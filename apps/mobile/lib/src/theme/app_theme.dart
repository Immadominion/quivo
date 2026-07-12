import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildQuivoTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final text = base.textTheme.apply(
    fontFamily: 'Satoshi',
    bodyColor: QC.ink,
    displayColor: QC.ink,
  );
  return base.copyWith(
    scaffoldBackgroundColor: QC.groundBot,
    colorScheme: base.colorScheme.copyWith(primary: QC.primary, surface: QC.card),
    textTheme: text.copyWith(
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      titleMedium: text.titleMedium?.copyWith(fontFamily: 'Clash Display', fontWeight: FontWeight.w600),
      headlineSmall: text.headlineSmall?.copyWith(fontFamily: 'Clash Display', fontWeight: FontWeight.w700),
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Weighted text helpers used across screens.
/// Clash Display = headlines/titles/big numbers-as-headline. Satoshi = all body/UI copy.
/// JetBrains Mono = numbers ONLY (scores, timers, amounts, addresses) - never body/display for a
/// number that updates or gets compared at a glance.
class QText {
  static TextStyle h1(BuildContext c) =>
      const TextStyle(fontFamily: 'Clash Display', fontSize: 30, fontWeight: FontWeight.w700, color: QC.ink, letterSpacing: -0.6);
  static TextStyle h2(BuildContext c) =>
      const TextStyle(fontFamily: 'Clash Display', fontSize: 22, fontWeight: FontWeight.w700, color: QC.ink, letterSpacing: -0.3);
  static TextStyle title(BuildContext c) =>
      const TextStyle(fontFamily: 'Clash Display', fontSize: 18, fontWeight: FontWeight.w600, color: QC.ink);
  static TextStyle body(BuildContext c) =>
      const TextStyle(fontFamily: 'Satoshi', fontSize: 16, fontWeight: FontWeight.w500, color: QC.body);
  static TextStyle muted(BuildContext c) =>
      const TextStyle(fontFamily: 'Satoshi', fontSize: 14, fontWeight: FontWeight.w500, color: QC.muted);
  static TextStyle overline(BuildContext c, {Color? color}) => TextStyle(
        fontFamily: 'Satoshi',
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color ?? QC.muted,
      );
  static TextStyle mono(BuildContext c, {double size = 13, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color ?? QC.body);
}
