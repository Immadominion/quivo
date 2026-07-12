/**
 * Demo host — drives a real game the phone can join, for live end-to-end testing / demo capture.
 *
 *   pnpm --filter @quivo/realtime start        # terminal 1 (stub chain = instant settle)
 *   pnpm --filter @quivo/realtime demo-host     # terminal 2 → prints ROOM_CODE
 *
 * Creates a room with slow rounds + 3 auto-answering bots, prints the join code, waits for a human
 * player (the phone) to join, then starts. Keeps the leaderboard lively so the podium looks real.
 *
 * To seed bots into a room the STAGE dashboard already created (so the bots show up live on the
 * big-screen view instead of in a second, invisible room), pass its code:
 *
 *   ROOM_ID=<code from the stage's Create screen> pnpm --filter @quivo/realtime demo-host
 *
 * In that mode this script only joins bots as players — the stage owns hosting/host:start.
 */
import { Client, type Room } from "colyseus.js";
import { Keypair } from "@solana/web3.js";

const ENDPOINT = process.env.REALTIME_URL ?? "ws://localhost:2567";
const EXISTING_ROOM_ID = process.env.ROOM_ID;
const BOTS = ["ada", "bola", "chidi"];
const QUESTION_MS = Number(process.env.DEMO_QUESTION_MS ?? 14000);
const REVEAL_MS = Number(process.env.DEMO_REVEAL_MS ?? 6000);
const WAIT_FOR_HUMAN_MS = Number(process.env.DEMO_WAIT_MS ?? 60000);

const wallet = () => Keypair.generate().publicKey.toBase58();

function seatBots(roomId: string, client: Client): Promise<Room[]> {
  return Promise.all(
    BOTS.map(async (name) => {
      const bot = await client.joinById(roomId, { name, wallet: wallet() });
      bot.onMessage("question", (m: any) => {
        const smart = Math.random() < 0.6; // 60% pick option 1-ish; keeps it non-deterministic
        const choice = smart ? (m.question.index % m.question.options.length) : Math.floor(Math.random() * m.question.options.length);
        const delay = 600 + Math.floor(Math.random() * (QUESTION_MS * 0.6));
        setTimeout(() => bot.send("answer", { questionIndex: m.question.index, choice }), delay);
      });
      return bot;
    }),
  );
}

// ROOM_ID mode: the stage dashboard already created + will start the room. Just seed bots into it.
async function joinExisting(roomId: string) {
  const client = new Client(ENDPOINT);
  const bots = await seatBots(roomId, client);
  console.log(`[demo-host] ${bots.length} bots joined existing room ${roomId} — start it from the stage dashboard`);
  await new Promise(() => {}); // keep the process (and bot sockets) alive
}

async function main() {
  if (EXISTING_ROOM_ID) {
    await joinExisting(EXISTING_ROOM_ID);
    return;
  }

  const client = new Client(ENDPOINT);
  const host = await client.create("quivo", {
    host: true,
    name: "HOST",
    wallet: "HOST",
    potAmount: (5_000_000).toString(),
    potMint: "TESTUSDC",
    questionDurationMs: QUESTION_MS,
    revealDurationMs: REVEAL_MS,
  });
  console.log(`ROOM_CODE=${host.roomId}`);
  console.log(`[demo-host] room ${host.roomId} · q=${QUESTION_MS}ms · join from the phone now`);

  const bots = await seatBots(host.roomId, client);
  console.log(`[demo-host] ${bots.length} bots seated`);

  // Wait until a human (the phone) joins — player count exceeds the bots — then start.
  const humanJoined = new Promise<void>((resolve) => {
    let started = false;
    const check = () => {
      const count = (host.state as any).players?.size ?? 0;
      if (!started && count > bots.length) {
        started = true;
        resolve();
      }
    };
    host.onStateChange(check);
    setTimeout(() => { if (!started) { started = true; resolve(); } }, WAIT_FOR_HUMAN_MS);
  });
  await humanJoined;
  const lead = Number(process.env.DEMO_START_DELAY_MS ?? 8000);
  console.log(`[demo-host] human joined — starting in ${lead}ms…`);
  await new Promise((r) => setTimeout(r, lead));
  console.log(`[demo-host] starting game…`);
  host.send("host:start");

  await new Promise<void>((resolve) => {
    host.onMessage("podium", (m: any) =>
      console.log(`[demo-host] podium: ${m.leaderboard.map((r: any, i: number) => `${i + 1}) ${r.name} ${r.score}`).join("  ")}`),
    );
    host.onMessage("settled", (m: any) => {
      console.log(`[demo-host] settled tx=${m.settlement.txSig}`);
      resolve();
    });
    host.onMessage("error", (m: any) => { console.log(`[demo-host] error ${JSON.stringify(m)}`); resolve(); });
  });
  console.log(`[demo-host] done`);
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
