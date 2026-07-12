import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../widgets/atoms.dart';
import '../widgets/gamify/host_card.dart';

/// Home hub - greet, wallet chip, and the big Join CTA. Join is wired to the QR/code flow in It2;
/// balance + recent results land in It5 behind a bottom-nav shell.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Q's rotating hype lines for the no-active-game home state. Picked pseudo-randomly (by day of
  /// month) so it feels alive without any new state - purely decorative, upbeat, never mean.
  static const _hypeLines = [
    "Nobody's beaten last week's high score yet. Nobody.",
    "Fastest finger wins ties. Don't overthink it.",
    "I've got a good feeling about this round. I say that every round.",
    "Somewhere out there a lobby is waiting for exactly you.",
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider).value;
    final wallet = ref.watch(walletProvider).value;
    final name = (prefs?.name.isNotEmpty ?? false) ? prefs!.name : 'player';
    final hypeLine = _hypeLines[DateTime.now().day % _hypeLines.length];

    return GroundScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hey $name 👋', style: QText.h2(context)),
                    Text('ready to play?', style: QText.muted(context)),
                  ],
                ),
              ),
              if (wallet != null)
                GestureDetector(
                  // Debug builds: long-press the avatar to open the phase preview harness.
                  onLongPress: kDebugMode ? () => context.push('/preview') : null,
                  child: PlayerAvatar(seed: wallet.address, size: 46),
                ),
            ],
          ),
          const SizedBox(height: 22),
          HostCard(line: hypeLine, ctaLabel: 'Join now', onTap: () => context.push('/join')),
          const Spacer(),
          QCard(
            child: Column(
              children: [
                const Coin(size: 46),
                const SizedBox(height: 14),
                Text('Join a live game', style: QText.title(context)),
                const SizedBox(height: 8),
                Text(
                  'Scan the QR on the big screen, or enter the game code.',
                  style: QText.muted(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PillButton(label: 'Join a game', big: true, onTap: () => context.push('/join')),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.12, end: 0, curve: Curves.easeOutBack),
          const SizedBox(height: 28),
          Row(
            children: const [
              Expanded(child: _Step(emoji: '📷', label: 'Scan or\nenter code')),
              Expanded(child: _Step(emoji: '⚡', label: 'Answer\nfast')),
              Expanded(child: _Step(emoji: '🪙', label: 'Win real\ncrypto')),
            ],
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.emoji, required this.label});
  final String emoji;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: QText.muted(context).copyWith(fontWeight: FontWeight.w700, height: 1.2)),
      ],
    );
  }
}
