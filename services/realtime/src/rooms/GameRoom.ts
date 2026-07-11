/**
 * GameRoom — one Colyseus room per live game. Authoritative for gameplay: the round clock, the
 * secret questions, server-measured answer timing, scoring, and the leaderboard. Money + fairness
 * live on-chain via the injected ChainWorker (see ../chain/worker.ts); this room never holds the pot.
 *
 * Synced state (GameState) carries the continuous stuff (phase, scores) so clients render the
 * leaderboard cheaply; discrete events (a new question, the reveal, the settlement) are broadcast as
 * messages that mirror @quivo/protocol's ServerMessage union.
 */
import { Room, type Client } from "colyseus";
import { Schema, MapSchema, type } from "@colyseus/schema";
import { keccak_256 } from "@noble/hashes/sha3";
import {
  GAME,
  latencyBucket,
  scoreAnswer,
  type GamePhase,
  type LeaderboardEntry,
  type QuestionPublic,
} from "@quivo/protocol";
import type { ChainWorker } from "../chain/worker";

class PlayerState extends Schema {
  @type("string") name = "";
  @type("string") wallet = "";
  @type("number") score = 0;
  @type("boolean") hasAnswered = false;
  @type("number") lastDelta = 0;
}

class GameState extends Schema {
  @type("string") phase: GamePhase = "lobby";
  @type("number") questionIndex = -1;
  @type("number") endsAt = 0;
  @type({ map: PlayerState }) players = new MapSchema<PlayerState>();
}

/** Full question including the correct answer — SERVER ONLY, never synced or broadcast. */
interface Question {
  prompt: string;
  options: string[];
  correct: number;
}

const DEMO_QUESTIONS: Question[] = [
  {
    prompt: "What gives a Solana transaction its speed floor?",
    options: ["Proof of History", "Gas auctions", "Sharding", "A mempool"],
    correct: 0,
  },
  {
    prompt: "MagicBlock's Ephemeral Rollups mainly buy you…",
    options: ["More token supply", "Sub-50ms latency & gasless writes", "Fewer validators", "Free NFTs"],
    correct: 1,
  },
  {
    prompt: "A session key lets a player…",
    options: ["Mint SOL", "Sign scoped game actions with no wallet popup", "Become a validator", "Skip the game"],
    correct: 1,
  },
];

interface CreateOptions {
  chain: ChainWorker;
  questions?: Question[];
  potAmount?: string; // base units (bigint as string over the wire)
  prizeSplit?: number[];
  questionDurationMs?: number; // override for tests / fast rounds
  revealDurationMs?: number;
}

export class GameRoom extends Room<GameState> {
  maxClients = GAME.MAX_PLAYERS;

  private chain!: ChainWorker;
  private questions: Question[] = [];
  private answers = new Map<string, { choice: number; elapsedMs: number }>();
  private questionOpenedAt = 0;
  private hostId: string | null = null;
  private potAmount = 0n;
  private prizeSplit: number[] = [...GAME.DEFAULT_PRIZE_SPLIT];
  private questionMs: number = GAME.QUESTION_DURATION_MS;
  private revealMs: number = GAME.REVEAL_DURATION_MS;
  private timer: ReturnType<typeof setTimeout> | null = null;
  /** The exact bytes committed on-chain at creation and revealed at settle (commit-reveal). */
  private revealBytes!: Uint8Array;
  private chainInit: Promise<{ gamePubkey: string }> | null = null;

  onCreate(options: CreateOptions) {
    this.chain = options.chain;
    this.questions = options.questions?.length ? options.questions : DEMO_QUESTIONS;
    if (options.potAmount) this.potAmount = BigInt(options.potAmount);
    if (options.prizeSplit?.length) this.prizeSplit = options.prizeSplit;
    // Timing is a server/config concern (not client-dictated). Env override wins for tests.
    this.questionMs = Number(process.env.QUIVO_QUESTION_MS ?? options.questionDurationMs ?? GAME.QUESTION_DURATION_MS);
    this.revealMs = Number(process.env.QUIVO_REVEAL_MS ?? options.revealDurationMs ?? GAME.REVEAL_DURATION_MS);
    console.log(`[room] create q=${this.questionMs}ms r=${this.revealMs}ms pot=${this.potAmount} chain=${this.chain.mode}`);
    this.setState(new GameState());

    // Commit-reveal: hash the full question set (answers included) + a salt, escrow the pot, and
    // post the commitment BEFORE anyone plays — the host provably can't swap questions afterwards.
    // (Reveal bytes ride in the settle tx, so keep question sets small; hash-of-hashes later.)
    this.revealBytes = Buffer.from(JSON.stringify({ questions: this.questions, salt: this.roomId }));
    const commitment = keccak_256(this.revealBytes);
    this.chainInit = this.chain
      .initGame({
        gameId: this.roomId,
        numQuestions: this.questions.length,
        questionCommitment: commitment,
        prizeSplit: this.prizeSplit,
        potAmount: this.potAmount,
      })
      .then((r) => (console.log(`[room] on-chain game ready ${r.gamePubkey}`), r))
      .catch((e) => {
        console.error(`[room] chain init failed:`, e?.message ?? e);
        throw e;
      });

    this.onMessage("host:start", (client) => {
      if (this.state.phase !== "lobby") return;
      if (this.hostId && client.sessionId !== this.hostId) return;
      this.startQuestion(0);
    });

    this.onMessage("answer", (client, msg: { questionIndex: number; choice: number }) => {
      if (this.state.phase !== "question") return;
      if (msg.questionIndex !== this.state.questionIndex) return;
      if (this.answers.has(client.sessionId)) return; // one answer per question — no double-tap
      const player = this.state.players.get(client.sessionId);
      if (!player) return;
      const elapsedMs = Date.now() - this.questionOpenedAt; // server clock = truth
      this.answers.set(client.sessionId, { choice: msg.choice, elapsedMs });
      player.hasAnswered = true;
      // Tier-2: anchor the answer on the Ephemeral Rollup live — fire-and-forget; a failed anchor
      // never affects gameplay or the payout. On success the stage shows it in the on-chain ticker.
      const t0 = Date.now();
      this.chain
        .submitAnswer(this.roomId, player.wallet, msg.questionIndex, msg.choice, latencyBucket(elapsedMs, this.questionMs))
        .then(() =>
          this.broadcast("anchored", {
            name: player.name,
            wallet: player.wallet,
            questionIndex: msg.questionIndex,
            ms: Date.now() - t0,
          }),
        )
        .catch((e) => console.warn(`[room] answer anchor failed: ${e?.message ?? e}`));
    });
  }

  onJoin(client: Client, options: { name?: string; wallet?: string; host?: boolean }) {
    if (options.host && !this.hostId) {
      this.hostId = client.sessionId; // the host runs the stage — a presenter, not a contestant
      return;
    }
    const p = new PlayerState();
    p.name = (options.name ?? "player").slice(0, 24);
    p.wallet = options.wallet ?? "";
    this.state.players.set(client.sessionId, p);
    // Tier-2: create + delegate this player's PDA to the ER during the lobby (fire-and-forget —
    // if it fails they still play and still get paid; only their live answer trail is skipped).
    if (p.wallet) {
      this.chain
        .registerPlayer(this.roomId, p.wallet)
        .catch((e) => console.warn(`[room] player registration failed (${p.name}): ${e?.message ?? e}`));
    }
  }

  onLeave(client: Client) {
    // Keep the seat during an active game so a dropped phone can rejoin; only drop it in the lobby.
    if (this.state.phase === "lobby") this.state.players.delete(client.sessionId);
  }

  onDispose() {
    if (this.timer) clearTimeout(this.timer);
  }

  /** One pending phase-transition timer (the game is strictly sequential). */
  private schedule(fn: () => void, ms: number) {
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(fn, ms);
  }

  private startQuestion(index: number) {
    const q = this.questions[index];
    this.answers.clear();
    this.state.players.forEach((p) => (p.hasAnswered = false));
    this.state.phase = "question";
    this.state.questionIndex = index;
    this.questionOpenedAt = Date.now();
    this.state.endsAt = this.questionOpenedAt + this.questionMs;

    const question: QuestionPublic = {
      index,
      prompt: q.prompt,
      options: q.options,
      durationMs: this.questionMs,
    };
    this.broadcast("question", { question, endsAt: this.state.endsAt });
    this.schedule(() => this.closeQuestion(index), this.questionMs);
  }

  private closeQuestion(index: number) {
    if (this.state.questionIndex !== index || this.state.phase !== "question") return;
    const q = this.questions[index];
    this.state.players.forEach((p, sid) => {
      const a = this.answers.get(sid);
      const gained = a ? scoreAnswer(a.choice === q.correct, a.elapsedMs, this.questionMs) : 0;
      p.lastDelta = gained;
      p.score += gained;
    });
    this.state.phase = "reveal";
    this.broadcast("reveal", {
      questionIndex: index,
      correctChoice: q.correct,
      leaderboard: this.leaderboard(),
    });

    const isLast = index >= this.questions.length - 1;
    this.schedule(() => (isLast ? void this.finish() : this.startQuestion(index + 1)), this.revealMs);
  }

  private async finish() {
    this.state.phase = "settling";
    const ranking = this.leaderboard();
    this.broadcast("podium", { leaderboard: ranking });
    try {
      await this.chainInit; // escrow + commitment must exist before we can settle
      const settlement = await this.chain.settle({
        gameId: this.roomId,
        ranking,
        prizeSplit: this.prizeSplit,
        reveal: this.revealBytes,
      });
      this.broadcast("settled", { settlement });
    } catch (e: any) {
      this.broadcast("error", { code: "settle_failed", message: String(e?.message ?? e) });
    }
    this.state.phase = "complete";
  }

  private leaderboard(): LeaderboardEntry[] {
    const rows: LeaderboardEntry[] = [...this.state.players.entries()].map(([sid, p]) => ({
      sessionId: sid,
      name: p.name,
      wallet: p.wallet,
      score: p.score,
      delta: p.lastDelta,
      rank: 0,
    }));
    rows.sort((a, b) => b.score - a.score);
    rows.forEach((r, i) => (r.rank = i + 1));
    return rows;
  }
}
