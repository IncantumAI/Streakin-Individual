// lib/features/notes/domain/attachment.dart
// Attachment domain entity and kind enum.

import 'dart:typed_data';

/// Supported attachment kinds. Magic bytes + extension + MIME must agree.
enum AttachmentKind { png, jpeg, svg, pdf, csv, txt, docx, pptx }

extension AttachmentKindExt on AttachmentKind {
  String get serialized => name; // 'png', 'jpeg', etc.

  static AttachmentKind fromString(String s) {
    return AttachmentKind.values.firstWhere(
      (k) => k.name == s,
      orElse: () => throw ArgumentError('Unknown AttachmentKind: $s'),
    );
  }

  /// Expected file extensions (lower-cased).
  List<String> get extensions => switch (this) {
    AttachmentKind.png => ['png'],
    AttachmentKind.jpeg => ['jpg', 'jpeg'],
    AttachmentKind.svg => ['svg'],
    AttachmentKind.pdf => ['pdf'],
    AttachmentKind.csv => ['csv'],
    AttachmentKind.txt => ['txt'],
    AttachmentKind.docx => ['docx'],
    AttachmentKind.pptx => ['pptx'],
  };

  /// MIME type for this kind.
  String get mime => switch (this) {
    AttachmentKind.png => 'image/png',
    AttachmentKind.jpeg => 'image/jpeg',
    AttachmentKind.svg => 'image/svg+xml',
    AttachmentKind.pdf => 'application/pdf',
    AttachmentKind.csv => 'text/csv',
    AttachmentKind.txt => 'text/plain',
    AttachmentKind.docx =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    AttachmentKind.pptx => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  /// Per-kind file size cap in bytes.
  int get maxBytes => switch (this) {
    AttachmentKind.png => 10 * 1024 * 1024, // 10 MB
    AttachmentKind.jpeg => 10 * 1024 * 1024, // 10 MB
    AttachmentKind.svg => 1 * 1024 * 1024, // 1 MB
    AttachmentKind.pdf => 25 * 1024 * 1024, // 25 MB
    AttachmentKind.csv => 25 * 1024 * 1024, // 25 MB
    AttachmentKind.txt => 25 * 1024 * 1024, // 25 MB
    AttachmentKind.docx => 25 * 1024 * 1024, // 25 MB
    AttachmentKind.pptx => 25 * 1024 * 1024, // 25 MB
  };
}

class Attachment {
  const Attachment({
    required this.id,
    required this.noteId,
    required this.kind,
    required this.mime,
    required this.size,
    required this.sha256,
    required this.storageName,
    required this.createdAt,
  });

  final String id;
  final String noteId;
  final AttachmentKind kind;
  final String mime;
  final int size;
  final String sha256;

  /// UUID filename under attachments/ in the encrypted FileStore.
  final String storageName;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Attachment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Result of a successful validation — carries re-encoded bytes + metadata.
class ValidatedAttachment {
  const ValidatedAttachment({
    required this.kind,
    required this.mime,
    required this.originalFilename,
    required this.sanitizedBytes,
    required this.sha256,
    this.thumbnailBytes,
  });

  final AttachmentKind kind;
  final String mime;
  final String originalFilename;

  /// Re-encoded (safe) bytes — strip EXIF, re-encode images, sanitise SVG, etc.
  final Uint8List sanitizedBytes;
  final String sha256;

  /// Only set for PNG/JPEG — small preview thumbnail bytes (pre-encrypted).
  final Uint8List? thumbnailBytes;
}
