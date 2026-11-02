// lib/core/validation/attachment_validation_isolate.dart
// Runs AttachmentValidator in a Dart worker isolate so the UI thread
// is never blocked during file validation (spec §9.2).

import 'dart:isolate';
import 'dart:typed_data';

import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/validation/attachment_validator.dart';
import 'package:streakin/features/notes/domain/attachment.dart';

// ── Message types (must be sendable across isolates) ─────────────────────────

class _ValidationRequest {
  const _ValidationRequest({
    required this.bytes,
    required this.filename,
    required this.sendPort,
  });
  final Uint8List bytes;
  final String filename;
  final SendPort sendPort;
}

class _ValidationResult {
  const _ValidationResult({this.value, this.errorMessage});
  final ValidatedAttachment? value;
  final String? errorMessage;
}

// ── Isolate entry point ───────────────────────────────────────────────────────

void _validationIsolateMain(_ValidationRequest req) {
  try {
    const validator = AttachmentValidator();
    final result = validator.validate(req.bytes, req.filename);
    req.sendPort.send(_ValidationResult(value: result));
  } on ValidationFailure catch (e) {
    req.sendPort.send(_ValidationResult(errorMessage: e.message));
  } catch (e) {
    req.sendPort.send(
      _ValidationResult(errorMessage: 'An unexpected error occurred: $e'),
    );
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Validate [bytes] with [filename] in a worker isolate.
/// Returns [ValidatedAttachment] or throws [ValidationFailure].
Future<ValidatedAttachment> validateInIsolate(
  Uint8List bytes,
  String filename,
) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    _validationIsolateMain,
    _ValidationRequest(
      bytes: bytes,
      filename: filename,
      sendPort: receivePort.sendPort,
    ),
  );

  final result = await receivePort.first as _ValidationResult;
  receivePort.close();

  if (result.errorMessage != null) {
    throw ValidationFailure(result.errorMessage!);
  }
  return result.value!;
}
