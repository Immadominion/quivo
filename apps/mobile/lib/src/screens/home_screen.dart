import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/history.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/gamify/gamify_atoms.dart';

/// Home is a focused game hub: identity, the next join action, and recent activity.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _ago(int ms) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}';
  }

  void _copyAddress(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showReceiveSheet(BuildContext context, Wallet wallet) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReceiveSheet(
        wallet: wallet,
        onCopy: () => _copyAddress(context, wallet.address),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider).value;
    final wallet = ref.watch(walletProvider).value;
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final name = (prefs?.name.isNotEmpty ?? false) ? prefs!.name : 'player';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey,',
                      style: QText.h1(
                        context,
                      ).copyWith(fontSize: 38, height: 1.0),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: QC.primary,
                        shape: QC.squircle(16),
                        shadows: QC.shadowCard,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'Clash Display',
                            fontWeight: FontWeight.w700,
                            fontSize: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ready when the room goes live.',
                      style: QText.muted(context),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 22),
          const _FeaturedRoomCard()
              .animate()
              .fadeIn(delay: 60.ms, duration: 320.ms)
              .slideY(begin: 0.05, end: 0),
          if (wallet != null) ...[
            const SizedBox(height: 18),
            _ReceiveHomeRow(onTap: () => _showReceiveSheet(context, wallet)),
          ],
          const SizedBox(height: 26),
          SectionHeader(
            title: 'History',
            onSeeAll: history.isEmpty ? null : () => context.push('/history'),
          ),
          const SizedBox(height: 12),
          if (history.isNotEmpty) ...[
            for (final (i, e) in history.take(3).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GameRow(entry: e, ago: _ago(e.playedAtMs))
                    .animate()
                    .fadeIn(delay: (120 + 60 * i).ms, duration: 260.ms)
                    .slideY(begin: 0.06, end: 0),
              ),
          ] else
            const _EmptyGames().animate().fadeIn(
              delay: 120.ms,
              duration: 300.ms,
            ),
        ],
      ),
    );
  }
}

class _FeaturedRoomCard extends StatelessWidget {
  const _FeaturedRoomCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ShapeDecoration(
        color: QC.night,
        shape: QC.squircle(QC.rBig),
        shadows: QC.shadowFloat,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: QC.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FluentIcons.qr_code_24_filled,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const Spacer(),
              Text(
                'LIVE ROOM',
                style: QText.overline(
                  context,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Live room',
            style: QText.h1(
              context,
            ).copyWith(color: Colors.white, fontSize: 32, height: 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            'When the host opens a game, use the center scanner below to enter the room.',
            style: QText.muted(context).copyWith(
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveHomeRow extends StatelessWidget {
  const _ReceiveHomeRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: QCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        color: QC.cardTint,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: QC.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FluentIcons.arrow_download_24_filled,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receive',
                    style: QText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Open your payout QR code.',
                    style: QText.muted(context),
                  ),
                ],
              ),
            ),
            const Icon(
              FluentIcons.chevron_right_24_filled,
              color: QC.primaryText,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveSheet extends StatelessWidget {
  const _ReceiveSheet({required this.wallet, required this.onCopy});
  final Wallet wallet;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        decoration: ShapeDecoration(color: QC.card, shape: QC.squircle(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: QC.line,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            Text('Receive', style: QText.h1(context)),
            const SizedBox(height: 6),
            Text(
              'Prizes and transfers land at this wallet.',
              textAlign: TextAlign.center,
              style: QText.muted(context),
            ),
            const SizedBox(height: 24),
            QrImageView(
              data: wallet.address,
              version: QrVersions.auto,
              size: 220,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: QC.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: QC.ink,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onCopy,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: ShapeDecoration(
                  color: QC.cardTint,
                  shape: QC.squircle(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        wallet.short,
                        textAlign: TextAlign.center,
                        style: QText.mono(context, size: 14, color: QC.ink),
                      ),
                    ),
                    const Icon(
                      FluentIcons.copy_20_regular,
                      color: QC.primaryText,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGames extends StatelessWidget {
  const _EmptyGames();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Icon(
            FluentIcons.ticket_diagonal_24_regular,
            color: QC.muted,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text('No games yet', style: QText.title(context)),
          const SizedBox(height: 6),
          Text(
            'When you play, results and payouts appear here.',
            textAlign: TextAlign.center,
            style: QText.muted(context),
          ),
        ],
      ),
    );
  }
}

/// One compact recent-game row: rank badge, code + when, winnings (or score) trailing.
class _GameRow extends StatelessWidget {
  const _GameRow({required this.entry, required this.ago});
  final HistoryEntry entry;
  final String ago;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ShapeDecoration(
        color: QC.card,
        shape: QC.squircle(QC.rTile),
        shadows: QC.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: entry.won ? QC.coinB : QC.cardTint,
              shape: BoxShape.circle,
              border: Border.all(color: QC.borderColor, width: QC.borderWidth),
            ),
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: entry.won ? Colors.white : QC.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game ${entry.code}',
                  style: QText.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$ago · ${entry.players} players',
                  style: QText.muted(context).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            entry.won
                ? '+${entry.amountUsdc.toStringAsFixed(2)}'
                : '${entry.score} pts',
            style: QText.mono(
              context,
              size: 13,
              color: entry.won ? QC.winGreen : QC.muted,
            ),
          ),
        ],
      ),
    );
  }
}
