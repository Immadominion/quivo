import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:rive/rive.dart' show Fit;
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/names.dart';
import '../widgets/atoms.dart';
import '../widgets/rive_illustration.dart';

/// First-run flow, in the order the user asked for: connect a wallet first, then three value
/// slides (last = get started), then a name step that comes PRE-FILLED from the wallet's own label
/// (Seed Vault / .skr on Seeker) or an Apple-Arcade-style suggestion, editable only if you want.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { connect, slides, name }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Debug-only: jump straight to the value slides at a chosen page to preview animations
  // (--dart-define=QUIVO_ONBOARD_SLIDES=true --dart-define=QUIVO_SLIDE=1). No-op in release.
  static const _dbgSlides = kDebugMode && bool.fromEnvironment('QUIVO_ONBOARD_SLIDES');
  static const _dbgSlide = int.fromEnvironment('QUIVO_SLIDE');

  final _pc = PageController(initialPage: _dbgSlide);
  final _name = TextEditingController();
  _Step _step = _dbgSlides ? _Step.slides : _Step.connect;
  int _page = _dbgSlide;
  bool _saving = false;
  bool _userEdited = false;

  static const _slides = [
    _Slide('Play live', 'Join a game show happening in the room. Answer on your phone, race the clock.',
        riv: 'assets/animations/play.riv'),
    _Slide('Win real crypto', 'Top the leaderboard and get paid on-chain, straight to your wallet.', coinRain: true),
    _Slide('Fast and fair', 'Every round settles on Solana. Provably fair, instantly paid.',
        riv: 'assets/animations/fast.riv'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    _name.dispose();
    super.dispose();
  }

  void _toSlides() => setState(() => _step = _Step.slides);

  void _toName() => setState(() => _step = _Step.name);

  Future<void> _start() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await ref.read(prefsProvider.notifier).completeOnboarding(_name.text.trim());
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Prefill the name reactively: a random suggestion first, then replaced by the real on-chain
    // name (.skr / .sol) once it resolves after connect, unless the user has already typed. This is
    // why a real name wins over the random one, and warming it here means it's ready by the name step.
    ref.listen<AsyncValue<String>>(suggestedNameProvider, (_, next) {
      next.whenData((name) {
        if (_userEdited || !mounted || name.isEmpty) return;
        _name.text = name;
        _name.selection = TextSelection.collapsed(offset: name.length);
      });
    });
    // The slides + connect steps are full-bleed (not GroundScaffold): slides for the coin rain,
    // connect for the bg-txt background image. The name step keeps the padded GroundScaffold.
    if (_step == _Step.slides) return _slidesScaffold();
    if (_step == _Step.connect) return _ConnectStep(onDone: _toSlides);
    return GroundScaffold(child: _nameView());
  }

  Widget _slidesScaffold() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: QC.ground),
        child: Stack(
          children: [
            // Raining coins: full screen (fills height, covers width), only on the "Win real crypto"
            // slide, behind everything including the button. Decorative, never blocks taps/swipes.
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedOpacity(
                    opacity: _page == 1 ? 1 : 0,
                    duration: 350.ms,
                    child: Lottie.asset(
                      'assets/animations/win.lottie',
                      decoder: _dotLottieDecoder,
                      fit: BoxFit.cover,
                      repeat: true,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: _slidesColumn(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slidesColumn() {
    final last = _page == _slides.length - 1;
    return Column(
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
            itemBuilder: (c, i) => _SlideView(slide: _slides[i]),
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
              decoration: BoxDecoration(color: on ? QC.primary : QC.line, borderRadius: BorderRadius.circular(4)),
            );
          }),
        ),
        const SizedBox(height: 22),
        PillButton(
          label: last ? 'Get started' : 'Next',
          big: true,
          onTap: last ? _toName : () => _pc.nextPage(duration: 320.ms, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }

  Widget _nameView() {
    final wallet = ref.watch(walletProvider).value;
    final resolving = ref.watch(suggestedNameProvider).isLoading;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (wallet != null) PlayerAvatar(seed: wallet.address, size: 84, initial: _name.text.isNotEmpty ? _name.text : 'Q'),
              const SizedBox(height: 22),
              Text('What should we call you?', style: QText.h1(context), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                resolving
                    ? 'Finding your wallet name...'
                    : (wallet?.isConnected == true
                        ? 'Straight from your wallet. Change it if you like.'
                        : 'Here is a name to start with. Change it if you like.'),
                textAlign: TextAlign.center,
                style: QText.muted(context),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                maxLength: 20,
                onChanged: (_) => setState(() => _userEdited = true),
                style: QText.title(context),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  suffixIcon: IconButton(
                    tooltip: 'Shuffle',
                    icon: const Icon(FluentIcons.arrow_shuffle_24_regular, color: QC.muted, size: 20),
                    onPressed: () => setState(() => _name.text = randomName()),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: QC.line, width: 2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: QC.line, width: 2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: QC.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 10),
              if (wallet != null)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(wallet.isConnected ? FluentIcons.wallet_24_filled : FluentIcons.person_24_regular, size: 16, color: QC.muted),
                  const SizedBox(width: 6),
                  Text(
                    wallet.isConnected ? 'Wallet ${wallet.short}' : 'Guest ${wallet.short}',
                    style: QText.mono(context, size: 12, color: QC.muted),
                  ),
                ]),
              const SizedBox(height: 28),
              PillButton(
                label: _saving ? 'Setting up...' : 'Start playing',
                big: true,
                enabled: !_saving && _name.text.trim().isNotEmpty,
                onTap: _start,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// A .lottie (dotLottie) file is a zip; pick the animation JSON out of it for the lottie package.
Future<LottieComposition?> _dotLottieDecoder(List<int> bytes) {
  return LottieComposition.decodeZip(bytes, filePicker: (files) {
    for (final f in files) {
      if (f.name.startsWith('animations/') && f.name.endsWith('.json')) return f;
    }
    return files.isNotEmpty ? files.first : null;
  });
}

class _Slide {
  final String title, subtitle;

  /// A .riv illustration shown directly (no circle/container). Null on the coin-rain slide, whose
  /// visual is the full-screen win.lottie behind the whole page.
  final String? riv;
  final bool coinRain;
  const _Slide(this.title, this.subtitle, {this.riv, this.coinRain = false});
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (slide.riv != null) ...[
            // The rive plays directly, no circle or background behind it.
            SizedBox(height: 260, child: RiveIllustration(slide.riv!, fit: Fit.contain)),
            const SizedBox(height: 20),
          ],
          Text(slide.title, style: QText.h1(context)),
          const SizedBox(height: 10),
          Text(slide.subtitle, textAlign: TextAlign.center, style: QText.body(context).copyWith(color: QC.body)),
        ],
      ),
    );
  }
}

/// Step 1: connect a real wallet (MWA / Seed Vault). Guest fallback keeps iOS + no-wallet users
/// moving, but connect is the hero path. Full-bleed bg-txt art, headline top-left in white, the two
/// actions pinned to the bottom like the slides.
class _ConnectStep extends ConsumerWidget {
  const _ConnectStep({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connect = ref.watch(walletConnectProvider);
    final ctrl = ref.read(walletConnectProvider.notifier);
    final connecting = connect.status == ConnectStatus.connecting;

    Future<void> doConnect() async {
      HapticFeedback.selectionClick();
      final conn = await ctrl.connect();
      if (conn != null && context.mounted) onDone();
    }

    // Dark art background, so white status-bar icons + white text.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QC.night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/branding/bg-txt.png', fit: BoxFit.cover),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Empty top ~3/4, so the headline sits low on the art, not up top.
                    const Spacer(flex: 3),
                    Text(
                      'Bring your\nwallet',
                      style: QText.h1(context).copyWith(color: Colors.white, fontSize: 44, height: 1.02),
                    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.06, end: 0),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 300,
                      child: Text(
                        'Connect your Solana wallet so prizes land with you, and your account is still yours if you reinstall.',
                        style: QText.body(context).copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.4),
                      ),
                    ),
                    const Spacer(flex: 1),
                    PillButton(
                      label: connecting ? 'Opening wallet...' : 'Connect wallet',
                      big: true,
                      enabled: !connecting,
                      leading: connecting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(FluentIcons.wallet_24_filled, color: Colors.white, size: 20),
                      onTap: doConnect,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: connecting ? null : onDone,
                        child: Text(
                          'Continue as guest',
                          style: QText.body(context).copyWith(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (connect.status == ConnectStatus.error && connect.error != null) ...[
                      const SizedBox(height: 6),
                      Text(connect.error!, textAlign: TextAlign.center, style: QText.muted(context).copyWith(color: Colors.white)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
