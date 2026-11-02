// lib/core/security/erase_all_data_service.dart
// Spec §4.10: irreversibly deletes core.db, keyring.bin, attachments/,
// secure-storage entries and preferences. Caller navigates to onboarding.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/core/security/vault_manager.dart';
import 'package:streakin/core/storage/identifiers.dart';

class EraseAllDataService {
  EraseAllDataService(this._ref, {Directory? supportDir})
    : _supportDirOverride = supportDir;
  final Ref _ref;
  final Directory? _supportDirOverride;

  Future<void> eraseAll() async {
    // Lock first: drops keys and closes the session/DB.
    _ref.read(vaultManagerStateProvider)?.lockAll();
    await _ref.read(LockController.provider.notifier).lock();
    // Give SessionScope a frame to close the DB handle.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final dir = _supportDirOverride ?? await getApplicationSupportDirectory();
    for (final name in [
      AppIdentifiers.dbFileName,
      '${AppIdentifiers.dbFileName}-wal',
      '${AppIdentifiers.dbFileName}-shm',
      AppIdentifiers.keyringFileName,
    ]) {
      final f = File(p.join(dir.path, name));
      if (f.existsSync()) {
        await _overwriteAndDelete(f);
      }
    }
    final attachments = Directory(p.join(dir.path, 'attachments'));
    if (attachments.existsSync()) await attachments.delete(recursive: true);

    try {
      await const FlutterSecureStorage().deleteAll();
      await const FlutterSecureStorage(
        // ignore: deprecated_member_use
        aOptions: AndroidOptions(sharedPreferencesName: 'biometric_storage_v2'),
      ).deleteAll();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _overwriteAndDelete(File f) async {
    try {
      final len = await f.length();
      if (len > 0 && len < 256 * 1024 * 1024) {
        await f.writeAsBytes(List<int>.filled(len, 0), flush: true);
      }
    } catch (_) {}
    await f.delete();
  }
}

final eraseAllDataServiceProvider = Provider<EraseAllDataService>(
  EraseAllDataService.new,
);
