import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/game_controller.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';

/// Join a game: scan the QR on the host's big screen (hero - it's what the nav's center button
/// promises, and this room-to-phone topology is exactly what QR is for), or type the room code in
/// the always-visible field below (the Kahoot path; also the only path when a code arrives by chat
/// or the camera is unavailable). A valid scan auto-joins with no confirm step - joining a lobby
/// is low-stakes, unlike QR auth flows that need approval.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});
  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _ctrl = TextEditingController();
  final _scanner = MobileScannerController();
  bool _busy = false;
  bool _scanHandled = false;
  String? _scanNote;
  Timer? _noteTimer;

  @override
  void dispose() {
    _noteTimer?.cancel();
    _ctrl.dispose();
    _scanner.dispose();
    super.dispose();
  }

  // Real room ids are mixed-case tokens (e.g. 1VMJ0hqm5) - never uppercase or over-trim them.
  bool get _valid => _ctrl.text.trim().length >= 4;

  /// Pull a room code out of whatever the QR carried: the stage encodes a join URL with ?c=CODE;
  /// a bare code is accepted too.
  static String? _codeFromQr(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    final fromUrl = uri?.queryParameters['c'];
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;
    if (RegExp(r'^[A-Za-z0-9_-]{4,16}$').hasMatch(text)) return text;
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanHandled || _busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final code = _codeFromQr(raw);
      if (code != null) {
        _scanHandled = true;
        HapticFeedback.mediumImpact();
        _scanner.stop();
        _join(code);
        return;
      }
    }
    // Something scanned, but not a Quivo code: say so briefly, keep scanning.
    if (capture.barcodes.isNotEmpty && _scanNote == null) {
      setState(() => _scanNote = 'Not a Quivo game code. Keep aiming at the big screen.');
      _noteTimer?.cancel();
      _noteTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _scanNote = null);
      });
    }
  }

  Future<void> _join(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final wallet = await ref.read(walletProvider.future);
      final prefs = ref.read(prefsProvider).value;
      final name = (prefs?.name.isNotEmpty ?? false) ? prefs!.name : 'player';
      await ref.read(gameControllerProvider.notifier).join(code.trim(), name: name, wallet: wallet.address);
      if (mounted) context.push('/play');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _scanHandled = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GroundScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: QC.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: QC.borderColor, width: QC.borderWidth),
                          boxShadow: QC.shadowCard,
                        ),
                        child: const Icon(FluentIcons.arrow_left_24_regular, size: 20, color: QC.ink),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Join a game', style: QText.h1(context)),
                  ],
                ),
                const SizedBox(height: 18),

                // ----- Scanner hero: aim at the host screen, auto-joins on a valid code. -----
                Container(
                  height: 300,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: QC.night,
                    shape: QC.squircle(QC.rCard),
                    shadows: QC.shadowFloat,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scanner,
                        onDetect: _onDetect,
                        fit: BoxFit.cover,
                        placeholderBuilder: (context) => const ColoredBox(color: QC.night),
                        // Camera denied / unavailable (simulators too): degrade to code-first.
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.camera_off_24_regular,
                                    size: 34, color: Colors.white.withValues(alpha: 0.7)),
                                const SizedBox(height: 10),
                                Text(
                                  'Camera unavailable.\nType the game code below instead.',
                                  textAlign: TextAlign.center,
                                  style: QText.body(context)
                                      .copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Corner brackets so the viewport reads as "aim here".
                      const IgnorePointer(
                        child: ExcludeSemantics(
                          child: CustomPaint(painter: _CornerBrackets()),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: 200.ms,
                            child: Container(
                              key: ValueKey(_scanNote ?? 'hint'),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: ShapeDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: QC.squircle(12, bordered: false),
                              ),
                              child: Text(
                                _scanNote ?? 'Point at the QR on the big screen',
                                style: const TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 20),

                // ----- Persistent manual path: never hidden behind a link. -----
                Row(
                  children: [
                    const Expanded(child: Divider(color: QC.line, thickness: 2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or enter the code', style: QText.muted(context)),
                    ),
                    const Expanded(child: Divider(color: QC.line, thickness: 2)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                  decoration: ShapeDecoration(
                    color: QC.card,
                    shape: QC.squircle(QC.rCard),
                    shadows: QC.shadowCard,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _ctrl,
                        textAlign: TextAlign.center,
                        maxLength: 12,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _valid && !_busy ? _join(_ctrl.text) : null,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
                        style: QText.mono(context, size: 26, color: QC.ink).copyWith(letterSpacing: 4),
                        cursorColor: QC.primary,
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: 'CODE',
                          hintStyle: QText.mono(context, size: 26, color: QC.line).copyWith(letterSpacing: 4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      PillButton(
                        label: _busy ? 'Joining...' : 'Join',
                        big: true,
                        enabled: _valid && !_busy,
                        onTap: () => _join(_ctrl.text),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
                const SizedBox(height: 16),
                Center(child: Text('No account needed - you are already in.', style: QText.muted(context))),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Four white corner brackets over the camera viewport - the universal "aim here" framing.
class _CornerBrackets extends CustomPainter {
  const _CornerBrackets();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const inset = 18.0;
    const arm = 26.0;
    final w = size.width, h = size.height;

    void corner(Offset origin, Offset dx, Offset dy) {
      canvas.drawLine(origin, origin + dx, paint);
      canvas.drawLine(origin, origin + dy, paint);
    }

    corner(const Offset(inset, inset), const Offset(arm, 0), const Offset(0, arm));
    corner(Offset(w - inset, inset), const Offset(-arm, 0), const Offset(0, arm));
    corner(Offset(inset, h - inset), const Offset(arm, 0), const Offset(0, -arm));
    corner(Offset(w - inset, h - inset), const Offset(-arm, 0), const Offset(0, -arm));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
