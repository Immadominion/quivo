import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';

/// Quivo "Floodlight" design tokens - see ../../../docs/DESIGN.md.
/// One primary color (violet), no gradients as brand decisions, squircle corners, and (v3) a
/// solid ink border + flat offset shadow on every card/button - matches the usequivo.fun landing.
class QC {
  QC._();

  // text on light backgrounds
  static const ink = Color(0xFF17122A);
  static const body = Color(0xFF2A2140);
  static const muted = Color(0xFF938DA8);
  static const line = Color(0xFFEBE6F5);

  // bright canvas
  static const groundTop = Color(0xFFFFFFFF);
  static const groundBot = Color(0xFFF6F1FE);
  static const card = Color(0xFFFFFFFF);
  static const cardTint = Color(0xFFF3EEFF);

  // "night" - the dark ink surface for host cards, verdict cards, wallet balance, nav
  static const night = Color(0xFF120F1C);

  // THE one primary color. A second (magenta) exists for sparing, single-color accent use only
  // (e.g. one trait chip) - never paired with primary as a gradient.
  static const primary = Color(0xFF7C3AED);
  static const primaryText = Color(0xFF7C3AED);
  static const primaryDeep = primary;
  static const magenta = Color(0xFFE93D82);

  // secondary accents kept from Quivo's existing coin/status vocabulary - each a single solid.
  static const winPurpleA = primary;
  static const winPurpleB = primary;
  static const winLime = winGreen;
  static const winGreen = Color(0xFF22C55E);

  static const coinA = Color(0xFFF2951F);
  static const coinB = Color(0xFFF2951F);
  static const danger = Color(0xFFF43F5E);
  static const amber = Color(0xFFF59E0B);
  static const amberPale = Color(0xFFFEF3C7);
  static const info = Color(0xFF3B82F6);
  static const infoPale = Color(0xFFDBEAFE);

  // Kept as `Gradient`-typed so existing `gradient:` call sites don't need touching - both stops
  // are now the SAME color, so every one of these paints as a flat, single-color fill.
  static const ground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [groundTop, groundBot],
  );
  static const primaryGrad = LinearGradient(colors: [primary, primary]);
  static const winPurpleGrad = primaryGrad;
  static const nightGrad = LinearGradient(colors: [night, night]);
  static const coinGrad = LinearGradient(colors: [coinB, coinB]);

  // radii - used as the cornerRadius for `squircle()` below.
  static const rCard = 24.0;
  static const rBig = 28.0;
  static const rTile = 18.0;

  // v3: the neobrutalist border + shadow language shared with the usequivo.fun landing page.
  // One weight, one offset - kept deliberately restrained, not the landing's full tilt/halftone
  // treatment (that stays landing-only, see docs/DESIGN.md §1).
  static const borderColor = ink;
  static const borderWidth = 2.0;

  /// Superellipse ("squircle") corners - see docs/DESIGN.md. Use as `ShapeDecoration(shape: ...)`
  /// or directly as a Material `shape:`. `smoothing` 0.6 matches iOS's continuous-corner feel.
  /// Carries the shared `ink` border by default (v3) - pass `bordered: false` to opt out.
  static ShapeBorder squircle(double radius, {double smoothing = 0.6, bool bordered = true}) => SmoothRectangleBorder(
        side: bordered ? const BorderSide(color: borderColor, width: borderWidth) : BorderSide.none,
        borderRadius: SmoothBorderRadius(cornerRadius: radius, cornerSmoothing: smoothing),
      );

  /// Flat, no-blur offset shadow - the neobrutalist signature (v3). Same black regardless of the
  /// surface color, matching the web's `--shadow: Xpx Ypx 0px 0px var(--border)`.
  static List<BoxShadow> shadowCard = const [BoxShadow(color: ink, offset: Offset(4, 4))];
  static List<BoxShadow> shadowFloat = const [BoxShadow(color: ink, offset: Offset(6, 6))];
  static List<BoxShadow> btnShadow(Color rgb) => const [BoxShadow(color: ink, offset: Offset(3, 3))];

  /// No-op - the old glow-blob effect (a radial-gradient "shadow") is retired along with shadows
  /// and gradients. Kept so call sites can stay as-is; it paints nothing.
  static BoxDecoration glowBlob(Color color) => const BoxDecoration();
}

/// The four answer colors - the shared vocabulary with the stage (Kahoot grammar). Each answer is
/// ONE solid color (no gradient) - `.gradient` is kept only so existing `gradient:` call sites
/// compile; it degenerates to the same solid color at both stops.
class QAnswer {
  final String glyph;
  final Color solid;
  final List<Color> grad;
  const QAnswer(this.glyph, this.solid, this.grad);
  LinearGradient get gradient => LinearGradient(colors: [solid, solid]);
}

const kAnswers = <QAnswer>[
  QAnswer('▲', Color(0xFFF43F5E), [Color(0xFFF43F5E), Color(0xFFF43F5E)]),
  QAnswer('◆', Color(0xFF3B82F6), [Color(0xFF3B82F6), Color(0xFF3B82F6)]),
  QAnswer('●', Color(0xFFF59E0B), [Color(0xFFF59E0B), Color(0xFFF59E0B)]),
  QAnswer('■', Color(0xFF22C55E), [Color(0xFF22C55E), Color(0xFF22C55E)]),
];

/// Deterministic identicon color for a wallet or name (avatars, chips) - per-user color variety is
/// a data-visualization technique (distinguishing players), not a brand gradient decision, so this
/// intentionally stays hue-varied rather than collapsing to the single primary color.
Color playerColor(String seed) {
  var h = 0;
  for (var i = 0; i < seed.length; i++) {
    h = (h * 31 + seed.codeUnitAt(i)) % 360;
  }
  return HSLColor.fromAHSL(1, h.toDouble(), 0.82, 0.56).toColor();
}

/// Single solid identicon fill (was a two-tone gradient) - same hue derivation as [playerColor].
Color playerSolid(String seed) => playerColor(seed);

/// Kept for compatibility with existing call sites expecting a Gradient; degenerates to one color.
LinearGradient playerGradient(String seed) {
  final c = playerColor(seed);
  return LinearGradient(colors: [c, c]);
}
