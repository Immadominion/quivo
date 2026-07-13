import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/names.dart';
import '../widgets/atoms.dart';

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
  final _pc = PageController();
  final _name = TextEditingController();
  _Step _step = _Step.connect;
  int _page = 0;
  bool _saving = false;
  bool _userEdited = false;

  static const _slides = [
    _Slide('🎮', 'Play live', 'Join a game show happening in the room. Answer on your phone, race the clock.'),
    _Slide('🪙', 'Win real crypto', 'Top the leaderboard and get paid on-chain, straight to your wallet.'),
    _Slide('⚡', 'Fast and fair', 'Every round settles on Solana. Provably fair, instantly paid.'),
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
    return GroundScaffold(
      child: switch (_step) {
        _Step.connect => _ConnectStep(onDone: _toSlides),
        _Step.slides => _slidesView(),
        _Step.name => _nameView(),
      },
    );
  }

  Widget _slidesView() {
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

class _Slide {
  final String emoji, title, subtitle;
  const _Slide(this.emoji, this.title, this.subtitle);
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
        ],
      ),
    );
  }
}

/// Step 1: connect a real wallet (MWA / Seed Vault). Guest fallback keeps iOS + no-wallet users
/// moving, but connect is the hero path.
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

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(color: QC.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(FluentIcons.wallet_24_filled, color: Colors.white, size: 52),
              ).animate().scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack, duration: 450.ms),
              const SizedBox(height: 26),
              Text('Bring your wallet', style: QText.h1(context), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Connect your Solana wallet so prizes land with you, and your account is still yours if you reinstall.',
                  textAlign: TextAlign.center,
                  style: QText.body(context).copyWith(color: QC.body),
                ),
              ),
              const SizedBox(height: 30),
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
              TextButton(
                onPressed: connecting ? null : onDone,
                child: Text('Continue as guest', style: QText.muted(context)),
              ),
              if (connect.status == ConnectStatus.error && connect.error != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(connect.error!, textAlign: TextAlign.center, style: QText.muted(context).copyWith(color: QC.danger)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
