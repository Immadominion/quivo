import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/balance.dart';
import '../../data/history.dart';
import '../../data/wallet.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/atoms.dart';
import '../../widgets/gamify/night_card.dart';

/// Wallet tab, devnet SOL balance, lifetime winnings, and the receive address (QR + copy).
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  Future<void> _faucet() async {
    final uri = Uri.parse('https://faucet.solana.com');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).value;
    final balance = ref.watch(balanceProvider);
    final stats = ref.watch(historyStatsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(balanceProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Wallet', style: QText.h1(context)),
                const _DevnetChip(),
              ],
            ),
            const SizedBox(height: 18),
            NightCard(
              glow: QC.coinB,
              glowAlignment: Alignment.topRight,
              child: Column(
                children: [
                  Text('Lifetime winnings',
                      style: QText.muted(context).copyWith(color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Coin(size: 30),
                      const SizedBox(width: 10),
                      Text('${stats.earnedUsdc.toStringAsFixed(2)} USDC',
                          style: QText.mono(context, size: 34, weight: FontWeight.w800, color: QC.coinA)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(QC.rBig),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.checkmark_circle_16_filled, size: 14, color: QC.coinA),
                        const SizedBox(width: 6),
                        Text('Secured on Solana',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.75),
                                letterSpacing: 0.2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.12)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MiniStat(label: 'Games', value: '${stats.played}'),
                      _MiniStat(label: 'Wins', value: '${stats.wins}'),
                      balance.when(
                        data: (b) => _MiniStat(label: 'SOL', value: b.sol.toStringAsFixed(3)),
                        loading: () => const _MiniStat(label: 'SOL', value: '…'),
                        error: (_, __) => const _MiniStat(label: 'SOL', value: '-'),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 16),
            // History left the nav (three-element bar); its wallet-side entry point is this row.
            GestureDetector(
              onTap: () => context.push('/history'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: ShapeDecoration(
                  color: QC.card,
                  shape: QC.squircle(QC.rTile),
                  shadows: QC.shadowCard,
                ),
                child: Row(
                  children: [
                    const Icon(FluentIcons.history_24_regular, size: 20, color: QC.ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Game history', style: QText.body(context).copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text('${stats.played} games', style: QText.mono(context, size: 12, color: QC.muted)),
                    const SizedBox(width: 6),
                    const Icon(FluentIcons.chevron_right_16_filled, size: 16, color: QC.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            QCard(
              child: Column(
                children: [
                  Text('Your receive address', style: QText.title(context)),
                  const SizedBox(height: 4),
                  Text('Prizes land here automatically.', style: QText.muted(context), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (wallet != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: ShapeDecoration(color: Colors.white, shape: QC.squircle(QC.rTile)),
                      child: QrImageView(
                        data: wallet.address,
                        version: QrVersions.auto,
                        size: 150,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: QC.ink),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: QC.ink),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (wallet != null)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: wallet.address));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: ShapeDecoration(color: QC.cardTint, shape: QC.squircle(QC.rTile)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(wallet.short, style: QText.mono(context))),
                            const SizedBox(width: 10),
                            const Icon(FluentIcons.copy_20_regular, size: 18, color: QC.primaryText),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PillButton(
              label: 'Get devnet SOL',
              gradient: const LinearGradient(colors: [QC.winGreen, QC.winLime]),
              rgb: QC.winGreen,
              leading: const Icon(FluentIcons.drop_20_filled, color: Colors.white, size: 20),
              onTap: _faucet,
            ),
          ],
        ),
      ),
    );
  }
}

class _DevnetChip extends StatelessWidget {
  const _DevnetChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: QC.winGreen.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(QC.rBig)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: QC.winGreen, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Devnet', style: TextStyle(fontWeight: FontWeight.w800, color: QC.winGreen, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
        Text(label,
            style: QText.muted(context).copyWith(color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}
