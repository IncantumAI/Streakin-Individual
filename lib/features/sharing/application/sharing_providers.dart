// lib/features/sharing/application/sharing_providers.dart
// Wires export/import services to the open session (DB, key vault, vaults).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/crypto/hkdf.dart';
import 'package:streakin/core/notifications/notification_reconciler.dart'
    show reconcilerStateProvider;
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/core/security/vault_manager.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/storage/session_database.dart';
import 'package:streakin/features/notes/notes_module.dart'
    show noteRepositoryStateProvider;
import 'package:streakin/features/sharing/application/export_service.dart';
import 'package:streakin/features/sharing/application/import_service.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/data/sync_peer_store.dart';

final deviceIdentityProvider = FutureProvider<DeviceIdentity>(
  (ref) => DeviceIdentity.loadOrCreate(),
);

final syncPeerStoreProvider = Provider<SyncPeerStore?>((ref) {
  final db = ref.watch(sessionDatabaseProvider);
  return db == null ? null : SyncPeerStore(db);
});

final syncPeersProvider = StreamProvider<List<SyncPeer>>((ref) {
  final store = ref.watch(syncPeerStoreProvider);
  return store == null ? const Stream.empty() : store.watchAll();
});

Future<Directory> _attachmentsDir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'attachments'));
  if (!dir.existsSync()) await dir.create(recursive: true);
  return dir;
}

Future<Uint8List> _attachKey(Ref ref) => ref
    .read(keyVaultProvider)
    .use((dek) => HkdfDerive.deriveAttachKey(Uint8List.fromList(dek)));

final exportServiceProvider = FutureProvider<ExportService?>((ref) async {
  final db = ref.watch(sessionDatabaseProvider);
  if (db == null) return null;
  final identity = await ref.watch(deviceIdentityProvider.future);
  return ExportService(
    db: db,
    identity: identity,
    peers: SyncPeerStore(db),
    isVaultUnlocked: (id) =>
        ref.read(vaultManagerStateProvider)?.isUnlocked(id) ?? false,
    loadAttachmentPlain: (row) async {
      final file = File(
        p.join((await _attachmentsDir()).path, row.storageName),
      );
      if (!file.existsSync()) return null;
      return AesGcm256.decrypt(
        await file.readAsBytes(),
        await _attachKey(ref),
        aad: row.noteId.codeUnits,
      );
    },
  );
});

final importServiceProvider = FutureProvider<ImportService?>((ref) async {
  final db = ref.watch(sessionDatabaseProvider);
  if (db == null) return null;
  final identity = await ref.watch(deviceIdentityProvider.future);
  return ImportService(
    db: db,
    identity: identity,
    peers: SyncPeerStore(db),
    saveAttachment: (row, plain) async {
      final enc = await AesGcm256.encrypt(
        plain,
        await _attachKey(ref),
        aad: row.noteId.codeUnits,
      );
      await File(p.join((await _attachmentsDir()).path, row.storageName))
          .writeAsBytes(enc, flush: true);
    },
    onApplied: (noteIds) async {
      // Rebuild links/tags/mentions/FTS for imported (non-vault) notes by
      // re-saving them through the repository.
      final repo = ref.read(noteRepositoryStateProvider);
      if (repo != null) {
        for (final id in noteIds) {
          final n = await repo.getById(id);
          if (n != null && n.vaultId == null && !n.isDeleted) {
            await repo.saveNote(n);
          }
        }
      }
      // Imported reminders / tasks → notifications.
      await ref.read(reconcilerStateProvider)?.reconcile();
    },
  );
});
