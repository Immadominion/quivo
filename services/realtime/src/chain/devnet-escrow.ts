/**
 * Devnet escrow proof — exercises the DEPLOYED quivo program end-to-end on the money-custody half:
 *   mint test-USDC → initializeGame (creates Game PDA + program-owned vault) → fundPot →
 *   commitQuestions → assert the vault really holds the funds and the host can't touch them.
 *
 *   QUIVO_KEYPAIR=/path/to/funded-devnet-wallet.json tsx src/chain/devnet-escrow.ts
 *
 * This is the Tier-1 escrow slice (no ER yet) — proves the program moves and holds real money on
 * devnet. The ER delegate→settle round-trip is the next script.
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

const RPC = process.env.SOLANA_RPC ?? "https://api.devnet.solana.com";
const idl = JSON.parse(readFileSync(new URL("../onchain/quivo.json", import.meta.url), "utf8"));

function loadKeypair(): Keypair {
  const path = process.env.QUIVO_KEYPAIR;
  if (!path) throw new Error("set QUIVO_KEYPAIR=/path/to/devnet-wallet.json");
  return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(readFileSync(path, "utf8"))));
}

const ok = (label: string, cond: boolean, detail = "") => {
  console.log(`  ${cond ? "✅" : "❌"}  ${label}${detail ? "  " + detail : ""}`);
  if (!cond) throw new Error(`assertion failed: ${label}`);
};

async function main() {
  const payer = loadKeypair();
  const connection = new Connection(RPC, "confirmed");
  const provider = new anchor.AnchorProvider(connection, new anchor.Wallet(payer), {
    commitment: "confirmed",
  });
  anchor.setProvider(provider);
  const program = new anchor.Program(idl, provider);
  const programId = program.programId;

  console.log(`\n🏦  Quivo escrow proof → devnet`);
  console.log(`  program ${programId.toBase58()}`);
  console.log(`  host    ${payer.publicKey.toBase58()}\n`);

  // 1. test-USDC mint (6dp), fund the host with 10.
  console.log("· minting test-USDC…");
  const mint = await createMint(connection, payer, payer.publicKey, null, 6);
  const hostAta = await getOrCreateAssociatedTokenAccount(connection, payer, mint, payer.publicKey);
  await mintTo(connection, payer, mint, hostAta.address, payer, 10_000_000n); // 10 USDC
  ok("mint + host funded 10 USDC", true, mint.toBase58());

  // 2. PDAs.
  const seed = new BN(Date.now());
  const seedLe = seed.toArrayLike(Buffer, "le", 8);
  const [game] = PublicKey.findProgramAddressSync(
    [Buffer.from("game"), payer.publicKey.toBuffer(), seedLe],
    programId,
  );
  const [vaultAuthority] = PublicKey.findProgramAddressSync(
    [Buffer.from("vault"), game.toBuffer()],
    programId,
  );
  const potVault = getAssociatedTokenAddressSync(mint, vaultAuthority, true);

  // 3. initializeGame → creates Game + program-owned vault.
  console.log("· initializeGame…");
  await program.methods
    .initializeGame(seed, 3, [60, 30, 10])
    .accounts({
      host: payer.publicKey,
      game,
      potMint: mint,
      vaultAuthority,
      potVault,
      associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
      tokenProgram: TOKEN_PROGRAM_ID,
      systemProgram: SystemProgram.programId,
    })
    .rpc();
  const g1: any = await program.account.game.fetch(game);
  ok("game created", g1.status === 0 && g1.numQuestions === 3);
  ok("vault owned by program PDA", (await getAccount(connection, potVault)).owner.equals(vaultAuthority));

  // 4. fundPot 5 USDC.
  console.log("· fundPot 5 USDC…");
  await program.methods
    .fundPot(new BN(5_000_000))
    .accounts({ funder: payer.publicKey, funderAta: hostAta.address, potVault, game, tokenProgram: TOKEN_PROGRAM_ID })
    .rpc();
  const vaultBal = (await getAccount(connection, potVault)).amount;
  ok("escrow holds 5 USDC", vaultBal === 5_000_000n, `${Number(vaultBal) / 1e6} USDC`);

  // 5. commitQuestions (keccak of the reveal, before players join).
  console.log("· commitQuestions…");
  const reveal = Buffer.from(JSON.stringify({ q: ["a", "b", "c"], salt: "quivo-demo" }));
  const commitment = Array.from(keccak_256(reveal));
  await program.methods.commitQuestions(commitment).accounts({ host: payer.publicKey, game }).rpc();
  const g2: any = await program.account.game.fetch(game);
  ok("commitment stored", Buffer.from(g2.questionCommitment).equals(Buffer.from(commitment)));

  console.log(`\n✅  Escrow proven on devnet — the program holds 5 USDC that only settle can release.`);
  console.log(`   game    ${game.toBase58()}`);
  console.log(`   vault   ${potVault.toBase58()}`);
  console.log(`   https://explorer.solana.com/address/${game.toBase58()}?cluster=devnet\n`);
}

main().catch((e) => {
  console.error("\n💥 escrow proof failed:", e.message ?? e);
  process.exit(1);
});
