import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';

/// First-run onboarding: three value slides, then a name pick. Sign-in-LESS - the wallet is already
/// minted (walletProvider), so there is nothing to create; we just say hi and ask a name.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pc = PageController();
  final _name = TextEditingController();
  int _page = 0;
  bool _saving = false;

  static const _slides = [
    _Slide('🎮', 'Play live', 'Join a game show happening in the room. Answer on your phone, race the clock.', QC.primary),
    _Slide('🪙', 'Win real crypto', 'Top the leaderboard and get paid on-chain - instantly, provably fair.', QC.winGreen),
    _Slide('⚡', 'No signup', 'A wallet is already made for you on this phone. Just pick a name and play.', QC.winPurpleB),
  ];

  @override
  void dispose() {
    _pc.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await ref.read(prefsProvider.notifier).completeOnboarding(_name.text.trim());
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return GroundScaffold(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: last
                ? const SizedBox(height: 40)
                : TextButton(
                    onPressed: () => _pc.animateToPage(_slides.length - 1, duration: 300.ms, curve: Curves.easeOut),
                    child: Text('Skip', style: QText.muted(context)),
                  ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _slides.length,
              itemBuilder: (c, i) => _SlideView(slide: _slides[i], isNameStep: i == _slides.length - 1, nameController: _name),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final on = i == _page;
              return AnimatedContainer(
                duration: 250.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(color: on ? QC.primary : QC.muted, borderRadius: BorderRadius.circular(4)),
              );
            }),
          ),
          const SizedBox(height: 22),
          last
              ? PillButton(label: _saving ? 'Setting up…' : 'Start playing', big: true, enabled: !_saving, onTap: _start)
              : PillButton(
                  label: 'Next',
                  big: true,
                  onTap: () => _pc.nextPage(duration: 320.ms, curve: Curves.easeOutCubic),
                ),
        ],
      ),
    );
  }
}

class _Slide {
  final String emoji, title, subtitle;
  final Color accent;
  const _Slide(this.emoji, this.title, this.subtitle, this.accent);
}

class _SlideView extends ConsumerWidget {
  const _SlideView({required this.slide, required this.isNameStep, required this.nameController});
  final _Slide slide;
  final bool isNameStep;
  final TextEditingController nameController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // A plain centered Column can't shrink when the keyboard opens for the name field, which
      // overflowed. LayoutBuilder + a min-height ConstrainedBox keeps the centered look when
      // everything fits, and scrolls instead of overflowing when the keyboard eats the space.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(slide.emoji, style: const TextStyle(fontSize: 64)),
                ).animate(key: ValueKey(slide.title)).scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack, duration: 450.ms),
                const SizedBox(height: 28),
                Text(slide.title, style: QText.h1(context)),
                const SizedBox(height: 10),
                Text(slide.subtitle, textAlign: TextAlign.center, style: QText.body(context).copyWith(color: QC.body)),
                if (isNameStep) ...[
                  const SizedBox(height: 26),
                  TextField(
                    controller: nameController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.words,
                    style: QText.title(context),
                    decoration: InputDecoration(
                      hintText: 'your name',
                      hintStyle: QText.muted(context),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: QC.line, width: 2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: QC.line, width: 2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: QC.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  wallet.when(
                    data: (w) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      PlayerAvatar(seed: w.address, size: 22),
                      const SizedBox(width: 8),
                      Text('your wallet ${w.short}', style: QText.mono(context, size: 12, color: QC.muted)),
                    ]),
                    loading: () => Text('making your wallet...', style: QText.muted(context)),
                    error: (e, _) => Text('wallet error', style: QText.muted(context)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
