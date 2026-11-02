// lib/core/security/brute_force_guard.dart
// Spec §8.4/§Phase 5C: escalating lockout, persisted across app kills.
//   failures 1–4  → none
//   failure 5     → 30 s,  6 → 60 s,  7 → 120 s … doubling, capped at 1 h
// Optional "wipe after N failures" (off by default).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streakin/core/storage/identifiers.dart';

abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore();
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class FailureOutcome {
  const FailureOutcome({
    required this.failures,
    required this.lockedFor,
    required this.shouldWipe,
  });
  final int failures;
  final Duration lockedFor;
  final bool shouldWipe;
}

class BruteForceGuard {
  BruteForceGuard({
    this._store = const SecureKeyValueStore(),
    Future<int> Function()? wipeThreshold,
    DateTime Function()? clock,
  }) : _wipeThreshold = wipeThreshold ?? _prefsWipeThreshold,
       _now = clock ?? DateTime.now;

  final KeyValueStore _store;
  final Future<int> Function() _wipeThreshold;
  final DateTime Function() _now;

  static Future<int> _prefsWipeThreshold() async =>
      (await SharedPreferences.getInstance()).getInt(
        AppIdentifiers.prefWipeAfterFailures,
      ) ??
      0;

  /// Lockout length after the [failures]-th consecutive failure.
  static Duration lockoutFor(int failures) {
    if (failures < 5) return Duration.zero;
    final seconds = 30 * (1 << (failures - 5).clamp(0, 12));
    return Duration(seconds: seconds.clamp(30, 3600));
  }

  Future<int> failures() async =>
      int.tryParse(
        await _store.read(AppIdentifiers.ssKeyFailedAttempts) ?? '',
      ) ??
      0;

  /// Time left before another attempt is allowed.
  Future<Duration> remaining() async {
    final raw = await _store.read(AppIdentifiers.ssKeyLockoutUntil);
    final until = int.tryParse(raw ?? '');
    if (until == null) return Duration.zero;
    final left = DateTime.fromMillisecondsSinceEpoch(until).difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<FailureOutcome> recordFailure() async {
    final n = (await failures()) + 1;
    await _store.write(AppIdentifiers.ssKeyFailedAttempts, '$n');
    final lock = lockoutFor(n);
    if (lock > Duration.zero) {
      await _store.write(
        AppIdentifiers.ssKeyLockoutUntil,
        '${_now().add(lock).millisecondsSinceEpoch}',
      );
    }
    final wipeAt = await _wipeThreshold();
    return FailureOutcome(
      failures: n,
      lockedFor: lock,
      shouldWipe: wipeAt > 0 && n >= wipeAt,
    );
  }

  Future<void> reset() async {
    await _store.delete(AppIdentifiers.ssKeyFailedAttempts);
    await _store.delete(AppIdentifiers.ssKeyLockoutUntil);
  }
}

final bruteForceGuardProvider = Provider<BruteForceGuard>(
  (_) => BruteForceGuard(),
);
