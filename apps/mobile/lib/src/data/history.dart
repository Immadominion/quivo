import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished game, kept locally so the History tab has something real to show. (Server-side
/// history would need an indexer; a local log is the honest MVP and survives restarts.)
class HistoryEntry {
  const HistoryEntry({
    required this.code,
    required this.playedAtMs,
    required this.rank,
    required this.players,
    required this.score,
    required this.won,
    required this.amountUsdc,
    required this.txSig,
  });

  final String code;
  final int playedAtMs;
  final int rank;
  final int players;
  final int score;
  final bool won;
  final double amountUsdc;
  final String txSig;

  Map<String, dynamic> toJson() => {
        'code': code,
        'playedAtMs': playedAtMs,
        'rank': rank,
        'players': players,
        'score': score,
        'won': won,
        'amountUsdc': amountUsdc,
        'txSig': txSig,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        code: j['code'] as String? ?? '',
        playedAtMs: (j['playedAtMs'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        players: (j['players'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toInt() ?? 0,
        won: j['won'] as bool? ?? false,
        amountUsdc: (j['amountUsdc'] as num?)?.toDouble() ?? 0,
        txSig: j['txSig'] as String? ?? '',
      );
}

class HistoryController extends AsyncNotifier<List<HistoryEntry>> {
  static const _key = 'match_history_v1';

  @override
  Future<List<HistoryEntry>> build() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? const [];
    return raw.map((s) => HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> add(HistoryEntry e) async {
    final p = await SharedPreferences.getInstance();
    final current = <HistoryEntry>[e, ...?state.value].take(50).toList();
    await p.setStringList(_key, current.map((h) => jsonEncode(h.toJson())).toList());
    state = AsyncData(current);
  }

  /// Debug-only: populate a few sample games so the History/Wallet tabs can be shown with data.
  Future<void> seedDemo(int nowMs) async {
    final samples = [
      HistoryEntry(code: 'QUIV', playedAtMs: nowMs - 900000, rank: 1, players: 24, score: 4820, won: true, amountUsdc: 12.50, txSig: 'DemoSig1'),
      HistoryEntry(code: 'PLAY', playedAtMs: nowMs - 7200000, rank: 3, players: 18, score: 3110, won: true, amountUsdc: 4.00, txSig: 'DemoSig2'),
      HistoryEntry(code: 'GAME', playedAtMs: nowMs - 172800000, rank: 7, players: 31, score: 2040, won: false, amountUsdc: 0, txSig: 'DemoSig3'),
    ];
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, samples.map((h) => jsonEncode(h.toJson())).toList());
    state = AsyncData(samples);
  }
}

final historyProvider = AsyncNotifierProvider<HistoryController, List<HistoryEntry>>(HistoryController.new);

/// Aggregate stats for the profile header.
class HistoryStats {
  const HistoryStats({required this.played, required this.wins, required this.earnedUsdc});
  final int played;
  final int wins;
  final double earnedUsdc;
}

final historyStatsProvider = Provider<HistoryStats>((ref) {
  final list = ref.watch(historyProvider).value ?? const [];
  return HistoryStats(
    played: list.length,
    wins: list.where((e) => e.won).length,
    earnedUsdc: list.fold<double>(0, (a, e) => a + e.amountUsdc),
  );
});
