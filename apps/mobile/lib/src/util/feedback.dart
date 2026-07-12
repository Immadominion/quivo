import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/prefs.dart';

/// Haptics, gated on the user's preference. HapticFeedback is built into the engine (no plugin),
/// so it behaves identically on both platforms and can't break a build.
enum Buzz { tap, select, correct, wrong, win }

void buzz(WidgetRef ref, Buzz kind) {
  final on = ref.read(prefsProvider).value?.haptics ?? true;
  if (!on) return;
  switch (kind) {
    case Buzz.tap:
      HapticFeedback.selectionClick();
    case Buzz.select:
      HapticFeedback.lightImpact();
    case Buzz.correct:
      HapticFeedback.mediumImpact();
    case Buzz.wrong:
      HapticFeedback.heavyImpact();
    case Buzz.win:
      HapticFeedback.heavyImpact();
  }
}
