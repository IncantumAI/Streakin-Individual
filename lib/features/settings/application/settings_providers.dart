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

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

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

final weekStartProvider =
    NotifierProvider<WeekStartNotifier, int>(WeekStartNotifier.new);

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

final dayBoundaryMinutesProvider =
    NotifierProvider<DayBoundaryNotifier, int>(DayBoundaryNotifier.new);

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

final reducedMotionProvider =
    NotifierProvider<ReducedMotionNotifier, bool>(ReducedMotionNotifier.new);

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
        AppIdentifiers.prefMotionMode, reduced ? 'reduced' : 'full');
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
        BiometricEnabledNotifier.new);

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

class ProfileNotifier extends Notifier<({String name, String username, String bio})> {
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
    NotifierProvider<ProfileNotifier, ({String name, String username, String bio})>(
        ProfileNotifier.new);
