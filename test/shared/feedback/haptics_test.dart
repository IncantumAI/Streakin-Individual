// test/shared/feedback/haptics_test.dart
// The Haptics setting must silence every haptic call, and must persist.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';
import 'package:streakin/shared/feedback/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<MethodCall> hapticCalls() =>
      calls.where((c) => c.method == 'HapticFeedback.vibrate').toList();

  test('disabled haptics never reach the platform channel', () {
    const h = AppHaptics(enabled: false);
    h
      ..tap()
      ..selection()
      ..success()
      ..warning()
      ..error();
    expect(hapticCalls(), isEmpty);
  });

  test('enabled haptics fire on mobile', () {
    const AppHaptics(enabled: true).success();
    expect(hapticCalls(), isNotEmpty);
  });

  test('haptics are skipped on desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const AppHaptics(enabled: true).success();
    expect(hapticCalls(), isEmpty);
  });

  test('hapticsEnabledProvider defaults on and persists changes', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hapticsEnabledProvider), isTrue);
    // Let the initial async load finish (the user can't toggle before that).
    await container.read(sharedPrefsProvider.future);
    await Future<void>.delayed(Duration.zero);
    await container.read(hapticsEnabledProvider.notifier).set(false);
    expect(container.read(hapticsEnabledProvider), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppIdentifiers.prefHapticsEnabled), 'false');
  });

  test('hapticsEnabledProvider loads a stored false', () async {
    SharedPreferences.setMockInitialValues({
      AppIdentifiers.prefHapticsEnabled: 'false',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(hapticsEnabledProvider);
    await container.read(sharedPrefsProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(hapticsEnabledProvider), isFalse);
  });
}
