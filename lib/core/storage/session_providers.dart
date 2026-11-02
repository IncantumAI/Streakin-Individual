// lib/core/storage/session_providers.dart
// Session-scoped DB provider — opened once per unlock using the key vault.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/features/habits/data/drift_habit_repository.dart';
import 'package:streakin/features/habits/data/habit_dao.dart';

/// Opens AppDatabase using a synchronous copy of the DEK extracted from
/// the vault. The copy is zeroed after the DB is opened.
/// Uses [ref.read] (not watch) so it never rebuilds on vault changes.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  // Extract DEK bytes synchronously while vault is guaranteed unlocked.
  // Take a defensive copy so the vault's zero-fill doesn't affect us.
  late Uint8List dekCopy;
  ref.read(keyVaultProvider).useSync((key) {
    dekCopy = Uint8List.fromList(key); // copy before any async gap
  });

  try {
    final db = await openAppDatabase(dekCopy);
    ref.onDispose(db.close);
    return db;
  } finally {
    SecureBytes.zeroFill(dekCopy); // zero our local copy immediately
  }
});

/// Wraps the DB into a HabitRepository provider.
final sessionHabitRepositoryProvider = FutureProvider<DriftHabitRepository>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftHabitRepository(HabitDao(db));
});
