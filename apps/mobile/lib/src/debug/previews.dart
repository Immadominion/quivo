import '../data/game_controller.dart';
import '../data/models.dart';

/// Fabricated game states for design QA + offline demo. Keyed by a short slug so both the interactive
/// PreviewScreen and the `--dart-define=QUIVO_PREVIEW=<slug>` boot shortcut share one source of truth.
const _names = ['ada', 'bola', 'chidi', 'deji', 'ephraim', 'funke', 'gozie', 'halima'];

const _q = QuestionPublic(
  index: 1,
  prompt: "MagicBlock's Ephemeral Rollups mainly buy you…",
  options: ['More token supply', 'Sub-50ms latency & gasless writes', 'Fewer validators', 'Free NFTs'],
  durationMs: 15000,
);

List<PlayerLite> _players(int n) =>
    [for (var i = 0; i < n; i++) PlayerLite(name: _names[i % _names.length], score: 0, hasAnswered: i.isEven)];

List<LeaderboardEntry> _board(String myWallet, {int myRank = 3}) {
  const scores = [2480, 2210, 1990, 1740, 1520, 1310, 1080, 860];
  return [
    for (var i = 0; i < scores.length; i++)
      LeaderboardEntry(
        sessionId: 's$i',
        name: (i + 1) == myRank ? 'You' : _names[i % _names.length],
        wallet: (i + 1) == myRank ? myWallet : 'W${i}peerpeerpeerpeerpeerpeerpeerpeer',
        score: scores[i],
        rank: i + 1,
        delta: (i + 1) == myRank ? 820 : 0,
      ),
  ];
}

/// Slug → labelled fabricated state. `deadline` uses now-relative time so countdowns tick live.
Map<String, ({String label, GameState state})> buildPreviews(String myWallet) {
  final board = _board(myWallet, myRank: 3);
  final settlement = Settlement(
    txSig: '5Qw8xVexampleSigForPreviewOnly1111111111111111111111111111111111',
    potMint: 'TESTUSDC',
    winners: [
      WinnerPayout(wallet: board[0].wallet, rank: 1, amount: '2500000'),
      WinnerPayout(wallet: board[1].wallet, rank: 2, amount: '1500000'),
      WinnerPayout(wallet: myWallet, rank: 3, amount: '1000000'),
    ],
  );
  return {
    'lobby': (label: 'Lobby (8 players)', state: GameState(phase: GamePhase.lobby, code: 'QUIV', players: _players(8))),
    'question': (
      label: 'Question (open)',
      state: GameState(phase: GamePhase.question, question: _q, questionDeadline: DateTime.now().add(const Duration(seconds: 15)))
    ),
    'answered': (
      label: 'Question (answered)',
      state: GameState(phase: GamePhase.question, question: _q, myChoice: 1, questionDeadline: DateTime.now().add(const Duration(seconds: 9)))
    ),
    'correct': (
      label: 'Reveal (correct)',
      state: GameState(phase: GamePhase.reveal, question: _q, myChoice: 1, correctChoice: 1, board: board)
    ),
    'wrong': (
      label: 'Reveal (wrong)',
      state: GameState(phase: GamePhase.reveal, question: _q, myChoice: 2, correctChoice: 1, board: board)
    ),
    'settling': (label: 'Settling', state: const GameState(phase: GamePhase.settling)),
    'win': (label: 'Results (you won)', state: GameState(phase: GamePhase.complete, board: board, settlement: settlement)),
    'placed': (
      label: 'Results (placed)',
      state: GameState(phase: GamePhase.complete, board: _board(myWallet, myRank: 5), settlement: settlement)
    ),
    'error': (label: 'Error / offline', state: const GameState(phase: GamePhase.error, error: 'No game found for that code.')),
  };
}
