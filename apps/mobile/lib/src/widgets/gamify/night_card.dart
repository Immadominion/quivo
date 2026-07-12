import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// The dark "ink" surface - host commentary, verdict cards, wallet balance. Every night card gets
/// exactly one radial glow blob in a corner (see docs/DESIGN.md §1, §5) - never zero, never more.
class NightCard extends StatelessWidget {
  const NightCard({
    super.key,
    required this.child,
    this.glow = QC.primary,
    this.glowAlignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(20),
    this.radius,
    this.gradient,
  });

  final Widget child;
  final Color glow;
  final Alignment glowAlignment;
  final EdgeInsets padding;
  final double? radius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? QC.rBig;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(gradient: gradient ?? QC.nightGrad, shape: QC.squircle(r)),
      child: Stack(
        children: [
          // Purely decorative - excluded from semantics so it can never desync the a11y tree
          // during the card's entrance animation (a real Stack+Align+animation crash otherwise).
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Align(
                  alignment: glowAlignment,
                  child: FractionallySizedBox(
                    widthFactor: 0.65,
                    heightFactor: 0.65,
                    child: DecoratedBox(decoration: QC.glowBlob(glow)),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
