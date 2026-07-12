import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/atoms.dart';

/// Placeholder home for It0 — proves the Candy Arcade shell renders. Replaced by the real home hub
/// in It5 (join CTA, balance chip, recent results) behind a bottom-nav shell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GroundScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Text('QUIVO', style: QText.h1(context).copyWith(fontSize: 44, letterSpacing: 1)),
          ),
          const SizedBox(height: 6),
          Center(child: Text('play live · win real crypto', style: QText.muted(context))),
          const SizedBox(height: 28),
          QCard(
            child: Column(
              children: [
                Coin(size: 40),
                const SizedBox(height: 12),
                Text('Foundation ready', style: QText.title(context)),
                const SizedBox(height: 8),
                Text(
                  'Candy Arcade theme · Riverpod · go_router',
                  style: QText.muted(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PillButton(label: 'Join a game', big: true, onTap: () {}),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.12, end: 0, curve: Curves.easeOutBack),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
