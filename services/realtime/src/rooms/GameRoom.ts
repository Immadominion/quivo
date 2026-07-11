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
import {
  GAME,
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
  potMint?: string;
  prizeSplit?: number[];
}

export class GameRoom extends Room<GameState> {
  maxClients = GAME.MAX_PLAYERS;

  private chain!: ChainWorker;
  private questions: Question[] = [];
  private answers = new Map<string, { choice: number; elapsedMs: number }>();
  private questionOpenedAt = 0;
  private hostId: string | null = null;
  private potAmount = 0n;
  private potMint = "So11111111111111111111111111111111111111112";
  private prizeSplit: number[] = [...GAME.DEFAULT_PRIZE_SPLIT];

  onCreate(options: CreateOptions) {
    this.chain = options.chain;
    this.questions = options.questions?.length ? options.questions : DEMO_QUESTIONS;
    if (options.potAmount) this.potAmount = BigInt(options.potAmount);
    if (options.potMint) this.potMint = options.potMint;
    if (options.prizeSplit?.length) this.prizeSplit = options.prizeSplit;
    this.setState(new GameState());

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
      // TODO(Tier-2): anchor (choice, latencyBucket(elapsedMs)) to the ER via the chain worker so
      // scoring is reconstructible on-chain in real time.
    });
  }

  onJoin(client: Client, options: { name?: string; wallet?: string; host?: boolean }) {
    if (options.host && !this.hostId) this.hostId = client.sessionId;
    const p = new PlayerState();
    p.name = (options.name ?? "player").slice(0, 24);
    p.wallet = options.wallet ?? "";
    this.state.players.set(client.sessionId, p);
  }

  onLeave(client: Client) {
    // Keep the seat during an active game so a dropped phone can rejoin; only drop it in the lobby.
    if (this.state.phase === "lobby") this.state.players.delete(client.sessionId);
  }

  private startQuestion(index: number) {
    const q = this.questions[index];
    this.answers.clear();
    this.state.players.forEach((p) => (p.hasAnswered = false));
    this.state.phase = "question";
    this.state.questionIndex = index;
    this.questionOpenedAt = Date.now();
    this.state.endsAt = this.questionOpenedAt + GAME.QUESTION_DURATION_MS;

    const question: QuestionPublic = {
      index,
      prompt: q.prompt,
      options: q.options,
      durationMs: GAME.QUESTION_DURATION_MS,
    };
    this.broadcast("question", { question, endsAt: this.state.endsAt });
    this.clock.setTimeout(() => this.closeQuestion(index), GAME.QUESTION_DURATION_MS);
  }

  private closeQuestion(index: number) {
    if (this.state.questionIndex !== index || this.state.phase !== "question") return;
    const q = this.questions[index];
    this.state.players.forEach((p, sid) => {
      const a = this.answers.get(sid);
      const gained = a ? scoreAnswer(a.choice === q.correct, a.elapsedMs, GAME.QUESTION_DURATION_MS) : 0;
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
    this.clock.setTimeout(
      () => (isLast ? void this.finish() : this.startQuestion(index + 1)),
      GAME.REVEAL_DURATION_MS,
    );
  }

  private async finish() {
    this.state.phase = "settling";
    const ranking = this.leaderboard();
    this.broadcast("podium", { leaderboard: ranking });
    try {
      const settlement = await this.chain.settle({
        gameId: this.roomId,
        ranking,
        potAmount: this.potAmount,
        potMint: this.potMint,
        prizeSplit: this.prizeSplit,
        reveal: null,
      });
      this.broadcast("settled", { settlement });
    } catch (e) {
      this.broadcast("error", { code: "settle_failed", message: String(e) });
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
