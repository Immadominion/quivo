import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/tokens.dart';

/// Scaffold that paints the Candy Arcade lavender ground behind everything.
class GroundScaffold extends StatelessWidget {
  const GroundScaffold({super.key, required this.child, this.padding, this.bottom});
  final Widget child;
  final EdgeInsets? padding;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: QC.ground),
        child: SafeArea(
          child: Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// White rounded card with the soft floating shadow.
class QCard extends StatelessWidget {
  const QCard({super.key, required this.child, this.padding = const EdgeInsets.all(22), this.color, this.radius});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? QC.card,
        borderRadius: BorderRadius.circular(radius ?? QC.rBig),
        boxShadow: QC.shadowFloat,
      ),
      child: child,
    );
  }
}

/// Pill button with matched-color glow, press-scale, and a min 48px tap target (a11y).
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.gradient,
    this.rgb = QC.primary,
    this.big = false,
    this.enabled = true,
    this.leading,
  });
  final String label;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color rgb;
  final bool big;
  final bool enabled;
  final Widget? leading;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  double _s = 1;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: on ? (_) => setState(() => _s = 0.95) : null,
      onTapUp: on ? (_) => setState(() => _s = 1) : null,
      onTapCancel: on ? () => setState(() => _s = 1) : null,
      onTap: on ? widget.onTap : null,
      child: AnimatedScale(
        scale: _s,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.symmetric(horizontal: widget.big ? 40 : 26, vertical: widget.big ? 18 : 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: on ? (widget.gradient ?? QC.primaryGrad) : null,
            color: on ? null : const Color(0xFFB9BCCB),
            borderRadius: BorderRadius.circular(QC.rBig),
            boxShadow: on ? QC.btnShadow(widget.rgb) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 10)],
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: widget.big ? 20 : 17,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The coin — money motif. Optionally spins.
class Coin extends StatelessWidget {
  const Coin({super.key, this.size = 26, this.spin = false});
  final double size;
  final bool spin;

  @override
  Widget build(BuildContext context) {
    final coin = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: QC.coinGrad,
        boxShadow: const [
          BoxShadow(color: Color(0x4DC86E0A), blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.42,
        height: size * 0.42,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFE0A8), Color(0xFFF0A835)]),
        ),
      ),
    );
    if (!spin) return coin;
    return coin.animate(onPlay: (c) => c.repeat()).rotate(duration: 1400.ms, begin: 0, end: 1);
  }
}

/// Deterministic avatar disc from a wallet/name.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.seed, this.size = 40});
  final String seed;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: playerGradient(seed), boxShadow: QC.shadowCard),
    );
  }
}
