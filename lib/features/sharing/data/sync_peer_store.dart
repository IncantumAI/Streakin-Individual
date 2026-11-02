// lib/features/sharing/data/sync_peer_store.dart — `sync_peers` table access.

import 'package:drift/drift.dart';

import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';

class SyncPeerStore {
  SyncPeerStore(this._db);
  final AppDatabase _db;

  Stream<List<SyncPeer>> watchAll() => _db.select(_db.syncPeers).watch();
  Future<List<SyncPeer>> all() => _db.select(_db.syncPeers).get();

  Future<SyncPeer?> byDeviceId(String deviceId) => (_db.select(
    _db.syncPeers,
  )..where((p) => p.deviceId.equals(deviceId))).getSingleOrNull();

  /// Records a peer after the SAS was confirmed on both devices.
  Future<SyncPeer> add(
    DevicePublicBundle bundle,
    String name, {
    DateTime? now,
  }) async {
    final row = SyncPeersCompanion(
      deviceId: Value(bundle.fingerprint),
      name: Value(name),
      publicKey: Value(bundle.base32),
      pairedAt: Value((now ?? DateTime.now().toUtc()).toIso8601String()),
    );
    await _db.into(_db.syncPeers).insertOnConflictUpdate(row);
    return (await byDeviceId(bundle.fingerprint))!;
  }

  Future<void> unpair(String deviceId) => (_db.delete(
    _db.syncPeers,
  )..where((p) => p.deviceId.equals(deviceId))).go();

  Future<void> setLastSent(String deviceId, String hlc) =>
      (_db.update(_db.syncPeers)..where((p) => p.deviceId.equals(deviceId)))
          .write(SyncPeersCompanion(lastSentHlc: Value(hlc)));

  Future<void> setLastRecv(String deviceId, String hlc) =>
      (_db.update(_db.syncPeers)..where((p) => p.deviceId.equals(deviceId)))
          .write(SyncPeersCompanion(lastRecvHlc: Value(hlc)));

  static DevicePublicBundle bundleOf(SyncPeer p) =>
      DevicePublicBundle.parse(p.publicKey);
}
