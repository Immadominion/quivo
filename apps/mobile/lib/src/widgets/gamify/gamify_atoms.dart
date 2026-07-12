import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Section title + trailing "See all" - every list section gets both, never a title alone.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: QText.title(context)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('See all', style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 13, color: QC.primaryText)),
                const SizedBox(width: 2),
                Icon(FluentIcons.chevron_right_16_filled, size: 16, color: QC.primaryText),
              ],
            ),
          ),
      ],
    );
  }
}

/// Blue pill - anywhere a result is pending/locked.
class LockedBadge extends StatelessWidget {
  const LockedBadge({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: QC.infoPale, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.lock_closed_16_filled, size: 12, color: QC.info),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 11.5, color: QC.info)),
        ],
      ),
    );
  }
}

/// Last-5 form squares - derived client-side from history, no new backend state.
class StreakRow extends StatelessWidget {
  const StreakRow({super.key, required this.results, this.size = 22});
  /// true = correct/won, false = wrong/lost, null = no data for that slot.
  final List<bool?> results;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in results)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: r == null ? QC.line : (r ? QC.winGreen : QC.danger),
                shape: QC.squircle(size * 0.32),
              ),
              child: r == null
                  ? null
                  : Text(r ? 'W' : 'L', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.5)),
            ),
          ),
      ],
    );
  }
}

/// Three-column mono stat row - used in verdict/results cards and stat cards.
class StatTrio extends StatelessWidget {
  const StatTrio({super.key, required this.items, this.dark = true});
  final List<(String label, String value, Color? valueColor)> items;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fillColor = dark ? Colors.white.withValues(alpha: 0.06) : QC.cardTint;
    final labelColor = dark ? Colors.white.withValues(alpha: 0.5) : QC.muted;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: ShapeDecoration(color: fillColor, shape: QC.squircle(14)),
              child: Column(
                children: [
                  Text(items[i].$2, style: QText.mono(context, size: 16, color: items[i].$3 ?? (dark ? Colors.white : QC.ink))),
                  const SizedBox(height: 2),
                  Text(items[i].$1, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: labelColor)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Small trait/bias pill tag - flavor computed from history, not new backend state.
class TraitChip extends StatelessWidget {
  const TraitChip({super.key, required this.label, this.color = QC.primaryText, this.bg});
  final String label;
  final Color color;
  final Color? bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg ?? color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 11.5, color: color)),
    );
  }
}

/// One entry in a vertical dotted memory timeline.
class TimelineEntry {
  const TimelineEntry({required this.date, required this.note, this.dotColor = QC.winGreen});
  final String date;
  final String note;
  final Color dotColor;
}

class TimelineList extends StatelessWidget {
  const TimelineList({super.key, required this.entries});
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 6),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: QC.line, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(left: 16, bottom: i == entries.length - 1 ? 0 : 16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -23,
                    top: 3,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: entries[i].dotColor, shape: BoxShape.circle, border: Border.all(color: QC.groundTop, width: 3)),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entries[i].date, style: QText.mono(context, size: 10, color: QC.muted)),
                      const SizedBox(height: 2),
                      Text(entries[i].note, style: const TextStyle(fontFamily: 'Satoshi', fontSize: 13, fontWeight: FontWeight.w600, color: QC.ink)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
