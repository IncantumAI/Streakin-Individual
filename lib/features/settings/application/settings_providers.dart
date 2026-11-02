// lib/features/settings/application/settings_providers.dart
// Riverpod 3 — uses Notifier instead of StateNotifier.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streakin/core/storage/identifiers.dart';

// ── SharedPreferences singleton ───────────────────────────────────────────────

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

// ── Theme mode ────────────────────────────────────────────────────────────────

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final stored = prefs.getString(AppIdentifiers.prefThemeMode) ?? 'system';
    state = _fromString(stored);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(AppIdentifiers.prefThemeMode, _toString(mode));
  }

  static ThemeMode _fromString(String s) => switch (s) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _toString(ThemeMode m) => switch (m) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    _ => 'system',
  };
}

// ── Week start ────────────────────────────────────────────────────────────────

final weekStartProvider = NotifierProvider<WeekStartNotifier, int>(
  WeekStartNotifier.new,
);

class WeekStartNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 1; // Monday default
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getInt(AppIdentifiers.prefWeekStart) ?? 1;
  }

  Future<void> set(int weekday) async {
    state = weekday;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt(AppIdentifiers.prefWeekStart, weekday);
  }
}

// ── Day boundary ──────────────────────────────────────────────────────────────

final dayBoundaryMinutesProvider = NotifierProvider<DayBoundaryNotifier, int>(
  DayBoundaryNotifier.new,
);

class DayBoundaryNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getInt(AppIdentifiers.prefDayBoundaryMinutes) ?? 0;
  }

  Future<void> set(int minutes) async {
    state = minutes;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt(AppIdentifiers.prefDayBoundaryMinutes, minutes);
  }
}

// ── Motion ────────────────────────────────────────────────────────────────────

final reducedMotionProvider = NotifierProvider<ReducedMotionNotifier, bool>(
  ReducedMotionNotifier.new,
);

class ReducedMotionNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final v = prefs.getString(AppIdentifiers.prefMotionMode) ?? 'full';
    state = v == 'reduced';
  }

  Future<void> set(bool reduced) async {
    state = reduced;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(
      AppIdentifiers.prefMotionMode,
      reduced ? 'reduced' : 'full',
    );
  }
}

// ── Haptics ───────────────────────────────────────────────────────────────────

final hapticsEnabledProvider = NotifierProvider<HapticsEnabledNotifier, bool>(
  HapticsEnabledNotifier.new,
);

class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final v = prefs.getString(AppIdentifiers.prefHapticsEnabled) ?? 'true';
    state = v == 'true';
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(
      AppIdentifiers.prefHapticsEnabled,
      enabled ? 'true' : 'false',
    );
  }
}

// ── Onboarding done ───────────────────────────────────────────────────────────

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getBool(AppIdentifiers.prefOnboardingDone) ?? false;
});

// ── Biometric unlock enabled ──────────────────────────────────────────────────

final biometricEnabledProvider =
    NotifierProvider<BiometricEnabledNotifier, bool>(
      BiometricEnabledNotifier.new,
    );

class BiometricEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getBool(AppIdentifiers.prefBiometricEnabled) ?? false;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(AppIdentifiers.prefBiometricEnabled, enabled);
  }
}

// ── Profile ───────────────────────────────────────────────────────────────────

class ProfileNotifier
    extends Notifier<({String name, String username, String bio})> {
  @override
  ({String name, String username, String bio}) build() {
    _load();
    return (name: '', username: '', bio: '');
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = (
      name: prefs.getString(AppIdentifiers.prefProfileName) ?? '',
      username: prefs.getString(AppIdentifiers.prefProfileUsername) ?? '',
      bio: prefs.getString(AppIdentifiers.prefProfileBio) ?? '',
    );
  }

  Future<void> save({
    required String name,
    required String username,
    required String bio,
  }) async {
    state = (name: name, username: username, bio: bio);
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(AppIdentifiers.prefProfileName, name);
    await prefs.setString(AppIdentifiers.prefProfileUsername, username);
    await prefs.setString(AppIdentifiers.prefProfileBio, bio);
  }
}

final profileProvider =
    NotifierProvider<
      ProfileNotifier,
      ({String name, String username, String bio})
    >(ProfileNotifier.new);

// ── Generic boolean / int preferences ────────────────────────────────────────

class BoolPrefNotifier extends Notifier<bool> {
  BoolPrefNotifier(this.key, this.defaultValue);
  final String key;
  final bool defaultValue;

  @override
  bool build() {
    _load();
    return defaultValue;
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getBool(key) ?? defaultValue;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(key, value);
  }
}

NotifierProvider<BoolPrefNotifier, bool> _boolPref(
  String key, {
  bool defaultValue = false,
}) => NotifierProvider<BoolPrefNotifier, bool>(
  () => BoolPrefNotifier(key, defaultValue),
);

/// Whether flagged to-dos must be done before the day locks in.
final countTodosForLockInProvider = _boolPref(
  AppIdentifiers.prefCountTodosForLockIn,
);

/// Per-type notification toggles (spec §12.1).
final notifHabitsEnabledProvider = _boolPref(
  AppIdentifiers.prefNotifHabits,
  defaultValue: true,
);
final notifTodosEnabledProvider = _boolPref(
  AppIdentifiers.prefNotifTodos,
  defaultValue: true,
);
final notifMentionsEnabledProvider = _boolPref(
  AppIdentifiers.prefNotifMentions,
  defaultValue: true,
);
final notifLockInNudgeEnabledProvider = _boolPref(
  AppIdentifiers.prefNotifLockInNudge,
  defaultValue: true,
);

/// 24-hour clock display.
final timeFormat24hProvider = _boolPref(AppIdentifiers.prefTimeFormat24h);

/// Default reminder time (minutes from midnight) for all-day items.
final defaultReminderMinutesProvider =
    NotifierProvider<DefaultReminderNotifier, int>(DefaultReminderNotifier.new);

class DefaultReminderNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 540; // 09:00
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getInt(AppIdentifiers.prefDefaultReminderMinutes) ?? 540;
  }

  Future<void> set(int minutes) async {
    state = minutes;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt(AppIdentifiers.prefDefaultReminderMinutes, minutes);
  }
}
