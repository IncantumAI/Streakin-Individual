// Track 5C: escalating lockout, persistence, wipe threshold.

import 'package:flutter_test/flutter_test.dart';

import 'package:streakin/core/security/brute_force_guard.dart';

class _Mem implements KeyValueStore {
  final Map<String, String> m = {};
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
  @override
  Future<void> delete(String key) async => m.remove(key);
}

void main() {
  late _Mem store;
  late DateTime now;
  int wipeAt = 0;

  BruteForceGuard guard() => BruteForceGuard(
    store: store,
    wipeThreshold: () async => wipeAt,
    clock: () => now,
  );

  setUp(() {
    store = _Mem();
    now = DateTime(2026, 10, 7, 12);
    wipeAt = 0;
  });

  test('tiers: 5→30s, 6→60s, 7→120s, doubling, capped at 1h', () {
    expect(BruteForceGuard.lockoutFor(4), Duration.zero);
    expect(BruteForceGuard.lockoutFor(5), const Duration(seconds: 30));
    expect(BruteForceGuard.lockoutFor(6), const Duration(seconds: 60));
    expect(BruteForceGuard.lockoutFor(7), const Duration(seconds: 120));
    expect(BruteForceGuard.lockoutFor(8), const Duration(seconds: 240));
    expect(BruteForceGuard.lockoutFor(30), const Duration(hours: 1));
  });

  test('no lockout for the first four failures; 5th locks for 30 s', () async {
    final g = guard();
    for (var i = 0; i < 4; i++) {
      expect((await g.recordFailure()).lockedFor, Duration.zero);
    }
    final fifth = await g.recordFailure();
    expect(fifth.lockedFor, const Duration(seconds: 30));
    expect(await g.remaining(), const Duration(seconds: 30));
    now = now.add(const Duration(seconds: 31));
    expect(await g.remaining(), Duration.zero);
  });

  test(
    'counter and lockout persist across a new guard instance (app kill)',
    () async {
      final g1 = guard();
      for (var i = 0; i < 6; i++) {
        await g1.recordFailure();
      }
      final g2 = guard(); // "restart"
      expect(await g2.failures(), 6);
      expect(await g2.remaining(), const Duration(seconds: 60));
    },
  );

  test('success resets the counter', () async {
    final g = guard();
    for (var i = 0; i < 5; i++) {
      await g.recordFailure();
    }
    await g.reset();
    expect(await g.failures(), 0);
    expect(await g.remaining(), Duration.zero);
  });

  test('wipe-after-N fires on the Nth failure only when enabled', () async {
    var g = guard();
    for (var i = 0; i < 9; i++) {
      expect((await g.recordFailure()).shouldWipe, isFalse); // disabled
    }
    store.m.clear();
    wipeAt = 5;
    g = guard();
    for (var i = 0; i < 4; i++) {
      expect((await g.recordFailure()).shouldWipe, isFalse);
    }
    expect((await g.recordFailure()).shouldWipe, isTrue);
  });
}
