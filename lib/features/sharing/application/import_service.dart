// lib/features/sharing/application/import_service.dart
// Spec §10.3/§10.4 import: open → preview (no writes) → apply (one
// transaction; any failure rolls everything back). Every attachment is
// re-validated: the sender is never trusted.

import 'dart:typed_data';

import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/validation/attachment_validator.dart';
import 'package:streakin/features/notes/notes_module.dart'
    as domain
    show AttachmentKindExt;
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/data/ncx_reader.dart';
import 'package:streakin/features/sharing/data/sharing_store.dart';
import 'package:streakin/features/sharing/data/sync_peer_store.dart';
import 'package:streakin/features/sharing/domain/ncx_container.dart';

/// A decrypted, not-yet-applied import.
class ImportSession {
  ImportSession._(this.header, this.payload, this.records, this.peer);
  final NcxHeader header;
  final NcxPayload payload;
  final ExportRecords records;
  final SyncPeer? peer;

  Map<String, dynamic> get manifest => payload.manifest;
  int get schemaVer => (manifest['schemaVer'] as int?) ?? 0;
  String? get maxHlc => manifest['maxHlc'] as String?;
  int get attachmentBytes => payload.entries.entries
      .where((e) => e.key.startsWith('attachments/'))
      .fold(0, (a, e) => a + e.value.length);
}

class ImportResult {
  const ImportResult({
    required this.appliedNoteIds,
    required this.attachmentsSaved,
  });
  final Set<String> appliedNoteIds;
  final int attachmentsSaved;
}

class ImportService {
  ImportService({
    required this._db,
    required this._identity,
    required this._peers,
    required this._saveAttachment,
    this._onApplied,
    this._validator = const AttachmentValidator(),
  });

  final AppDatabase _db;
  final DeviceIdentity _identity;
  final SyncPeerStore _peers;
  final Future<void> Function(Attachment row, Uint8List plain) _saveAttachment;
  final Future<void> Function(Set<String> noteIds)? _onApplied;
  final AttachmentValidator _validator;

  /// Which prompt the UI needs (passphrase / paired device / raw key).
  NcxHeader peek(Uint8List bytes) => NcxReader.peekHeader(bytes);

  /// Decrypts and authenticates. Throws [CryptoFailure] (tampered / wrong key).
  Future<ImportSession> open(
    Uint8List bytes, {
    String? passphrase,
    Uint8List? rawKey,
  }) async {
    final header = NcxReader.peekHeader(bytes);
    SyncPeer? peer;
    DevicePublicBundle? expected;
    if (header.scheme != NcxScheme.pass) {
      peer = await _peers.byDeviceId(header.senderDeviceId);
      if (peer != null) expected = SyncPeerStore.bundleOf(peer);
      if (header.scheme == NcxScheme.pair && peer == null) {
        throw const CryptoFailure(
          'This file is from a device you have not paired',
        );
      }
    }
    final payload = await NcxReader.open(
      bytes,
      passphrase: passphrase,
      rawKey: rawKey,
      identity: _identity,
      expectedSender: expected,
    );
    final records = ExportRecords.fromNdjson(payload.recordsNdjson);
    return ImportSession._(header, payload, records, peer);
  }

  String? _lastCommon(ImportSession s) {
    final p = s.peer;
    return p == null ? null : maxHlc([p.lastSentHlc, p.lastRecvHlc]);
  }

  /// Counts only — writes nothing.
  Future<ImportPreview> preview(ImportSession s) => SharingStore(_db).preview(
    s.records,
    schemaVer: s.schemaVer,
    attachmentSizeBytes: s.attachmentBytes,
    lastCommonHlc: _lastCommon(s),
  );

  Future<ImportResult> apply(ImportSession s) async {
    if (s.schemaVer > _db.schemaVersion) {
      throw const ValidationFailure(
        'This file was made by a newer version of the app. Update first.',
      );
    }

    // 1 — Re-validate every attachment BEFORE touching the database.
    final validated = <String, Uint8List>{};
    for (final row
        in s.records.tables['attachments'] ?? const <Map<String, dynamic>>[]) {
      final att = Attachment.fromJson(row);
      final bytes = s.payload.entries['attachments/${att.id}'];
      if (bytes == null) continue; // metadata without a blob: skipped
      final kind = domain.AttachmentKindExt.fromString(att.kind);
      final result = _validator.validate(
        bytes,
        '${att.id}.${kind.extensions.first}',
      );
      validated[att.id] = result.sanitizedBytes;
    }

    // 2 — One transaction for all rows.
    final store = SharingStore(_db);
    final touched = await store.apply(
      s.records,
      lastCommonHlc: _lastCommon(s),
      senderName: s.header.senderName.isEmpty
          ? 'other device'
          : s.header.senderName,
    );

    // 3 — Blobs (files) after the DB commit.
    var saved = 0;
    for (final row
        in s.records.tables['attachments'] ?? const <Map<String, dynamic>>[]) {
      final att = Attachment.fromJson(row);
      final plain = validated[att.id];
      if (plain == null) continue;
      await _saveAttachment(att, plain);
      saved++;
    }

    // 4 — Sync bookkeeping + derived-state refresh.
    final peer = s.peer;
    final newest = s.maxHlc;
    if (peer != null && newest != null) {
      await _peers.setLastRecv(peer.deviceId, newest);
    }
    await _onApplied?.call(touched);
    return ImportResult(appliedNoteIds: touched, attachmentsSaved: saved);
  }
}
