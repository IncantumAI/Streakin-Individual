// lib/core/platform/tray_service.dart
// Spec §12.3 / Phase 8A–B: close-to-tray on Windows and Linux.
//
// Closing the window hides it and shows a tray icon. The session is LOCKED
// first so no decrypted data (keys, DB, providers) stays in memory while the
// app idles in the tray; reminders keep firing from the process-wide
// DesktopNotificationScheduler. "Open" restores the window (user unlocks
// again); "Exit" quits.

// The nativeapi-based tray API is new in tray_manager 0.7; the legacy bridge
// is stable and enough for a single icon + menu.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart' show Size;
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  /// Called right before the window is hidden — lock the session here.
  Future<void> Function()? onBeforeHide;

  bool _started = false;
  bool _trayEnabled = true;

  static bool get supported => Platform.isWindows || Platform.isLinux;

  /// Window min size 800×600 (Spec §5.6) and close interception.
  Future<void> start({bool keepInTray = true}) async {
    if (!supported || _started) return;
    _started = true;
    _trayEnabled = keepInTray;
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
  }

  set keepInTray(bool v) => _trayEnabled = v;

  @override
  Future<void> onWindowClose() async {
    if (!_trayEnabled) {
      await windowManager.setPreventClose(false);
      await windowManager.close();
      return;
    }
    await onBeforeHide?.call();
    // TODO(rename): tooltip text.
    await trayManager.setIcon(
      Platform.isWindows
          ? 'windows/runner/resources/app_icon.ico'
          : 'assets/icon.png',
    );
    await trayManager.setToolTip('Streakin');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'open', label: 'Open Streakin'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Exit'),
        ],
      ),
    );
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  @override
  void onTrayIconMouseDown() => unawaited(_open());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'open') unawaited(_open());
    if (menuItem.key == 'exit') unawaited(_exit());
  }

  Future<void> _open() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
    await trayManager.destroy();
  }

  Future<void> _exit() async {
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
