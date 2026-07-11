/**
 * Chain worker — the ONLY holder of the relayer/fee-payer key. Drives the on-chain lifecycle and
 * sponsors all gas so players never see a wallet popup. The GameRoom talks to it through this
 * interface only.
 *
 * TIER-1 (base layer): escrow the pot + commit the question set in the lobby; settle the podium
 * with the reveal at game end. Proven by src/chain/devnet-escrow.ts.
 *
 * TIER-2 (MagicBlock Ephemeral Rollup): each player gets their own Player PDA, delegated to the ER
 * at join. Every answer streams to the ER live during play (gasless, sub-50ms writes) — the score
 * trail is on-chain WHILE the game runs. At game end the Player PDAs commit + undelegate back to
 * base, then settle pays from escrow. The Game account never delegates, so settlement can never be
 * hostage to ER timing — Tier-2 failures degrade gracefully to Tier-1, never brick the payout.
 *
 * Real mode needs QUIVO_KEYPAIR (path) or RELAYER_SECRET (JSON array). Otherwise: logging stub.
 */
import { readFileSync } from "node:fs";
import * as anchor from "@coral-xyz/anchor";
import BN from "bn.js";
import { Connection, Keypair, PublicKey, SystemProgram } from "@solana/web3.js";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  TOKEN_PROGRAM_ID,
  createMint,
  getOrCreateAssociatedTokenAccount,
  getAssociatedTokenAddressSync,
  mintTo,
} from "@solana/spl-token";
import { splitPot, type LeaderboardEntry, type Settlement, type WinnerPayout } from "@quivo/protocol";
import { retry } from "./retry";

export interface InitGameArgs {
  gameId: string;
  numQuestions: number;
  questionCommitment: Uint8Array; // keccak256(reveal)
  prizeSplit: readonly number[];
  potAmount: bigint; // base units (6dp test-USDC)
}

export interface SettleArgs {
  gameId: string;
  ranking: LeaderboardEntry[]; // sorted, rank 1 first
  prizeSplit: readonly number[];
  reveal: Uint8Array; // the exact bytes whose keccak was committed
}

export interface ChainWorker {
  readonly mode: "real" | "stub";
  initGame(args: InitGameArgs): Promise<{ gamePubkey: string }>;
  /** Tier-2: create + delegate the player's PDA so answers can stream to the ER. */
  registerPlayer(gameId: string, wallet: string): Promise<void>;
  /** Tier-2: anchor one answer on the ER, live. Fire-and-forget from gameplay. */
  submitAnswer(gameId: string, wallet: string, questionIndex: number, choice: number, bucket: number): Promise<void>;
  settle(args: SettleArgs): Promise<Settlement>;
}

interface GameCtx {
  seed: InstanceType<typeof BN>;
  game: PublicKey;
  vaultAuthority: PublicKey;
  potVault: PublicKey;
  mint: PublicKey;
  potAmount: bigint;
  /** wallet base58 → delegated Player PDA */
  players: Map<string, PublicKey>;
  /** wallet base58 → in-flight registration (answers wait for it instead of dropping) */
  playersPending: Map<string, Promise<void>>;
  /** memoized ER-bound program — a promise set synchronously so concurrent callers can't race */
  erReady?: Promise<anchor.Program>;
  anchored: number;
}

function loadRelayer(): Keypair | null {
  const secret = process.env.RELAYER_SECRET;
  if (secret) return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(secret)));
  const path = process.env.QUIVO_KEYPAIR;
  if (path) return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(readFileSync(path, "utf8"))));
  return null;
}

/** Resolve the ER endpoint for a delegated account via the MagicBlock router. */
async function resolveErEndpoint(account: PublicKey): Promise<string> {
  const router = process.env.ROUTER_ENDPOINT ?? "https://devnet-router.magicblock.app/";
  try {
    const res = await fetch(router, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getDelegationStatus", params: [account.toBase58()] }),
    });
    const body: any = await res.json();
    if (body?.result?.isDelegated && body.result.fqdn) return body.result.fqdn;
  } catch {
    /* fall through */
  }
  return process.env.EPHEMERAL_RPC || "https://devnet.magicblock.app";
}

export function makeChainWorker(): ChainWorker {
  const relayer = loadRelayer();
  if (!relayer) {
    console.warn("[chain] no RELAYER_SECRET / QUIVO_KEYPAIR — STUB mode (no real on-chain payout).");
    return stubWorker();
  }

  const rpc = process.env.SOLANA_RPC ?? "https://rpc.magicblock.app/devnet";
  const connection = new Connection(rpc, { commitment: "confirmed", confirmTransactionInitialTimeout: 90_000 });
  const provider = new anchor.AnchorProvider(connection, new anchor.Wallet(relayer), { commitment: "confirmed" });
  const idl = JSON.parse(readFileSync(new URL("../onchain/quivo.json", import.meta.url), "utf8"));
  const program = new anchor.Program(idl, provider);
  const games = new Map<string, Promise<GameCtx>>();

  // One test-USDC mint per process (POT_MINT env overrides — then the relayer ATA must be pre-funded).
  let mintPromise: Promise<PublicKey> | null = null;
  const getMint = () => {
    if (process.env.POT_MINT) return Promise.resolve(new PublicKey(process.env.POT_MINT));
    mintPromise ??= retry("createMint", () => createMint(connection, relayer, relayer.publicKey, null, 6)).then(
      (m) => (console.log(`[chain] test-USDC mint ${m.toBase58()}`), m),
    );
    return mintPromise;
  };

  const playerPda = (game: PublicKey, wallet: PublicKey) =>
    PublicKey.findProgramAddressSync(
      [Buffer.from("player"), game.toBuffer(), wallet.toBuffer()],
      program.programId,
    )[0];

  /** Lazily build the ER-bound program the first time we need to write to the rollup. The promise
   *  is assigned synchronously, so concurrent answer bursts share ONE router resolution. */
  function erFor(ctx: GameCtx): Promise<anchor.Program> {
    ctx.erReady ??= (async () => {
      const anyPda = ctx.players.values().next().value as PublicKey | undefined;
      const endpoint = await resolveErEndpoint(anyPda ?? ctx.game);
      // 'processed' — the ER's single sequencer finalizes instantly; waiting for 'confirmed' only
      // adds client-side polling latency to writes that already executed in milliseconds.
      const erConn = new Connection(endpoint, { commitment: "processed" });
      const erProvider = new anchor.AnchorProvider(erConn, new anchor.Wallet(relayer!), {
        commitment: "processed",
        preflightCommitment: "processed",
      });
      console.log(`[chain] ⚡ ER endpoint ${endpoint}`);
      return new anchor.Program(idl, erProvider);
    })();
    return ctx.erReady;
  }

  console.log(`[chain] REAL mode — relayer ${relayer.publicKey.toBase58()} → ${rpc}`);

  return {
    mode: "real",

    initGame(args) {
      const promise = (async (): Promise<GameCtx> => {
        const mint = await getMint();
        const relayerAta = await retry("relayerAta", () =>
          getOrCreateAssociatedTokenAccount(connection, relayer, mint, relayer.publicKey),
        );
        if (!process.env.POT_MINT) {
          await retry("mintPot", () => mintTo(connection, relayer, mint, relayerAta.address, relayer, args.potAmount));
        }

        const seed = new BN(Date.now());
        const seedLe = seed.toArrayLike(Buffer, "le", 8);
        const [game] = PublicKey.findProgramAddressSync(
          [Buffer.from("game"), relayer.publicKey.toBuffer(), seedLe],
          program.programId,
        );
        const [vaultAuthority] = PublicKey.findProgramAddressSync(
          [Buffer.from("vault"), game.toBuffer()],
          program.programId,
        );
        const potVault = getAssociatedTokenAddressSync(mint, vaultAuthority, true);

        await retry("initializeGame", () =>
          program.methods
            .initializeGame(seed, args.numQuestions, [...args.prizeSplit])
            .accountsPartial({
              host: relayer.publicKey,
              game,
              potMint: mint,
              vaultAuthority,
              potVault,
              associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
              tokenProgram: TOKEN_PROGRAM_ID,
              systemProgram: SystemProgram.programId,
            })
            .rpc(),
        );
        await retry("fundPot", () =>
          program.methods
            .fundPot(new BN(args.potAmount.toString()))
            .accountsPartial({
              funder: relayer.publicKey,
              funderAta: relayerAta.address,
              potVault,
              game,
              tokenProgram: TOKEN_PROGRAM_ID,
            })
            .rpc(),
        );
        await retry("commitQuestions", () =>
          program.methods
            .commitQuestions(Array.from(args.questionCommitment))
            .accountsPartial({ host: relayer.publicKey, game })
            .rpc(),
        );

        console.log(`[chain] game ${args.gameId} escrowed ${Number(args.potAmount) / 1e6} USDC → ${game.toBase58()}`);
        return {
          seed,
          game,
          vaultAuthority,
          potVault,
          mint,
          potAmount: args.potAmount,
          players: new Map(),
          playersPending: new Map(),
          anchored: 0,
        };
      })();
      games.set(args.gameId, promise);
      return promise.then((ctx) => ({ gamePubkey: ctx.game.toBase58() }));
    },

    /** Tier-2: join_game (relayer pays rent) + delegate_player → the PDA now lives on the ER. */
    async registerPlayer(gameId, wallet) {
      const ctxPromise = games.get(gameId);
      if (!ctxPromise) throw new Error(`no on-chain game for room ${gameId}`);
      const ctx = await ctxPromise;
      const walletPk = new PublicKey(wallet);
      const pda = playerPda(ctx.game, walletPk);

      const registration = (async () => {
        await retry("joinGame", () =>
          program.methods
            .joinGame()
            .accountsPartial({
              payer: relayer.publicKey,
              wallet: walletPk,
              game: ctx.game,
              player: pda,
              systemProgram: SystemProgram.programId,
            })
            .rpc(),
        );
        await retry("delegatePlayer", () =>
          program.methods
            .delegatePlayer(walletPk)
            .accountsPartial({ payer: relayer.publicKey, player: pda, game: ctx.game })
            .rpc(),
        );
        ctx.players.set(wallet, pda);
        console.log(`[chain] ⚡ player ${wallet.slice(0, 4)}… delegated to ER (${pda.toBase58().slice(0, 8)}…)`);
      })();
      ctx.playersPending.set(wallet, registration);
      await registration;
    },

    /** Tier-2: anchor one answer on the ER — gasless, milliseconds, live during play. */
    async submitAnswer(gameId, wallet, questionIndex, choice, bucket) {
      const ctxPromise = games.get(gameId);
      if (!ctxPromise) return;
      const ctx = await ctxPromise;
      let pda = ctx.players.get(wallet);
      if (!pda) {
        // Registration may still be in flight (short lobby) — wait for it instead of dropping.
        const pending = ctx.playersPending.get(wallet);
        if (pending) {
          await pending.catch(() => {});
          pda = ctx.players.get(wallet);
        }
      }
      if (!pda) return; // player never registered on-chain — gameplay is unaffected
      const er = await erFor(ctx);
      const t0 = Date.now();
      await er.methods
        .submitAnswer(questionIndex, choice, bucket)
        .accountsPartial({ signer: relayer.publicKey, game: ctx.game, player: pda })
        .rpc({ skipPreflight: true });
      ctx.anchored++;
      console.log(`[chain] ⚡ answer anchored on ER  q${questionIndex} ${wallet.slice(0, 4)}…  ${Date.now() - t0}ms`);
    },

    async settle(args) {
      const ctxPromise = games.get(args.gameId);
      if (!ctxPromise) throw new Error(`no on-chain game for room ${args.gameId} (initGame failed or never ran)`);
      const ctx = await ctxPromise;

      // Tier-2 epilogue: commit + undelegate the answer trail back to base. Never blocks the payout.
      console.log(`[chain] settle: players=${ctx.players.size} anchored=${ctx.anchored} er=${!!ctx.erReady}`);
      if (ctx.players.size > 0 && ctx.erReady) {
        try {
          const er = await erFor(ctx);
          const pdas = [...ctx.players.values()];
          const sig = await er.methods
            .commitPlayers()
            .accountsPartial({ payer: relayer.publicKey })
            .remainingAccounts(pdas.map((pubkey) => ({ pubkey, isWritable: true, isSigner: false })))
            .rpc({ skipPreflight: true });
          console.log(`[chain] ⚡ answer trail (${ctx.anchored} answers, ${pdas.length} players) committing to base — ${sig}`);
        } catch (e: any) {
          console.warn(`[chain] commit_players failed (payout unaffected): ${e?.message ?? e}`);
        }
      }

      // Valid winner wallets, podium order. Fewer winners than podium slots → surplus rolls to #1.
      const valid = args.ranking
        .map((r) => {
          try {
            return { entry: r, pubkey: new PublicKey(r.wallet) };
          } catch {
            return null;
          }
        })
        .filter(Boolean) as { entry: LeaderboardEntry; pubkey: PublicKey }[];
      if (valid.length === 0) throw new Error("no valid winner wallets to pay");

      const podium = valid.slice(0, args.prizeSplit.length);
      const atas: PublicKey[] = [];
      for (const w of podium) {
        const ata = await retry("winnerAta", () =>
          getOrCreateAssociatedTokenAccount(connection, relayer, ctx.mint, w.pubkey),
        );
        atas.push(ata.address);
      }
      while (atas.length < args.prizeSplit.length) atas.push(atas[0]); // roll surplus shares up to #1

      const txSig = await retry("settle", () =>
        program.methods
          .settle(Buffer.from(args.reveal))
          .accountsPartial({
            payer: relayer.publicKey,
            game: ctx.game,
            vaultAuthority: ctx.vaultAuthority,
            potVault: ctx.potVault,
            tokenProgram: TOKEN_PROGRAM_ID,
          })
          .remainingAccounts(atas.map((pubkey) => ({ pubkey, isWritable: true, isSigner: false })))
          .rpc(),
      );

      const amounts = splitPot(ctx.potAmount, args.prizeSplit);
      // Padded slots (fewer players than podium spots) actually paid winner #1 — report the truth.
      const surplus = amounts.slice(podium.length).reduce((a, b) => a + b, 0n);
      const winners: WinnerPayout[] = podium.map((w, i) => ({
        wallet: w.entry.wallet,
        rank: i + 1,
        amount: (i === 0 ? amounts[0] + surplus : amounts[i]).toString(),
      }));
      console.log(`[chain] game ${args.gameId} settled → ${txSig}`);
      return { txSig, potMint: ctx.mint.toBase58(), winners };
    },
  };
}

function stubWorker(): ChainWorker {
  return {
    mode: "stub",
    async initGame(args) {
      return { gamePubkey: `stub:${args.gameId}` };
    },
    async registerPlayer() {},
    async submitAnswer() {},
    async settle(args) {
      const amounts = splitPot(1_000_000n, args.prizeSplit);
      const winners: WinnerPayout[] = args.ranking.slice(0, amounts.length).map((r, i) => ({
        wallet: r.wallet,
        rank: i + 1,
        amount: amounts[i].toString(),
      }));
      console.log(`[chain:stub] settle ${args.gameId} →`, winners.map((w) => w.wallet).join(", "));
      return { txSig: "stub-signature", potMint: "STUB", winners };
    },
  };
}
