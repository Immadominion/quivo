// Wire models - mirror the JSON the gateway relays (see services/realtime/src/gateway.ts).

class QuestionPublic {
  const QuestionPublic({required this.index, required this.prompt, required this.options, required this.durationMs});
  final int index;
  final String prompt;
  final List<String> options;
  final int durationMs;

  factory QuestionPublic.fromJson(Map<String, dynamic> j) => QuestionPublic(
        index: j['index'] as int,
        prompt: j['prompt'] as String,
        options: (j['options'] as List).cast<String>(),
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 20000,
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({required this.sessionId, required this.name, required this.wallet, required this.score, required this.rank, required this.delta});
  final String sessionId;
  final String name;
  final String wallet;
  final int score;
  final int rank;
  final int delta;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        sessionId: j['sessionId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        wallet: j['wallet'] as String? ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        delta: (j['delta'] as num?)?.toInt() ?? 0,
      );
}

class WinnerPayout {
  const WinnerPayout({required this.wallet, required this.rank, required this.amount});
  final String wallet;
  final int rank;
  final String amount; // base units (6dp)

  double get usdc => (int.tryParse(amount) ?? 0) / 1e6;
  factory WinnerPayout.fromJson(Map<String, dynamic> j) =>
      WinnerPayout(wallet: j['wallet'] as String, rank: (j['rank'] as num).toInt(), amount: j['amount'].toString());
}

class Settlement {
  const Settlement({required this.txSig, required this.potMint, required this.winners});
  final String txSig;
  final String potMint;
  final List<WinnerPayout> winners;

  bool get isReal => txSig != 'stub-signature';
  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        txSig: j['txSig'] as String,
        potMint: j['potMint'] as String? ?? '',
        winners: (j['winners'] as List).map((w) => WinnerPayout.fromJson((w as Map).cast<String, dynamic>())).toList(),
      );
}

class PlayerLite {
  const PlayerLite({required this.name, required this.score, required this.hasAnswered});
  final String name;
  final int score;
  final bool hasAnswered;
  factory PlayerLite.fromJson(Map<String, dynamic> j) => PlayerLite(
        name: j['name'] as String? ?? 'player',
        score: (j['score'] as num?)?.toInt() ?? 0,
        hasAnswered: j['hasAnswered'] as bool? ?? false,
      );
}

class MyStanding {
  const MyStanding({required this.score, required this.rank});
  final int score;
  final int rank;
  factory MyStanding.fromJson(Map<String, dynamic> j) =>
      MyStanding(score: (j['score'] as num?)?.toInt() ?? 0, rank: (j['rank'] as num?)?.toInt() ?? 0);
}
