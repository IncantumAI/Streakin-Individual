// lib/core/storage/drift_vault_store.dart

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:streakin/core/security/vault_manager.dart';
import 'package:streakin/core/storage/app_database.dart';

class DriftVaultStore implements VaultStore {
  DriftVaultStore(this._db);
  final AppDatabase _db;

  VaultRecord _map(Vault r) => VaultRecord(
    id: r.id,
    name: r.name,
    kdfParams: jsonDecode(r.kdfParams) as Map<String, dynamic>,
    wrappedVaultKey: r.wrappedVaultKey,
    wrappedVaultKeyRecovery: r.wrappedVaultKeyRecovery,
    autoLockSeconds: r.autoLockSeconds,
  );

  @override
  Future<List<VaultRecord>> all() async =>
      (await _db.select(_db.vaults).get()).map(_map).toList();

  @override
  Future<VaultRecord?> get(String id) async {
    final r = await (_db.select(
      _db.vaults,
    )..where((v) => v.id.equals(id))).getSingleOrNull();
    return r == null ? null : _map(r);
  }

  @override
  Future<void> save(VaultRecord v) => _db
      .into(_db.vaults)
      .insertOnConflictUpdate(
        VaultsCompanion(
          id: Value(v.id),
          name: Value(v.name),
          kdfParams: Value(jsonEncode(v.kdfParams)),
          wrappedVaultKey: Value(v.wrappedVaultKey),
          wrappedVaultKeyRecovery: Value(v.wrappedVaultKeyRecovery),
          autoLockSeconds: Value(v.autoLockSeconds),
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.vaults)..where((v) => v.id.equals(id))).go();
}
