import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';

/// Bottom-nav shell (Home / Wallet / History / Profile) with a floating Candy nav bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (iconRegular: FluentIcons.grid_24_regular, iconFilled: FluentIcons.grid_24_filled, label: 'Play'),
    (iconRegular: FluentIcons.wallet_24_regular, iconFilled: FluentIcons.wallet_24_filled, label: 'Wallet'),
    (iconRegular: FluentIcons.history_24_regular, iconFilled: FluentIcons.history_24_filled, label: 'History'),
    (iconRegular: FluentIcons.person_24_regular, iconFilled: FluentIcons.person_24_filled, label: 'You'),
  ];

  void _go(int i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: QC.ground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 66,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            decoration: ShapeDecoration(
              gradient: QC.nightGrad,
              shape: QC.squircle(QC.rBig),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: navigationShell.currentIndex == i ? _tabs[i].iconFilled : _tabs[i].iconRegular,
                      label: _tabs[i].label,
                      active: navigationShell.currentIndex == i,
                      onTap: () => _go(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Dark pill nav: active tab lights up with the spotlight gradient; inactive
    // icons/labels sit at low-opacity white so they read against the dark bar.
    final color = active ? Colors.white : Colors.white.withValues(alpha: 0.5);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.12 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              // Kept as BorderRadius.circular (not squircle) - this radius animates on
              // active/inactive toggle, and ShapeDecoration doesn't tween as cleanly via
              // AnimatedContainer as BoxDecoration does. See docs/DESIGN.md §1.
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: active ? QC.primaryGrad : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: active ? QC.btnShadow(QC.primary) : null,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
