// lib/core/platform/windows_capture_guard.dart
// Spec §8.5/§8.7 screen-capture protection, one API for all platforms:
//   • Windows → SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)
//   • Android → FLAG_SECURE (recents thumbnail + screenshots blank)
//   • Linux   → not possible; the settings UI documents the limitation.
// Also surfaces desktop workstation-lock / sleep so the app can lock.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streakin/core/storage/identifiers.dart';

class CaptureGuard {
  CaptureGuard._();

  static const _desktop = MethodChannel('streakin/desktop_security');
  static const _android = MethodChannel('streakin.native');

  /// True where capture exclusion is technically possible.
  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isAndroid);

  /// Blocks or allows screenshots / screen recording. No-op where unsupported.
  static Future<void> setBlocked(bool blocked) async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        await _desktop.invokeMethod<void>('setCaptureBlocked', blocked);
      } else if (Platform.isAndroid) {
        await _android.invokeMethod<void>('setSecure', blocked);
      }
    } on PlatformException {
      // Native side missing (e.g. tests) — never crash for a privacy toggle.
    } on MissingPluginException {
      // Same.
    }
  }

  /// Calls [onLocked] when Windows reports a session lock or system suspend.
  static void listenForWorkstationLock(VoidCallback onLocked) {
    if (kIsWeb || !Platform.isWindows) return;
    _desktop.setMethodCallHandler((call) async {
      if (call.method == 'sessionLocked') onLocked();
    });
  }
}

class _CaptureBlockedNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true; // default on
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(AppIdentifiers.prefBlockScreenCapture) ?? true;
    await CaptureGuard.setBlocked(state);
  }

  Future<void> set(bool blocked) async {
    state = blocked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppIdentifiers.prefBlockScreenCapture, blocked);
    await CaptureGuard.setBlocked(blocked);
  }
}

/// "Block screen capture" setting (default on).
final captureBlockedProvider = NotifierProvider<_CaptureBlockedNotifier, bool>(
  _CaptureBlockedNotifier.new,
);

/// Linux: GNOME Keyring / libsecret availability (non-blocking warning).
Future<bool> linuxSecretServiceAvailable() async {
  if (kIsWeb || !Platform.isLinux) return true;
  try {
    final r = await Process.run('sh', [
      '-c',
      'command -v secret-tool >/dev/null 2>&1 || '
          'command -v gnome-keyring-daemon >/dev/null 2>&1 || '
          'command -v kwalletd5 >/dev/null 2>&1 || '
          'command -v kwalletd6 >/dev/null 2>&1',
    ]);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}
