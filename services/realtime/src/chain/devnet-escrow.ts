/**
 * Devnet Tier-1 proof — exercises the DEPLOYED quivo program end-to-end:
 *   mint test-USDC → initializeGame (Game PDA + program-owned vault) → fundPot → commitQuestions →
 *   settle (verify reveal, pay the 60/30/10 podium) → assert every winner wallet was paid on-chain.
 *
 *   SOLANA_RPC=<rpc> QUIVO_KEYPAIR=/path/to/funded-devnet-wallet.json tsx src/chain/devnet-escrow.ts
 *
 * Every on-chain op is wrapped in a transient-error retry — public devnet RPCs are flaky and we don't
 * want a socket hiccup to fail a real settlement. This is the Tier-1 slice (no ER).
 */
import { readFileSync } from "node:fs";
import * as anchor from "@coral-xyz/anchor";
import BN from "bn.js";
import { Connection, Keypair, PublicKey, SystemProgram } from "@solana/web3.js";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  TOKEN_PROGRAM_ID,
  createMint,
  getAccount,
  getOrCreateAssociatedTokenAccount,
  getAssociatedTokenAddressSync,
  mintTo,
} from "@solana/spl-token";
import { keccak_256 } from "@noble/hashes/sha3";
import type { Quivo } from "../onchain/quivo";

const RPC = process.env.SOLANA_RPC ?? "https://rpc.magicblock.app/devnet";
const idl = JSON.parse(readFileSync(new URL("../onchain/quivo.json", import.meta.url), "utf8")) as Quivo;

function loadKeypair(): Keypair {
  const path = process.env.QUIVO_KEYPAIR;
  if (!path) throw new Error("set QUIVO_KEYPAIR=/path/to/devnet-wallet.json");
  return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(readFileSync(path, "utf8"))));
}

const TRANSIENT = /fetch failed|socket hang up|block height exceeded|Blockhash not found|429|Too Many Requests|timed out|ETIMEDOUT|ECONNRESET|502|503|GOAWAY/i;

async function retry<T>(label: string, fn: () => Promise<T>, tries = 8): Promise<T> {
  let lastErr: unknown;
  for (let i = 0; i < tries; i++) {
    try {
      return await fn();
    } catch (e: any) {
      lastErr = e;
      if (!TRANSIENT.test(String(e?.message ?? e)) || i === tries - 1) throw e;
      process.stdout.write(`  ↻ ${label} (retry ${i + 1})\n`);
      await new Promise((r) => setTimeout(r, 700 * (i + 1)));
    }
  }
  throw lastErr;
}

const ok = (label: string, cond: boolean, detail = "") => {
  console.log(`  ${cond ? "✅" : "❌"}  ${label}${detail ? "  " + detail : ""}`);
  if (!cond) throw new Error(`assertion failed: ${label}`);
};

async function main() {
  const payer = loadKeypair();
  const connection = new Connection(RPC, { commitment: "confirmed", confirmTransactionInitialTimeout: 90_000 });
  const provider = new anchor.AnchorProvider(connection, new anchor.Wallet(payer), { commitment: "confirmed" });
  anchor.setProvider(provider);
  const program = new anchor.Program<Quivo>(idl, provider);
  const programId = program.programId;

  console.log(`\n🏦  Quivo Tier-1 proof → devnet`);
  console.log(`  program ${programId.toBase58()}`);
  console.log(`  host    ${payer.publicKey.toBase58()}\n`);

  // 1. test-USDC mint (6dp); fund the host with 10.
  console.log("· minting test-USDC…");
  const mint = await retry("createMint", () => createMint(connection, payer, payer.publicKey, null, 6));
  const hostAta = await retry("hostAta", () => getOrCreateAssociatedTokenAccount(connection, payer, mint, payer.publicKey));
  await retry("mintTo", () => mintTo(connection, payer, mint, hostAta.address, payer, 10_000_000n));
  ok("mint + host funded 10 USDC", true, mint.toBase58());

  // 2. PDAs.
  const seed = new BN(Date.now());
  const seedLe = seed.toArrayLike(Buffer, "le", 8);
  const [game] = PublicKey.findProgramAddressSync([Buffer.from("game"), payer.publicKey.toBuffer(), seedLe], programId);
  const [vaultAuthority] = PublicKey.findProgramAddressSync([Buffer.from("vault"), game.toBuffer()], programId);
  const potVault = getAssociatedTokenAddressSync(mint, vaultAuthority, true);

  // 3. initializeGame → Game + program-owned vault.
  console.log("· initializeGame…");
  await retry("initializeGame", () =>
    program.methods
      .initializeGame(seed, 3, [60, 30, 10])
      .accountsPartial({
        host: payer.publicKey,
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
  const g1: any = await retry("fetch game", () => program.account.game.fetch(game));
  ok("game created", g1.status === 0 && g1.numQuestions === 3);
  ok("vault owned by program PDA", (await retry("vault", () => getAccount(connection, potVault))).owner.equals(vaultAuthority));

  // 4. fundPot 5 USDC.
  console.log("· fundPot 5 USDC…");
  await retry("fundPot", () =>
    program.methods
      .fundPot(new BN(5_000_000))
      .accountsPartial({ funder: payer.publicKey, funderAta: hostAta.address, potVault, game, tokenProgram: TOKEN_PROGRAM_ID })
      .rpc(),
  );
  ok("escrow holds 5 USDC", (await retry("vaultBal", () => getAccount(connection, potVault))).amount === 5_000_000n);

  // 5. commitQuestions (keccak of the reveal, before players join).
  console.log("· commitQuestions…");
  const reveal = Buffer.from(JSON.stringify({ q: ["a", "b", "c"], salt: "quivo-demo" }));
  const commitment = Array.from(keccak_256(reveal));
  await retry("commitQuestions", () => program.methods.commitQuestions(commitment).accountsPartial({ host: payer.publicKey, game }).rpc());
  const g2: any = await retry("fetch game 2", () => program.account.game.fetch(game));
  ok("commitment stored", Buffer.from(g2.questionCommitment).equals(Buffer.from(commitment)));

  // 6. Podium winners + token accounts.
  console.log("· creating 3 winners + ATAs…");
  const winners = [Keypair.generate(), Keypair.generate(), Keypair.generate()];
  const winnerAtas: PublicKey[] = [];
  for (const w of winners) {
    const ata = await retry("winnerAta", () => getOrCreateAssociatedTokenAccount(connection, payer, mint, w.publicKey));
    winnerAtas.push(ata.address);
  }

  // 7. settle → verify reveal against the commitment, then pay the podium from escrow.
  console.log("· settle (pay the podium)…");
  await retry("settle", () =>
    program.methods
      .settle(reveal)
      .accountsPartial({ payer: payer.publicKey, game, vaultAuthority, potVault, tokenProgram: TOKEN_PROGRAM_ID })
      .remainingAccounts(winnerAtas.map((pubkey) => ({ pubkey, isWritable: true, isSigner: false })))
      .rpc(),
  );

  // 8. Verify the money actually moved.
  const bals = await Promise.all(winnerAtas.map((a) => retry("bal", () => getAccount(connection, a).then((x) => x.amount))));
  ok("1st place paid 3.0 USDC", bals[0] === 3_000_000n, `${Number(bals[0]) / 1e6}`);
  ok("2nd place paid 1.5 USDC", bals[1] === 1_500_000n, `${Number(bals[1]) / 1e6}`);
  ok("3rd place paid 0.5 USDC", bals[2] === 500_000n, `${Number(bals[2]) / 1e6}`);
  ok("vault drained", (await retry("vaultFinal", () => getAccount(connection, potVault))).amount === 0n);
  const g3: any = await retry("fetch game 3", () => program.account.game.fetch(game));
  ok("game marked complete", g3.status === 3);

  console.log(`\n✅  Full Tier-1 flow proven on devnet — escrow → provably-fair reveal → podium paid.`);
  console.log(`   game  ${game.toBase58()}`);
  winners.forEach((w, i) => console.log(`   #${i + 1}    ${w.publicKey.toBase58()}  +${Number(bals[i]) / 1e6} USDC`));
  console.log(`   https://explorer.solana.com/address/${game.toBase58()}?cluster=devnet\n`);
}

main().catch((e) => {
  console.error("\n💥 tier-1 proof failed:", e.message ?? e);
  process.exit(1);
});
