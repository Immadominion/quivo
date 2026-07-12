import 'package:flutter/material.dart';

/// Quivo "Candy Arcade" design tokens — Dart port of the web theme (../../docs/DESIGN.md).
class QC {
  QC._();

  static const ink = Color(0xFF161D33);
  static const body = Color(0xFF1B2237);
  static const muted = Color(0xFF8B94AC);
  static const line = Color(0xFFD3E1FB);

  static const groundTop = Color(0xFFACA5C6);
  static const groundBot = Color(0xFF9C94B8);
  static const card = Color(0xFFFFFFFF);
  static const cardTint = Color(0xFFE6EFFD);

  static const primary = Color(0xFF2F7DF6);
  static const primaryText = Color(0xFF2B6BE4);
  static const primaryDeep = Color(0xFF2456D6);

  static const winPurpleA = Color(0xFFC25FF2);
  static const winPurpleB = Color(0xFF9430DB);
  static const winLime = Color(0xFF82B11D);
  static const winGreen = Color(0xFF2F9E44);

  static const coinA = Color(0xFFFFCF7A);
  static const coinB = Color(0xFFF2951F);
  static const danger = Color(0xFFE5484D);

  static const ground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [groundTop, groundBot],
  );
  static const primaryGrad = LinearGradient(colors: [primaryDeep, primary]);
  static const winPurpleGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [winPurpleA, winPurpleB],
  );
  static const coinGrad = RadialGradient(center: Alignment(-0.3, -0.4), colors: [coinA, coinB]);

  // radii
  static const rCard = 26.0;
  static const rBig = 30.0;
  static const rTile = 20.0;

  static List<BoxShadow> shadowCard = const [
    BoxShadow(color: Color(0x1A302355), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static List<BoxShadow> shadowFloat = const [
    BoxShadow(color: Color(0x1F343060), blurRadius: 34, offset: Offset(0, 16)),
  ];
  static List<BoxShadow> btnShadow(Color rgb) => [
        BoxShadow(color: rgb.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
      ];
}

/// The four answer colors — the shared vocabulary with the stage (Kahoot grammar).
class QAnswer {
  final String glyph;
  final Color solid;
  final List<Color> grad;
  const QAnswer(this.glyph, this.solid, this.grad);
  LinearGradient get gradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad);
}

const kAnswers = <QAnswer>[
  QAnswer('▲', Color(0xFFE5484D), [Color(0xFFF2588F), Color(0xFFD92D3F)]),
  QAnswer('◆', Color(0xFF2F7DF6), [Color(0xFF4AA8F0), Color(0xFF1F4FD6)]),
  QAnswer('●', Color(0xFFEDA13D), [Color(0xFFF8B64C), Color(0xFFE8681E)]),
  QAnswer('■', Color(0xFF3FA14E), [Color(0xFF8DE06A), Color(0xFF2F9E44)]),
];

/// Deterministic candy gradient/color for a wallet or name (avatars, chips).
Color playerColor(String seed) {
  var h = 0;
  for (var i = 0; i < seed.length; i++) {
    h = (h * 31 + seed.codeUnitAt(i)) % 360;
  }
  return HSLColor.fromAHSL(1, h.toDouble(), 0.82, 0.56).toColor();
}

LinearGradient playerGradient(String seed) {
  var h = 0;
  for (var i = 0; i < seed.length; i++) {
    h = (h * 31 + seed.codeUnitAt(i)) % 360;
  }
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HSLColor.fromAHSL(1, h.toDouble(), 0.85, 0.62).toColor(),
      HSLColor.fromAHSL(1, (h + 40) % 360, 0.75, 0.45).toColor(),
    ],
  );
}
