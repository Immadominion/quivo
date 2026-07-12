import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App preferences (first-run flag, display name, sound/haptics). A reactive Notifier so the
/// Settings screen (It6) can toggle and rebuild; loaded once at splash.
class Prefs {
  const Prefs({this.onboarded = false, this.name = '', this.sound = true, this.haptics = true});
  final bool onboarded;
  final String name;
  final bool sound;
  final bool haptics;

  Prefs copyWith({bool? onboarded, String? name, bool? sound, bool? haptics}) => Prefs(
        onboarded: onboarded ?? this.onboarded,
        name: name ?? this.name,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
      );
}

class PrefsController extends AsyncNotifier<Prefs> {
  SharedPreferences? _p;

  @override
  Future<Prefs> build() async {
    final p = _p = await SharedPreferences.getInstance();
    return Prefs(
      onboarded: p.getBool('onboarded') ?? false,
      name: p.getString('name') ?? '',
      sound: p.getBool('sound') ?? true,
      haptics: p.getBool('haptics') ?? true,
    );
  }

  Future<void> _update(Prefs next, void Function(SharedPreferences) write) async {
    write(_p!);
    state = AsyncData(next);
  }

  Future<void> completeOnboarding(String name) => _update(
        state.value!.copyWith(onboarded: true, name: name),
        (p) {
          p.setBool('onboarded', true);
          p.setString('name', name);
        },
      );

  Future<void> setName(String v) => _update(state.value!.copyWith(name: v), (p) => p.setString('name', v));
  Future<void> setSound(bool v) => _update(state.value!.copyWith(sound: v), (p) => p.setBool('sound', v));
  Future<void> setHaptics(bool v) => _update(state.value!.copyWith(haptics: v), (p) => p.setBool('haptics', v));
}

final prefsProvider = AsyncNotifierProvider<PrefsController, Prefs>(PrefsController.new);
