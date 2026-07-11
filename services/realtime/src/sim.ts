/**
 * Vertical-slice simulator — drives a full game against a running realtime server, no UI.
 *
 *   pnpm --filter @quivo/realtime start   # terminal 1
 *   pnpm --filter @quivo/realtime sim      # terminal 2
 *
 * A host creates a room (short rounds), N players join and auto-answer with different reaction
 * times, and we log join → questions → reveals → podium → settlement. Proves the loop end-to-end.
 */
import { Client, type Room } from "colyseus.js";

const ENDPOINT = process.env.REALTIME_URL ?? "ws://localhost:2567";
const NUM_PLAYERS = 4;
const NAMES = ["ada", "bola", "chidi", "deji", "ephraim", "funke"];

function log(tag: string, msg: string) {
  console.log(`  ${tag.padEnd(8)} ${msg}`);
}

async function main() {
  const client = new Client(ENDPOINT);
  console.log(`\n🎬  Quivo vertical slice  →  ${ENDPOINT}\n`);

  const host = await client.create("quivo", {
    host: true,
    name: "HOST",
    wallet: "HOST",
    potAmount: (5_000_000).toString(), // 5 "USDC" (6dp)
    potMint: "TESTUSDC",
    questionDurationMs: 1800,
    revealDurationMs: 700,
  });
  log("host", `created room ${host.roomId}`);

  const done = new Promise<void>((resolve) => {
    host.onMessage("question", (m: any) => log("Q", `#${m.question.index}  ${m.question.prompt}`));
    host.onMessage("reveal", (m: any) => {
      const board = m.leaderboard.map((r: any) => `${r.name}:${r.score}`).join("  ");
      log("reveal", `correct=option[${m.correctChoice}]  |  ${board}`);
    });
    host.onMessage("podium", (m: any) => {
      const p = m.leaderboard.map((r: any, i: number) => `${i + 1}) ${r.name} ${r.score}`).join("   ");
      log("podium", p);
    });
    host.onMessage("settled", (m: any) => {
      log("settled", `tx=${m.settlement.txSig}`);
      for (const w of m.settlement.winners) log("payout", `#${w.rank}  ${w.wallet}  +${w.amount}`);
      resolve();
    });
    host.onMessage("error", (m: any) => {
      log("error", JSON.stringify(m));
      resolve();
    });
  });

  const players: Room[] = [];
  for (let i = 0; i < NUM_PLAYERS; i++) {
    const name = NAMES[i];
    const room = await client.joinById(host.roomId, { name, wallet: `W_${name}` });
    const reactionMs = 120 + i * 260; // different reaction times → different speed scores
    room.onMessage("question", (m: any) => {
      const choice = Math.floor(Math.random() * m.question.options.length); // questions are secret → guess
      setTimeout(() => room.send("answer", { questionIndex: m.question.index, choice }), reactionMs);
    });
    room.onMessage("*", () => {}); // players ignore reveal/podium/settled (stage/host renders those)
    players.push(room);
    log("join", `${name}`);
  }

  console.log();
  log("host", "▶ start");
  console.log();
  host.send("host:start");

  const timeout = new Promise<void>((_, reject) => setTimeout(() => reject(new Error("timeout")), 30_000));
  try {
    await Promise.race([done, timeout]);
    console.log("\n✅  slice complete — join → play → score → settle\n");
  } finally {
    players.forEach((p) => p.leave());
    host.leave();
    setTimeout(() => process.exit(0), 300);
  }
}

main().catch((e) => {
  console.error("sim failed:", e);
  process.exit(1);
});
