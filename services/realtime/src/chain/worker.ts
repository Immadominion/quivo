/**
 * Chain worker — the ONLY holder of the relayer/fee-payer key. It drives the on-chain lifecycle
 * (escrow, question commitment, VRF, settlement Magic Action) and sponsors gas so players never see
 * a wallet popup. The GameRoom talks to it through this interface only, so the on-chain layer can be
 * built and swapped without touching gameplay code.
 *
 * Right now `makeChainWorker` returns a STUB (logs + fake settlement) so the real-time slice runs
 * end-to-end before the program is deployed. Wire the real implementation against
 * onchain/programs/quivo once `anchor deploy` is done.
 */
import { splitPot, type LeaderboardEntry, type Settlement, type WinnerPayout } from "@quivo/protocol";

export interface InitGameArgs {
  gameId: string;
  numQuestions: number;
  questionCommitment: Uint8Array; // hash(questions ‖ answers ‖ salt)
  prizeSplit: readonly number[];
  potMint: string;
  potAmount: bigint; // base units
}

export interface SettleArgs {
  gameId: string;
  ranking: LeaderboardEntry[]; // sorted, rank 1 first
  potAmount: bigint;
  potMint: string;
  prizeSplit: readonly number[]; // podium split, sums to 100 (from the Game account)
  reveal: unknown; // { questions, answers, salt } to verify against the commitment
}

export interface ChainWorker {
  /** initialize_game + fund_pot + commit_questions on devnet. Returns the Game account pubkey. */
  initGame(args: InitGameArgs): Promise<{ gamePubkey: string }>;
  /** Verify reveal, VRF tie-break, pay top-N from escrow via the settle Magic Action. */
  settle(args: SettleArgs): Promise<Settlement>;
}

export function makeChainWorker(): ChainWorker {
  const relayer = process.env.RELAYER_SECRET;
  const programId = process.env.QUIVO_PROGRAM_ID;
  const stub = !relayer || !programId;

  if (stub) {
    console.warn(
      "[chain] RELAYER_SECRET / QUIVO_PROGRAM_ID not set — STUB mode (no real on-chain payout).",
    );
  }

  return {
    async initGame(args) {
      if (stub) return { gamePubkey: `stub:${args.gameId}` };
      // TODO(onchain): build+send initialize_game, fund_pot, commit_questions.
      //   see onchain/programs/quivo/src/lib.rs
      throw new Error("real chain worker not wired yet");
    },

    async settle(args) {
      const amounts = splitPot(args.potAmount, args.prizeSplit);
      const winners: WinnerPayout[] = args.ranking.slice(0, amounts.length).map((r, i) => ({
        wallet: r.wallet,
        rank: i + 1,
        amount: amounts[i].toString(),
      }));

      if (stub) {
        console.log(`[chain:stub] settle ${args.gameId} →`, winners);
        return { txSig: "stub-signature", potMint: args.potMint, winners };
      }
      // TODO(onchain): post answers Merkle root, request VRF, SETTLE (Magic Action) →
      //   pays winners from escrow PDA, commit_and_undelegate back to base layer.
      throw new Error("real chain worker not wired yet");
    },
  };
}
