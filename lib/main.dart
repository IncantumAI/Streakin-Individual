// lib/main.dart
// Bootstrap only — calls runApp with ProviderScope. Spec §6.2.

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/app/app.dart';
import 'package:streakin/core/logging/app_logger.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/notifications/notification_reconciler.dart'
    show defaultNotificationScheduler;
import 'package:streakin/core/platform/desktop_notification_scheduler.dart';
import 'package:streakin/core/platform/tray_service.dart';
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/core/time/hlc.dart';

// Flavour: set by --dart-define=FLAVOR=prod (default: dev).
const String _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialise logging before anything else.
      AppLogger.init(verbose: _flavor != 'prod');

      // Silence super_editor's extremely verbose infrastructure loggers
      // (content_layers, editor.ime etc.) even in debug builds.
      if (kDebugMode) {
        Logger('infrastructure').level = Level.WARNING;
        Logger('editor').level = Level.WARNING;
      }

      // Memory budget (Spec §11.4): bounded decoded-image cache.
      PaintingBinding.instance.imageCache
        ..maximumSize = 150
        ..maximumSizeBytes = 48 << 20;

      // Apply SQLCipher Android workaround before any DB operations.
      await initSqlCipherOnAndroid();

      // Initialise HLC with a short device-specific node ID.
      // In production this should be derived from a stable device identifier.
      Hlc.init('0000');

      // Global Flutter error handler → friendly screen + local log.
      FlutterError.onError = (details) {
        AppLogger.get('Flutter').severe(
          'Unhandled Flutter error\n  ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
      };

      // Desktop reminders run on in-process timers (no OS scheduling there).
      if (DesktopNotificationScheduler.isDesktop) {
        defaultNotificationScheduler = () =>
            DesktopNotificationScheduler.instance;
      }

      // Desktop: window min size + close-to-tray (Phase 8A/B).
      final container = ProviderContainer();
      if (TrayService.supported) {
        TrayService.instance.onBeforeHide = () =>
            container.read(LockController.provider.notifier).lock();
        await TrayService.instance.start();
      }

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const StreakinApp(),
        ),
      );
    },
    (error, stack) {
      AppLogger.get('Zone').severe(
        'Unhandled zone error\n  Error type: ${error.runtimeType}\n  $error',
        error,
        stack,
      );
    },
  );
}
