import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';

/// Bottom-nav shell. A compact floating pill with three icon tabs (Home / Wallet / History) and a
/// big raised JOIN button in the middle with concentric rings - joining by QR is Quivo's hero
/// action, the exact analog of the scanner button this pattern comes from. Profile is NOT a tab;
/// the home avatar opens it.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _go(int i) {
    HapticFeedback.lightImpact();
    navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    return Container(
      decoration: const BoxDecoration(gradient: QC.ground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          top: false,
          child: SizedBox(
            height: 112,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // The pill: compact (not edge-to-edge), night fill, border + hard offset shadow.
                Positioned(
                  left: 42,
                  right: 42,
                  bottom: 10,
                  child: Container(
                    height: 62,
                    decoration: ShapeDecoration(
                      color: QC.night,
                      shape: QC.squircle(31),
                      shadows: QC.shadowFloat,
                    ),
                    child: Row(
                      children: [
                        // Home + Wallet share the left half; History mirrors Home on the right.
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _TabDot(
                                icon: index == 0 ? FluentIcons.home_24_filled : FluentIcons.home_24_regular,
                                label: 'Home',
                                active: index == 0,
                                onTap: () => _go(0),
                              ),
                              _TabDot(
                                icon: index == 1 ? FluentIcons.wallet_24_filled : FluentIcons.wallet_24_regular,
                                label: 'Wallet',
                                active: index == 1,
                                onTap: () => _go(1),
                              ),
                            ],
                          ),
                        ),
                        // Well under the raised JOIN button.
                        const SizedBox(width: 74),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Invisible slot so History mirrors Home's distance from the edge.
                              const SizedBox(width: 44, height: 44),
                              _TabDot(
                                icon: index == 2 ? FluentIcons.history_24_filled : FluentIcons.history_24_regular,
                                label: 'History',
                                active: index == 2,
                                onTap: () => _go(2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // The raised JOIN action: concentric rings around a primary core, poking above
                // the pill. This is the one way into a game from anywhere in the shell.
                Positioned(
                  top: 0,
                  child: _JoinButton(onTap: () {
                    HapticFeedback.mediumImpact();
                    context.push('/join');
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only circular tab button inside the pill. Active = flat primary circle with a white ring;
/// inactive = bare icon at half opacity.
class _TabDot extends StatelessWidget {
  const _TabDot({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? QC.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: active ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Icon(icon, size: 22, color: active ? Colors.white : Colors.white.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Join a game',
      child: GestureDetector(
        onTap: onTap,
        // Ring 1: soft primary halo. Ring 2: card-colored with the ink border. Core: primary
        // circle, ink border, hard offset shadow, QR glyph.
        child: Container(
          width: 82,
          height: 82,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: QC.primary.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: QC.card,
              shape: BoxShape.circle,
              border: Border.all(color: QC.borderColor, width: QC.borderWidth),
            ),
            child: Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: QC.primary,
                shape: BoxShape.circle,
                border: Border.all(color: QC.borderColor, width: QC.borderWidth),
                boxShadow: QC.btnShadow(QC.primary),
              ),
              child: const Icon(FluentIcons.qr_code_24_filled, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
