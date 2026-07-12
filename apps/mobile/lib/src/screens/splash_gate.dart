import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/game_controller.dart';
import '../data/history.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../debug/previews.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';

/// Debug boot shortcuts:
///   `--dart-define=QUIVO_PREVIEW=win`   jumps straight to that game phase.
///   `--dart-define=QUIVO_ROUTE=/wallet` boots straight to a tab (bypasses onboarding).
const String _kPreviewSlug = String.fromEnvironment('QUIVO_PREVIEW');
const String _kBootRoute = String.fromEnvironment('QUIVO_ROUTE');

/// `--dart-define=QUIVO_JOIN=ABCD` auto-joins a real room on boot (live end-to-end testing).
const String _kAutoJoin = String.fromEnvironment('QUIVO_JOIN');

/// Splash - warms the wallet + prefs, then routes to onboarding (first run) or home.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key});
  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final wallet = await ref.read(walletProvider.future);
    final prefs = await ref.read(prefsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (kDebugMode && _kPreviewSlug.isNotEmpty) {
      final preview = buildPreviews(wallet.address)[_kPreviewSlug];
      if (preview != null) {
        ref.read(gameControllerProvider.notifier).debugLoad(preview.state, myWallet: wallet.address);
        context.go('/play');
        return;
      }
    }
    if (kDebugMode && _kAutoJoin.isNotEmpty) {
      final name = prefs.name.isNotEmpty ? prefs.name : 'player';
      await ref.read(gameControllerProvider.notifier).join(_kAutoJoin, name: name, wallet: wallet.address);
      if (!mounted) return;
      context.go('/play');
      return;
    }
    if (kDebugMode && _kBootRoute.isNotEmpty) {
      if (const bool.fromEnvironment('QUIVO_SEED')) {
        await ref.read(historyProvider.notifier).seedDemo(DateTime.now().millisecondsSinceEpoch);
      }
      if (!mounted) return;
      context.go(_kBootRoute);
      return;
    }
    context.go(prefs.onboarded ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return GroundScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Coin(size: 68, spin: true),
            const SizedBox(height: 22),
            const Text('QUIVO', style: TextStyle(fontFamily: 'Clash Display', fontWeight: FontWeight.w700, fontSize: 42, color: QC.ink, letterSpacing: 1.5)),
          ],
        ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}
