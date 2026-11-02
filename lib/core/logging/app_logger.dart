// lib/core/logging/app_logger.dart
// Spec §14: package:logging with redacting sink.
// Production: all logging suppressed (Level.OFF). No console output.
// Debug: Level.ALL with redaction.

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:logging/logging.dart';

export 'package:logging/logging.dart' show Logger, Level;

class AppLogger {
  AppLogger._();
  static bool _initialised = false;

  static void init({required bool verbose}) {
    if (_initialised) return;
    _initialised = true;
    hierarchicalLoggingEnabled = true;

    if (!kDebugMode) {
      // Production: suppress ALL logging — no console output whatsoever.
      // Only SEVERE errors are kept, routed through the zone error handler
      // in main.dart, not printed.
      Logger.root.level = Level.OFF;
      return;
    }

    // Debug builds: log everything; redact sensitive values.
    Logger.root.level = verbose ? Level.ALL : Level.WARNING;
    Logger.root.onRecord.listen(RedactorSink._handle);
  }

  static Logger get(String name) => Logger(name);
}

class RedactorSink {
  RedactorSink._();

  static final _sensitivePatterns = <RegExp>[
    RegExp(r'password\s*[=:]\s*\S+', caseSensitive: false),
    RegExp(r'key\s*[=:]\s*[0-9a-fA-F]{8,}', caseSensitive: false),
    RegExp(r'[0-9a-fA-F]{32,}'),
    RegExp(r'token\s*[=:]\s*\S+', caseSensitive: false),
    RegExp(r'secret\s*[=:]\s*\S+', caseSensitive: false),
  ];

  static void _handle(LogRecord record) {
    if (!kDebugMode) return; // Extra guard — should not reach here in prod.
    final cleaned = _redact(record.message);
    final output = '[${record.level.name}][${record.loggerName}] $cleaned';
    debugPrint(output);
    if (record.error != null) {
      debugPrint('  Error type: ${record.error.runtimeType}');
    }
  }

  static String _redact(String message) {
    var result = message;
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAll(pattern, '[REDACTED]');
    }
    return result;
  }

  static String redactForTest(String message) => _redact(message);
}
