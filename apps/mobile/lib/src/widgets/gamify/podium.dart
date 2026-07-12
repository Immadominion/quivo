import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../atoms.dart';

/// The 3-column podium, crown on #1, height-coded bars. Reference: Touchline's Squad Ladder.
/// See docs/DESIGN.md §2.3.
class Podium extends StatelessWidget {
  const Podium({super.key, required this.top3, required this.myWallet});
  final List<LeaderboardEntry> top3;
  final String myWallet;

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? at(int rank) => top3.where((e) => e.rank == rank).cast<LeaderboardEntry?>().firstWhere((_) => true, orElse: () => null);
    final order = [at(2), at(1), at(3)];
    final heights = [60.0, 86.0, 46.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: order[i] == null
                ? const SizedBox.shrink()
                : _Plinth(entry: order[i]!, height: heights[i], me: order[i]!.wallet == myWallet),
          ),
      ],
    );
  }
}

class _Plinth extends StatelessWidget {
  const _Plinth({required this.entry, required this.height, required this.me});
  final LeaderboardEntry entry;
  final double height;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final gold = entry.rank == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gold) const Icon(FluentIcons.trophy_24_filled, color: QC.coinB, size: 22),
        PlayerAvatar(seed: entry.wallet, size: gold ? 54 : 44, initial: entry.name),
        const SizedBox(height: 6),
        Text(
          me ? 'You' : entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Clash Display', fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.white),
        ),
        Text('${entry.score}', style: QText.mono(context, size: 11, color: const Color(0xFFC7BEDD))),
        const SizedBox(height: 6),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: ShapeDecoration(
            gradient: gold ? QC.coinGrad : null,
            color: gold ? null : Colors.white.withValues(alpha: 0.08),
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(top: const SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.6)),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${entry.rank}',
            style: TextStyle(fontFamily: 'Clash Display', fontWeight: FontWeight.w700, fontSize: 17, color: gold ? Colors.white : const Color(0xFFC0CABF)),
          ),
        ),
      ],
    );
  }
}
