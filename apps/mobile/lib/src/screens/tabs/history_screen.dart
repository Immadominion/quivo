import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';
import '../../data/history.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/atoms.dart';

/// History tab, every finished game, most recent first. Rows link to the settlement tx.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('History', style: QText.h1(context)),
            const SizedBox(height: 16),
            Expanded(
              child: history.when(
                loading: () => const Center(child: CircularProgressIndicator(color: QC.primary)),
                error: (_, __) => Center(child: Text('Couldn’t load history', style: QText.muted(context))),
                data: (list) => list.isEmpty
                    ? _Empty(onPlay: () => context.push('/join'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _HistoryRow(entry: list[i])
                            .animate()
                            .fadeIn(delay: (40 * i).ms, duration: 260.ms)
                            .slideY(begin: 0.06, end: 0),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          Text('Your finished games and winnings\nwill show up here.', style: QText.muted(context), textAlign: TextAlign.center),
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
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(color: QC.card, shape: QC.squircle(QC.rTile)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: entry.won ? QC.coinGrad : QC.primaryGrad,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('#${entry.rank}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Game ${entry.code}', style: QText.body(context).copyWith(fontWeight: FontWeight.w900)),
                  Text('$_when · ${entry.score} pts · ${entry.players} players', style: QText.muted(context)),
                ],
              ),
            ),
            if (entry.won)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: QC.coinB.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(QC.rBig)),
                child: Text('+${entry.amountUsdc.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: QC.coinB, fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}
