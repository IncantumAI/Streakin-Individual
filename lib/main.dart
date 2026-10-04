// lib/main.dart
// Bootstrap only — calls runApp with ProviderScope. Spec §6.2.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/app/app.dart';
import 'package:streakin/core/logging/app_logger.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/time/hlc.dart';

// Flavour: set by --dart-define=FLAVOR=prod (default: dev).
const String _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialise logging before anything else.
      AppLogger.init(verbose: _flavor != 'prod');

      // Apply SQLCipher Android workaround before any DB operations.
      await initSqlCipherOnAndroid();

      // Initialise HLC with a short device-specific node ID.
      // In production this should be derived from a stable device identifier.
      Hlc.init('0000');

      // Global Flutter error handler → friendly screen + local log.
      FlutterError.onError = (details) {
        AppLogger.get('Flutter').severe(
          'Unhandled Flutter error',
          details.exception,
          details.stack,
        );
      };

      runApp(
        const ProviderScope(
          child: StreakinApp(),
        ),
      );
    },
    (error, stack) {
      AppLogger.get('Zone').severe('Unhandled zone error', error, stack);
    },
  );
}
