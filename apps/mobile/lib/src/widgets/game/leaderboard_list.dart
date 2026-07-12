import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../atoms.dart';

/// Ranked player rows with your own highlighted. Shared by the reveal and results screens.
class LeaderboardList extends StatelessWidget {
  const LeaderboardList({super.key, required this.board, required this.myWallet, this.max = 8});
  final List<LeaderboardEntry> board;
  final String myWallet;
  final int max;

  @override
  Widget build(BuildContext context) {
    final rows = board.take(max).toList();
    final mine = board.indexWhere((e) => e.wallet == myWallet);
    final showMineSeparately = mine >= max;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (var i = 0; i < rows.length; i++)
          _Row(entry: rows[i], me: rows[i].wallet == myWallet)
              .animate()
              .fadeIn(delay: (50 * i).ms, duration: 260.ms)
              .slideX(begin: 0.1, end: 0),
        if (showMineSeparately) ...[
          const SizedBox(height: 6),
          Center(child: Text('· · ·', style: QText.muted(context))),
          const SizedBox(height: 6),
          _Row(entry: board[mine], me: true),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.me});
  final LeaderboardEntry entry;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final medal = entry.rank <= 3;
    final rankColor = switch (entry.rank) {
      1 => QC.coinB,
      2 => const Color(0xFF7C88A8), // silver, deepened from the reference's steel-grey for contrast on the bright ground
      3 => const Color(0xFFC17A3E), // bronze, deepened slightly for the same reason
      _ => QC.muted,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: me ? QC.cardTint : QC.card,
        shadows: me ? QC.btnShadow(QC.primary) : QC.shadowCard,
        shape: QC.squircle(QC.rTile),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              medal ? '${entry.rank}' : '${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: medal ? 20 : 16, color: rankColor),
            ),
          ),
          const SizedBox(width: 6),
          PlayerAvatar(seed: entry.wallet, size: 36, initial: entry.name),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              me ? 'You' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: me ? FontWeight.w900 : FontWeight.w700, fontSize: 16, color: QC.body),
            ),
          ),
          Text(
            '${entry.score}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: QC.ink),
          ),
        ],
      ),
    );
  }
}
