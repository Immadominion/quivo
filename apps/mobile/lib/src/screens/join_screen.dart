import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import '../data/game_controller.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';

/// Enter a game code (the QR camera path lands in a later pass; the code field is the reliable core).
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});
  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valid => _ctrl.text.trim().length >= 4;

  Future<void> _join() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      final wallet = await ref.read(walletProvider.future);
      final prefs = ref.read(prefsProvider).value;
      final name = (prefs?.name.isNotEmpty ?? false) ? prefs!.name : 'player';
      await ref.read(gameControllerProvider.notifier).join(
            _ctrl.text.trim(),
            name: name,
            wallet: wallet.address,
          );
      if (mounted) context.push('/play');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t join: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GroundScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BackChip(onTap: () => context.pop()),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text('Enter game code', style: QText.h1(context)),
          const SizedBox(height: 6),
          Text('It’s on the big screen.', style: QText.muted(context)),
          const SizedBox(height: 28),
          QCard(
            child: Column(
              children: [
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 9, // Colyseus room ids are 9 chars (generateId(length = 9))
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _join(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 40, letterSpacing: 8, color: QC.ink),
                  cursorColor: QC.primary,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: 'ABCD',
                    hintStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 40, letterSpacing: 8, color: QC.line),
                  ),
                ),
                const SizedBox(height: 8),
                PillButton(label: 'Join', big: true, enabled: _valid && !_busy, onTap: _join),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'No account needed, you’re already in.',
              style: QText.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle, boxShadow: QC.shadowCard),
        child: const Icon(FluentIcons.arrow_left_24_regular, color: QC.ink, size: 22),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) => TextEditingValue(
        text: next.text.toUpperCase(),
        selection: next.selection,
        composing: TextRange.empty,
      );
}
