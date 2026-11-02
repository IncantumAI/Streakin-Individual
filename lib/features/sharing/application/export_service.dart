// lib/features/sharing/application/export_service.dart
// Spec §10.1/§10.4 export: full or delta, three key modes. Vault notes leave
// as ciphertext and only when their vault is unlocked.

import 'dart:convert';
import 'dart:typed_data';

import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/data/ncx_writer.dart';
import 'package:streakin/features/sharing/data/sharing_store.dart';
import 'package:streakin/features/sharing/data/sync_peer_store.dart';
import 'package:streakin/features/sharing/domain/ncx_container.dart';

class ExportResult {
  const ExportResult({
    required this.bytes,
    required this.fileName,
    required this.recordCount,
    required this.excludedLockedVaults,
    this.rawKey,
  });
  final Uint8List bytes;
  final String fileName;
  final int recordCount;

  /// Locked vaults whose notes were left out (UI shows a warning).
  final List<String> excludedLockedVaults;

  /// Mode C only: the key the recipient needs (show once).
  final Uint8List? rawKey;
}

class ExportService {
  ExportService({
    required this._db,
    required this._identity,
    required this._peers,
    required this._isVaultUnlocked,
    required this._loadAttachmentPlain,
    this.deviceName = 'This device',
    this.kdf = const NcxKdf(),
  });

  final AppDatabase _db;
  final DeviceIdentity _identity;
  final SyncPeerStore _peers;
  final bool Function(String vaultId) _isVaultUnlocked;
  final Future<Uint8List?> Function(Attachment row) _loadAttachmentPlain;
  final String deviceName;
  final NcxKdf kdf;

  /// Vault ids that have notes but are currently locked.
  Future<List<String>> lockedVaultsWithNotes() async {
    final notes = await _db.select(_db.notes).get();
    return {
      for (final n in notes)
        if (n.vaultId != null && !_isVaultUnlocked(n.vaultId!)) n.vaultId!,
    }.toList();
  }

  /// [onProgress] receives 0..1 while records and attachments are packed.
  Future<ExportResult> export({
    required NcxScheme scheme,
    NcxScope scope = NcxScope.full,
    String? passphrase,
    SyncPeer? peer,
    void Function(double progress)? onProgress,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    String? since;
    if (scope == NcxScope.delta) {
      since = peer?.lastSentHlc; // null → behaves like a full export
    }

    final locked = await lockedVaultsWithNotes();
    onProgress?.call(0.05);
    final records = await _collectWith(since);
    onProgress?.call(0.4);

    // Attachments: decrypted locally, re-protected by the container AEAD.
    final entries = <String, Uint8List>{};
    final index = <Map<String, dynamic>>[];
    final rows =
        records.tables['attachments'] ?? const <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = Attachment.fromJson(rows[i]);
      final plain = await _loadAttachmentPlain(row);
      if (plain != null) {
        entries['attachments/${row.id}'] = plain;
        index.add({
          'id': row.id,
          'sha256': row.sha256,
          'size': plain.length,
          'kind': row.kind,
        });
      }
      onProgress?.call(0.4 + 0.5 * ((i + 1) / rows.length));
    }

    final manifest = SharingStore.manifestFor(
      records,
      schemaVersion: _db.schemaVersion,
      deviceId: _identity.deviceId,
      scope: scope.name,
      sinceHlc: since,
      attachmentIndex: index,
    );
    entries['manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    );
    entries['records.ndjson'] = Uint8List.fromList(
      utf8.encode(records.toNdjson()),
    );

    Uint8List? rawKey;
    if (scheme == NcxScheme.key) rawKey = SecureBytes.randomBytes(32);

    final bytes = await NcxWriter.build(
      scheme: scheme,
      entries: entries,
      identity: _identity,
      senderName: deviceName,
      scope: scope,
      sinceHlc: since,
      passphrase: passphrase,
      kdf: kdf,
      recipient: peer == null ? null : SyncPeerStore.bundleOf(peer),
      rawKey: rawKey,
      now: stamp.toUtc(),
    );
    onProgress?.call(1);

    if (peer != null && scheme == NcxScheme.pair) {
      final newest = SharingStore.newestHlc(records);
      if (newest != null) await _peers.setLastSent(peer.deviceId, newest);
    }

    String two(int v) => v.toString().padLeft(2, '0');
    // TODO(rename): brand prefix of the exported file name.
    final name =
        'streakin-export-${stamp.year}${two(stamp.month)}${two(stamp.day)}'
        '-${two(stamp.hour)}${two(stamp.minute)}.$kNcxExtension';

    return ExportResult(
      bytes: bytes,
      fileName: name,
      recordCount: records.total,
      excludedLockedVaults: locked,
      rawKey: rawKey,
    );
  }

  Future<ExportRecords> _collectWith(String? since) =>
      SharingStore(_db)
          .collect(sinceHlc: since, includeVault: _isVaultUnlocked);
}
