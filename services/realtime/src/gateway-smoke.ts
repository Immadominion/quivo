/**
 * Smoke test for the mobile JSON gateway: create a game (as a Colyseus host), then join + play
 * through the raw-JSON gateway exactly as the Flutter app will, and assert we get the money moment.
 *
 *   pnpm --filter @quivo/realtime exec tsx src/gateway-smoke.ts
 */
import { Client } from "colyseus.js";
import WebSocket from "ws";
import { Keypair } from "@solana/web3.js";

const COLYSEUS = process.env.REALTIME_URL ?? "ws://localhost:2567";
const GATEWAY = process.env.GATEWAY_URL ?? "ws://localhost:2568";

async function main() {
  console.log("\n📱 gateway smoke — host via Colyseus, player via raw JSON gateway\n");
  const host = await new Client(COLYSEUS).create("quivo", { host: true, name: "HOST", potAmount: "5000000" });
  console.log("  host created room", host.roomId);

  const wallet = Keypair.generate().publicKey.toBase58();
  const ws = new WebSocket(GATEWAY);
  const done = new Promise<void>((resolve, reject) => {
    let curQ = -1;
    ws.on("open", () => {
      console.log("  gateway connected → join", host.roomId);
      ws.send(JSON.stringify({ t: "join", code: host.roomId, name: "mobile-ada", wallet }));
    });
    ws.on("message", (raw) => {
      const m = JSON.parse(raw.toString());
      if (m.t === "joined") console.log("  ✅ joined via gateway, sessionId", m.sessionId);
      if (m.t === "chainReady") console.log("  ⚡ escrow ready", m.gamePubkey);
      if (m.t === "question") {
        curQ = m.question.index;
        const choice = Math.floor(Math.random() * m.question.options.length);
        setTimeout(() => ws.send(JSON.stringify({ t: "answer", questionIndex: curQ, choice })), 300);
        console.log(`  Q#${curQ} → answering`);
      }
      if (m.t === "reveal") console.log(`  reveal q#${m.questionIndex} correct=${m.correctChoice}`);
      if (m.t === "settled") {
        const mine = m.settlement.winners.find((w: any) => w.wallet === wallet);
        console.log("  💸 settled", m.settlement.txSig.slice(0, 12) + "…", mine ? `→ me +${Number(mine.amount) / 1e6} USDC` : "(no payout)");
        resolve();
      }
      if (m.t === "error") reject(new Error(m.message));
    });
    ws.on("error", reject);
  });

  // start once a player is in
  setTimeout(() => host.send("host:start"), 2500);
  const timeout = new Promise<void>((_, rej) => setTimeout(() => rej(new Error("timeout")), 120_000));
  try {
    await Promise.race([done, timeout]);
    console.log("\n✅ gateway smoke complete — the Flutter wire protocol works\n");
  } finally {
    ws.close();
    host.leave();
    setTimeout(() => process.exit(0), 300);
  }
}

main().catch((e) => {
  console.error("gateway smoke failed:", e.message ?? e);
  process.exit(1);
});
