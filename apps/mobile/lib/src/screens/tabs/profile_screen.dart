import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../data/history.dart';
import '../../data/prefs.dart';
import '../../data/wallet.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/atoms.dart';
import '../../widgets/gamify/gamify_atoms.dart';

/// "My Dossier" flavor, trait chips + a memory timeline, computed client-side from
/// [HistoryEntry] data already persisted locally. No new backend state (see DESIGN.md §5).
List<(String, Color)> _dossierTraits(HistoryStats stats, List<HistoryEntry> history) {
  if (stats.played == 0) return const [];
  final winRate = stats.wins / stats.played;
  final podiumCount = history.where((e) => e.rank >= 1 && e.rank <= 3).length;
  final podiumRate = podiumCount / stats.played;

  final traits = <(String, Color)>[];
  if (winRate >= 0.5) traits.add(('Sharp shooter', QC.winGreen));
  if (stats.played >= 10) traits.add(('Regular', QC.primaryText));
  if (podiumRate >= 0.4) traits.add(('Podium regular', QC.coinB));
  if (stats.earnedUsdc >= 20) traits.add(('High roller', QC.magenta));
  if (traits.isEmpty) traits.add(('Getting started', QC.muted));
  return traits.take(3).toList();
}

String _dossierDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

List<TimelineEntry> _dossierTimeline(List<HistoryEntry> history) {
  return history.take(5).map((e) {
    final note = e.won ? 'Placed #${e.rank} · +${e.amountUsdc.toStringAsFixed(2)} USDC' : 'Placed #${e.rank}';
    return TimelineEntry(date: _dossierDate(e.playedAtMs), note: note, dotColor: e.won ? QC.winGreen : QC.danger);
  }).toList();
}

/// Profile + settings hub, identity, stats, and the sound/haptics toggles.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QC.card,
        shape: QC.squircle(QC.rCard),
        title: Text('Your name', style: QText.title(context)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 16,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(counterText: '', hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) ref.read(prefsProvider.notifier).setName(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider).value;
    final wallet = ref.watch(walletProvider).value;
    final stats = ref.watch(historyStatsProvider);
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final name = (prefs?.name.isNotEmpty ?? false) ? prefs!.name : 'player';
    final traits = _dossierTraits(stats, history);
    final timeline = _dossierTimeline(history);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text('You', style: QText.h1(context)),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                if (wallet != null) PlayerAvatar(seed: wallet.address, size: 84, initial: name),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _editName(context, ref, name),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: QText.h2(context)),
                      const SizedBox(width: 8),
                      const Icon(FluentIcons.edit_20_filled, size: 18, color: QC.muted),
                    ],
                  ),
                ),
                if (wallet != null) Text(wallet.short, style: QText.mono(context).copyWith(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          QCard(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(value: '${stats.played}', label: 'Games'),
                _Divider(),
                _Stat(value: '${stats.wins}', label: 'Wins'),
                _Divider(),
                _Stat(value: stats.earnedUsdc.toStringAsFixed(1), label: 'USDC won'),
              ],
            ),
          ),
          if (traits.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in traits) TraitChip(label: t.$1, color: t.$2)],
            ),
          ],
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Recent form', style: QText.title(context)),
            const SizedBox(height: 12),
            TimelineList(entries: timeline),
          ],
          const SizedBox(height: 18),
          Text('Settings', style: QText.title(context)),
          const SizedBox(height: 10),
          QCard(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                _ToggleRow(
                  icon: FluentIcons.speaker_2_24_filled,
                  label: 'Sound',
                  value: prefs?.sound ?? true,
                  onChanged: (v) => ref.read(prefsProvider.notifier).setSound(v),
                ),
                const Divider(height: 1, color: QC.line),
                _ToggleRow(
                  icon: FluentIcons.phone_vibrate_24_filled,
                  label: 'Haptics',
                  value: prefs?.haptics ?? true,
                  onChanged: (v) => ref.read(prefsProvider.notifier).setHaptics(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          QCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(FluentIcons.info_20_regular, color: QC.primaryText, size: 20),
                    const SizedBox(width: 10),
                    Text('About Quivo', style: QText.body(context).copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Live trivia game shows where the whole room plays on their phones and winners are paid '
                  'real crypto on Solana, instantly, on-chain. Built on MagicBlock.',
                  style: QText.muted(context),
                ),
                const SizedBox(height: 10),
                Text('Devnet · v0.1.0', style: QText.mono(context).copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: QC.ink)),
        const SizedBox(height: 2),
        Text(label, style: QText.muted(context)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 34, color: QC.line);
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: QC.body, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: QText.body(context).copyWith(fontWeight: FontWeight.w700))),
          Switch(value: value, activeThumbColor: Colors.white, activeTrackColor: QC.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
