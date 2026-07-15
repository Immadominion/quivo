import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';
import '../../data/history.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/atoms.dart';

/// Every finished game, most recent first; rows link to the settlement tx. Pushed above the shell
/// (reached from Home's "See all" and from Wallet), so it brings its own ground + back chip.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final stats = ref.watch(historyStatsProvider);

    return GroundScaffold(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: QC.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: QC.borderColor,
                      width: QC.borderWidth,
                    ),
                    boxShadow: QC.shadowCard,
                  ),
                  child: const Icon(
                    FluentIcons.arrow_left_24_regular,
                    size: 20,
                    color: QC.ink,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text('History', style: QText.h1(context)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: history.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: QC.primary),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Couldn’t load history',
                  style: QText.muted(context),
                ),
              ),
              data: (list) => list.isEmpty
                  ? _Empty(onPlay: () => context.push('/join'))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        _HistorySummary(stats: stats),
                        const SizedBox(height: 18),
                        for (final (i, entry) in list.indexed)
                          _HistoryRow(entry: entry)
                              .animate()
                              .fadeIn(delay: (40 * i).ms, duration: 260.ms)
                              .slideY(begin: 0.06, end: 0),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.stats});
  final HistoryStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ShapeDecoration(
        color: QC.night,
        shape: QC.squircle(QC.rBig),
        shadows: QC.shadowCard,
      ),
      child: Row(
        children: [
          _SummaryStat(label: 'Games', value: '${stats.played}'),
          _SummaryDivider(),
          _SummaryStat(label: 'Wins', value: '${stats.wins}'),
          _SummaryDivider(),
          _SummaryStat(
            label: 'USDC',
            value: stats.earnedUsdc.toStringAsFixed(2),
            valueColor: QC.coinB,
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: QText.mono(
              context,
              size: 17,
              color: valueColor ?? Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: QText.muted(context).copyWith(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 34,
    color: Colors.white.withValues(alpha: 0.12),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPlay});
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Coin(size: 54),
          const SizedBox(height: 18),
          Text('No games yet', style: QText.title(context)),
          const SizedBox(height: 6),
          Text(
            'Your finished games and winnings\nwill show up here.',
            style: QText.muted(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          PillButton(label: 'Join a game', onTap: onPlay),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final HistoryEntry entry;

  Future<void> _open() async {
    if (entry.txSig.isEmpty || entry.txSig == 'stub-signature') return;
    final uri = Uri.parse('$kExplorerTx${entry.txSig}$kCluster');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String get _when {
    final d = DateTime.fromMillisecondsSinceEpoch(entry.playedAtMs);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: ShapeDecoration(
          color: QC.card,
          shape: QC.squircle(QC.rTile),
          shadows: QC.shadowCard,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.won ? QC.coinB : QC.cardTint,
                shape: BoxShape.circle,
                border: Border.all(
                  color: QC.borderColor,
                  width: QC.borderWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: entry.won ? Colors.white : QC.ink,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Game ${entry.code}',
                    style: QText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '$_when · ${entry.score} pts · ${entry.players} players',
                    style: QText.muted(context),
                  ),
                ],
              ),
            ),
            if (entry.won)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: QC.coinB.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(QC.rBig),
                ),
                child: Text(
                  '+${entry.amountUsdc.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: QC.coinB,
                    fontSize: 14,
                  ),
                ),
              )
            else
              Text(
                '${entry.score} pts',
                style: QText.mono(context, size: 12, color: QC.muted),
              ),
          ],
        ),
      ),
    );
  }
}
