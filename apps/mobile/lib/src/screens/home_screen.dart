import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/history.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/gamify/gamify_atoms.dart';
import '../widgets/gamify/host_card.dart';

/// Home. Joining lives on the nav's raised JOIN button, so this screen is a real hub: a big
/// personal greeting as the hero, Q talking, your form, and your recent games. Everything on it is
/// real persisted data - no instructional filler.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Q's line, derived from the player's real persisted record (the Cleo pattern: cite the user's
  /// own numbers; users can't dismiss their own stats as filler). State-triggered, most-specific
  /// state first; it changes when your record changes, never on a schedule. Voice: hype, tease,
  /// never mean.
  static String _qLine(List<HistoryEntry> history) {
    if (history.isEmpty) {
      return "First round's the scariest. After that you're hooked. I'll be watching.";
    }
    var streak = 0;
    for (final e in history) {
      if (!e.won) break;
      streak++;
    }
    final last = history.first;
    if (streak >= 2) {
      return '$streak wins on the bounce. One more and I name a trophy after you.';
    }
    if (last.won) {
      return '+${last.amountUsdc.toStringAsFixed(2)} USDC last game. The room knows your name now.';
    }
    if (last.rank <= 3) {
      return '#${last.rank} of ${last.players} last game. One spot off the money. One.';
    }
    return '#${last.rank} of ${last.players} last time. We both know that was a warm-up.';
  }

  String _ago(int ms) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider).value;
    final wallet = ref.watch(walletProvider).value;
    final stats = ref.watch(historyStatsProvider);
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final name = (prefs?.name.isNotEmpty ?? false) ? prefs!.name : 'player';
    final qLine = _qLine(history);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        children: [
          // ----- Hero: the greeting IS the headline. Name sits in a tilted primary chip. -----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hey,', style: QText.h1(context).copyWith(fontSize: 38, height: 1.0)),
                    const SizedBox(height: 6),
                    Transform.rotate(
                      angle: -0.035,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: ShapeDecoration(
                          color: QC.primary,
                          shape: QC.squircle(14),
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
                    ),
                    const SizedBox(height: 10),
                    Text('Ready to play?', style: QText.muted(context)),
                  ],
                ),
              ),
              if (wallet != null)
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  // Debug builds: long-press the avatar to open the phase preview harness.
                  onLongPress: kDebugMode ? () => context.push('/preview') : null,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: QC.borderColor, width: QC.borderWidth),
                      boxShadow: QC.shadowCard,
                    ),
                    child: PlayerAvatar(seed: wallet.address, size: 52, initial: name),
                  ),
                ),
            ],
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 22),

          // ----- Q, the host. -----
          HostCard(line: qLine, ctaLabel: 'Join a game', onTap: () => context.push('/join')),
          const SizedBox(height: 16),

          // ----- Your form: real stats + last-5 streak. -----
          QCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('YOUR FORM', style: QText.overline(context)),
                    if (history.isNotEmpty)
                      StreakRow(
                        results: [
                          for (var i = 0; i < 5; i++) i < history.length ? history[i].won : null,
                        ],
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                StatTrio(
                  dark: false,
                  items: [
                    ('GAMES', '${stats.played}', null),
                    ('WINS', '${stats.wins}', QC.winGreen),
                    ('USDC WON', stats.earnedUsdc.toStringAsFixed(2), QC.coinB),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 300.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 22),

          // ----- Recent games (real history) or the first-game nudge. -----
          if (history.isNotEmpty) ...[
            SectionHeader(title: 'Recent games', onSeeAll: () => context.push('/history')),
            const SizedBox(height: 12),
            for (final (i, e) in history.take(3).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GameRow(entry: e, ago: _ago(e.playedAtMs))
                    .animate()
                    .fadeIn(delay: (120 + 60 * i).ms, duration: 260.ms)
                    .slideY(begin: 0.06, end: 0),
              ),
          ] else
            QCard(
              color: QC.cardTint,
              child: Column(
                children: [
                  Text('No games yet', style: QText.title(context)),
                  const SizedBox(height: 6),
                  Text(
                    'Tap the big button below when the host puts the QR on the screen.',
                    textAlign: TextAlign.center,
                    style: QText.muted(context),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
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
                Text('Game ${entry.code}', style: QText.body(context).copyWith(fontWeight: FontWeight.w700)),
                Text('$ago · ${entry.players} players', style: QText.muted(context).copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(
            entry.won ? '+${entry.amountUsdc.toStringAsFixed(2)}' : '${entry.score} pts',
            style: QText.mono(context, size: 13, color: entry.won ? QC.winGreen : QC.muted),
          ),
        ],
      ),
    );
  }
}
