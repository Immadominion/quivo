/**
 * Chain worker — the ONLY holder of the relayer/fee-payer key. Drives the on-chain lifecycle
 * (escrow, question commitment, settlement) and sponsors all gas so players never see a wallet
 * popup. The GameRoom talks to it through this interface only.
 *
 * Real mode needs QUIVO_KEYPAIR (path to a funded devnet keypair) or RELAYER_SECRET (JSON array).
 * Without either it runs as a logging STUB so the game loop still works offline.
 *
 * Flow per game (proven by src/chain/devnet-escrow.ts):
 *   initGame:  [self-mint test-USDC once] → mint pot to relayer → initializeGame → fundPot →
 *              commitQuestions(keccak(reveal))          (base layer, during the lobby)
 *   settle:    create winner ATAs → settle(reveal) with winners as remaining_accounts
 *              (verifies reveal vs commitment on-chain, pays 60/30/10 from escrow)
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
  settle(args: SettleArgs): Promise<Settlement>;
}

interface GameCtx {
  seed: InstanceType<typeof BN>;
  game: PublicKey;
  vaultAuthority: PublicKey;
  potVault: PublicKey;
  mint: PublicKey;
  potAmount: bigint;
}

function loadRelayer(): Keypair | null {
  const secret = process.env.RELAYER_SECRET;
  if (secret) return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(secret)));
  const path = process.env.QUIVO_KEYPAIR;
  if (path) return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(readFileSync(path, "utf8"))));
  return null;
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
  const games = new Map<string, GameCtx>();

  // One test-USDC mint per process (POT_MINT env overrides — then the relayer ATA must be pre-funded).
  let mintPromise: Promise<PublicKey> | null = null;
  const getMint = () => {
    if (process.env.POT_MINT) return Promise.resolve(new PublicKey(process.env.POT_MINT));
    mintPromise ??= retry("createMint", () => createMint(connection, relayer, relayer.publicKey, null, 6)).then(
      (m) => (console.log(`[chain] test-USDC mint ${m.toBase58()}`), m),
    );
    return mintPromise;
  };

  console.log(`[chain] REAL mode — relayer ${relayer.publicKey.toBase58()} → ${rpc}`);

  return {
    mode: "real",

    async initGame(args) {
      const mint = await getMint();
      // Fund the relayer with the pot, then escrow it (self-mint => we are mint authority).
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
      const [vaultAuthority] = PublicKey.findProgramAddressSync([Buffer.from("vault"), game.toBuffer()], program.programId);
      const potVault = getAssociatedTokenAddressSync(mint, vaultAuthority, true);

      await retry("initializeGame", () =>
        program.methods
          .initializeGame(seed, args.numQuestions, [...args.prizeSplit])
          .accounts({
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
          .accounts({ funder: relayer.publicKey, funderAta: relayerAta.address, potVault, game, tokenProgram: TOKEN_PROGRAM_ID })
          .rpc(),
      );
      await retry("commitQuestions", () =>
        program.methods.commitQuestions(Array.from(args.questionCommitment)).accounts({ host: relayer.publicKey, game }).rpc(),
      );

      games.set(args.gameId, { seed, game, vaultAuthority, potVault, mint, potAmount: args.potAmount });
      console.log(`[chain] game ${args.gameId} escrowed ${Number(args.potAmount) / 1e6} USDC → ${game.toBase58()}`);
      return { gamePubkey: game.toBase58() };
    },

    async settle(args) {
      const ctx = games.get(args.gameId);
      if (!ctx) throw new Error(`no on-chain game for room ${args.gameId} (initGame failed or never ran)`);

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
          .accounts({
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
      const winners: WinnerPayout[] = podium.map((w, i) => ({
        wallet: w.entry.wallet,
        rank: i + 1,
        amount: amounts[i].toString(),
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
