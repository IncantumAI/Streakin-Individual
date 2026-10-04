// lib/core/logging/app_logger.dart
// Spec §14: package:logging with redacting sink.

import 'package:logging/logging.dart';

export 'package:logging/logging.dart' show Logger, Level;

class AppLogger {
  AppLogger._();
  static bool _initialised = false;

  static void init({required bool verbose}) {
    if (_initialised) return;
    _initialised = true;
    hierarchicalLoggingEnabled = true;
    Logger.root.level = verbose ? Level.ALL : Level.WARNING;
    Logger.root.onRecord.listen(RedactorSink._handle);
  }

  static Logger get(String name) => Logger(name);
}

class RedactorSink {
  RedactorSink._();

  // Dart RegExp does not support (?i) inline flags — use caseSensitive: false.
  static final _sensitivePatterns = <RegExp>[
    RegExp(r'password\s*[=:]\s*\S+', caseSensitive: false),
    RegExp(r'key\s*[=:]\s*[0-9a-fA-F]{8,}', caseSensitive: false),
    RegExp(r'[0-9a-fA-F]{32,}'),
    RegExp(r'token\s*[=:]\s*\S+', caseSensitive: false),
    RegExp(r'secret\s*[=:]\s*\S+', caseSensitive: false),
  ];

  static void _handle(LogRecord record) {
    final cleaned = _redact(record.message);
    final output = '[${record.level.name}][${record.loggerName}] $cleaned';
    // ignore: avoid_print
    print(output);
    if (record.error != null) {
      // ignore: avoid_print
      print('  Error type: ${record.error.runtimeType}');
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
