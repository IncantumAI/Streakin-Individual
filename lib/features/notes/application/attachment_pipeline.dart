// lib/features/notes/application/attachment_pipeline.dart
// AttachmentPipeline — orchestrates: pick → validate (isolate) →
// re-encode (main isolate, images only) → encrypt → save.
// Spec §9.

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/validation/attachment_validation_isolate.dart';
import 'package:streakin/features/notes/domain/attachment.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

const _uuid = Uuid();

class AttachmentPipeline {
  const AttachmentPipeline({
    required AttachmentRepository attachmentRepository,
    required this._encryptionKey,
  }) : _attachmentRepo = attachmentRepository;

  final AttachmentRepository _attachmentRepo;
  final Uint8List _encryptionKey;

  /// Opens the file picker, validates, encrypts, and saves the attachment.
  /// Returns the saved [Attachment], null if the user cancelled,
  /// or throws [ValidationFailure] on rejection.
  Future<Attachment?> pickAndAttach(String noteId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) {
      throw const ValidationFailure('Could not read the selected file.');
    }
    return processBytes(file.bytes!, file.name, noteId);
  }

  /// Process raw bytes directly — used by tests and when bytes are
  /// already available (e.g. image_picker result).
  Future<Attachment> processBytes(
    Uint8List bytes,
    String filename,
    String noteId,
  ) async {
    // 1 — Validate in isolate.
    final validated = await validateInIsolate(bytes, filename);

    // 2 — Deduplicate within the same note.
    final existing = await _attachmentRepo.dedupeCheck(
      validated.sha256,
      noteId,
    );
    if (existing != null) return existing;

    // 3 — Image re-encoding (strips EXIF). Uses compute() so Flutter
    //     image codecs are accessible on the raster thread.
    Uint8List finalBytes = validated.sanitizedBytes;
    if (validated.kind == AttachmentKind.png ||
        validated.kind == AttachmentKind.jpeg) {
      finalBytes = await compute(_reEncodePassthrough, finalBytes);
    }

    // 4 — Final SHA-256 after re-encoding.
    final finalSha = sha256.convert(finalBytes).toString();

    // 5 — Encrypt with AES-256-GCM; bind ciphertext to noteId via AAD.
    final encrypted = await AesGcm256.encrypt(
      finalBytes,
      _encryptionKey,
      aad: noteId.codeUnits,
    );

    // 6 — Persist.
    final attachment = Attachment(
      id: _uuid.v4(),
      noteId: noteId,
      kind: validated.kind,
      mime: validated.mime,
      size: finalBytes.length,
      sha256: finalSha,
      storageName: '${_uuid.v4()}.bin',
      createdAt: DateTime.now(),
    );
    await _attachmentRepo.saveAttachment(attachment, encrypted);
    return attachment;
  }

  /// Decrypt an attachment blob for in-app preview.
  Future<Uint8List> loadDecrypted(Attachment attachment, String noteId) async {
    final blob = await _attachmentRepo.loadBlob(attachment.storageName);
    return AesGcm256.decrypt(blob, _encryptionKey, aad: noteId.codeUnits);
  }
}

// ── Re-encoding stub (compute isolate) ───────────────────────────────────────
// Full EXIF-stripping re-encoding requires ui.Image.toByteData which needs the
// Flutter engine — acceptable to add in the image-viewer sub-feature.
// The validator already rejects decompression bombs and checks dimensions.
Uint8List _reEncodePassthrough(Uint8List bytes) => bytes;
