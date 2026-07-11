/**
 * @quivo/protocol — the typed contract shared by every layer.
 *
 * The realtime server (services/realtime) and the stage app (apps/stage) import these directly.
 * The Flutter player app mirrors the same wire shapes in Dart. Keep this file the single source of
 * truth for messages, game state, scoring, and tunables — change it here, change it everywhere.
 */

// ─────────────────────────── Tunables ───────────────────────────

export const GAME = {
  /** How long a question's answer window stays open. */
  QUESTION_DURATION_MS: 20_000,
  /** How long the correct answer + leaderboard stays up before the next question. */
  REVEAL_DURATION_MS: 4_000,
  /** Hard cap per room (Colyseus room; scale out with more rooms, not bigger ones). */
  MAX_PLAYERS: 300,
  /** Correct answer floor, before the speed bonus. */
  BASE_POINTS: 1_000,
  /** Fraction of BASE_POINTS awarded purely for being correct (rest is speed). */
  CORRECT_FLOOR: 0.5,
  /** Default prize split across the podium (must sum to 100). */
  DEFAULT_PRIZE_SPLIT: [60, 30, 10] as const,
} as const;

// ─────────────────────────── Core enums ───────────────────────────

export type GamePhase =
  | "lobby" // players joining, host hasn't started
  | "question" // a question is live, answers open
  | "reveal" // answer shown, leaderboard updating
  | "intermission" // between questions
  | "settling" // computing + paying out on-chain
  | "complete"; // podium shown, payout landed

// ─────────────────────────── View models ───────────────────────────

/** A question as sent to players — NEVER includes the correct answer. */
export interface QuestionPublic {
  index: number;
  prompt: string;
  options: string[]; // 2–4 options
  durationMs: number;
}

export interface PlayerView {
  sessionId: string;
  name: string;
  score: number;
  hasAnswered: boolean;
}

export interface LeaderboardEntry {
  sessionId: string;
  name: string;
  wallet: string;
  score: number;
  rank: number;
  /** Points gained on the last question (for the "+320" pop). */
  delta: number;
}

export interface WinnerPayout {
  wallet: string;
  rank: number;
  /** In the pot mint's base units (e.g. USDC 6dp). */
  amount: string;
}

export interface Settlement {
  /** Base-layer transaction signature of the settle Magic Action. */
  txSig: string;
  potMint: string;
  winners: WinnerPayout[];
}

// ─────────────────────────── Client → Server ───────────────────────────

export type ClientMessage =
  | { t: "join"; name: string; wallet: string }
  | { t: "answer"; questionIndex: number; choice: number } // choice = option index
  | { t: "host:start" }
  | { t: "host:next" };

// ─────────────────────────── Server → Client ───────────────────────────

export type ServerMessage =
  | {
      t: "state";
      phase: GamePhase;
      questionIndex: number;
      /** epoch ms when the current phase ends (question/reveal); null in lobby/complete. */
      endsAt: number | null;
      players: PlayerView[];
    }
  | { t: "question"; question: QuestionPublic; endsAt: number }
  | {
      t: "reveal";
      questionIndex: number;
      correctChoice: number;
      leaderboard: LeaderboardEntry[];
    }
  | { t: "podium"; leaderboard: LeaderboardEntry[] }
  | { t: "settled"; settlement: Settlement }
  | { t: "error"; code: string; message: string };

// ─────────────────────────── Scoring ───────────────────────────

/**
 * Kahoot-style scoring: correct answers earn a floor, and answering faster earns up to the rest.
 * The server owns the clock, so `elapsedMs` is measured server-side from when the question opened —
 * clients cannot inflate their speed. On-chain we anchor `(choice, latencyBucket)` so the score is
 * reconstructible; this function is the single definition both sides agree on.
 */
export function scoreAnswer(correct: boolean, elapsedMs: number, durationMs: number): number {
  if (!correct) return 0;
  const remaining = Math.max(0, Math.min(1, 1 - elapsedMs / durationMs));
  const speed = (1 - GAME.CORRECT_FLOOR) * remaining;
  return Math.round(GAME.BASE_POINTS * (GAME.CORRECT_FLOOR + speed));
}

/** Bucket latency into a small int for compact on-chain anchoring (0 = fastest). */
export function latencyBucket(elapsedMs: number, durationMs: number, buckets = 8): number {
  const frac = Math.max(0, Math.min(1, elapsedMs / durationMs));
  return Math.min(buckets - 1, Math.floor(frac * buckets));
}

/** Compute prize amounts (base units) for a pot given a split that sums to 100. Handles remainder. */
export function splitPot(potAmount: bigint, split: readonly number[]): bigint[] {
  const total = split.reduce((a, b) => a + b, 0);
  if (total !== 100) throw new Error(`prize split must sum to 100, got ${total}`);
  const out = split.map((pct) => (potAmount * BigInt(pct)) / 100n);
  // Give any rounding remainder to first place.
  const distributed = out.reduce((a, b) => a + b, 0n);
  out[0] += potAmount - distributed;
  return out;
}
