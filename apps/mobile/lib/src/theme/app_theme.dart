import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildQuivoTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final text = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
    bodyColor: QC.ink,
    displayColor: QC.ink,
  );
  return base.copyWith(
    scaffoldBackgroundColor: QC.groundBot,
    colorScheme: base.colorScheme.copyWith(primary: QC.primary, surface: QC.card),
    textTheme: text.copyWith(
      // heavy by default — the Candy Arcade rule
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Weighted text helpers (Nunito 700/800/900) used across screens.
class QText {
  static TextStyle h1(BuildContext c) =>
      GoogleFonts.nunito(fontSize: 30, fontWeight: FontWeight.w900, color: QC.ink, letterSpacing: -0.5);
  static TextStyle h2(BuildContext c) =>
      GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: QC.ink);
  static TextStyle title(BuildContext c) =>
      GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: QC.ink);
  static TextStyle body(BuildContext c) =>
      GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: QC.body);
  static TextStyle muted(BuildContext c) =>
      GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: QC.muted);
  static TextStyle mono(BuildContext c, {double size = 13, Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? QC.body,
      );
}
