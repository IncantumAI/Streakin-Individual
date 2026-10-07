// lib/core/storage/session_scope.dart
// Opens the SQLCipher DB after unlock and writes the repository into
// habitRepositoryStateProvider (a root-level StateProvider).

import 'dart:typed_data';

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/crypto/hkdf.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/features/habits/data/drift_habit_repository.dart';
import 'package:streakin/features/habits/data/habit_dao.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/data/note_dao.dart';
import 'package:streakin/features/notes/data/drift_note_repository.dart';
import 'package:streakin/features/notes/application/todo_bridge_impl.dart';
import 'package:streakin/features/todos/application/todo_providers.dart';
import 'package:streakin/features/todos/data/todo_dao.dart';
import 'package:streakin/features/todos/data/drift_todo_repository.dart';

class SessionScope extends ConsumerStatefulWidget {
  const SessionScope({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends ConsumerState<SessionScope> {
  AppDatabase? _db;
  bool _ready = false;
  bool _wrongKey = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  @override
  void dispose() {
    if (mounted) {
      try {
        ref.read(habitRepositoryStateProvider.notifier).clear();
        ref.read(noteRepositoryStateProvider.notifier).clear();
        ref.read(attachmentRepositoryStateProvider.notifier).clear();
        ref.read(ftsRepositoryStateProvider.notifier).clear();
        ref.read(todoRepositoryStateProvider.notifier).clear();
        ref.read(todoBridgeStateProvider.notifier).clear();
      } catch (_) {}
    }
    _db?.close();
    super.dispose();
  }

  Future<void> _openDatabase() async {
    try {
      late Uint8List dekCopy;
      ref.read(keyVaultProvider).useSync((key) {
        dekCopy = Uint8List.fromList(key);
      });

      final dbKey = await HkdfDerive.deriveDbKey(dekCopy);
      SecureBytes.zeroFill(dekCopy);
      final hexKey = SecureBytes.toHex(dbKey);
      SecureBytes.zeroFill(dbKey);

      final db = await openAppDatabaseWithKey(hexKey);

      // Probe the DB immediately to detect wrong key before showing the shell.
      // NativeDatabase is lazy — it only opens on first query.
      // This will throw SqliteException if the key is wrong.
      await db.customSelect('SELECT 1').get();

      final repo = DriftHabitRepository(HabitDao(db));
      ref.read(habitRepositoryStateProvider.notifier).set(repo);

      // ── Notes repositories ───────────────────────────────────────────────
      final noteDao = NoteDao(db);
      final ftsDao = NoteFtsDao(db);
      final attachmentDao = AttachmentDao(db);
      ref.read(noteRepositoryStateProvider.notifier).set(
            DriftNoteRepository(noteDao, ftsDao),
          );
      ref.read(attachmentRepositoryStateProvider.notifier).set(
            DriftAttachmentRepository(attachmentDao),
          );
      ref.read(ftsRepositoryStateProvider.notifier).set(
            DriftFtsRepository(ftsDao),
          );

      // ── Todos repository ─────────────────────────────────────────────────
      final todoDao = TodoDao(db);
      final todoRepo = DriftTodoRepository(todoDao);
      ref.read(todoRepositoryStateProvider.notifier).set(todoRepo);

      // ── Todo bridge (notes ↔ todos) ──────────────────────────────────────
      final noteRepoForBridge = DriftNoteRepository(noteDao, ftsDao);
      ref.read(todoBridgeStateProvider.notifier).set(
            TodoBridgeImpl(
              noteRepo: noteRepoForBridge,
              todoRepo: todoRepo,
            ),
          );

      if (mounted) {
        setState(() {
          _db = db;
          _ready = true;
        });
      } else {
        await db.close();
      }
    } on SqliteException catch (e) {
      // Wrong key or corrupted DB — likely stale data from a previous install.
      debugPrint('SessionScope wrong key or corrupt DB: $e');
      if (mounted) setState(() => _wrongKey = true);
    } catch (e, st) {
      if (mounted) setState(() => _error = e);
      debugPrint('SessionScope DB open error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_wrongKey) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_reset, size: 56, color: Colors.orange),
                SizedBox(height: 20),
                Text(
                  'Database key mismatch',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'The app was updated with a new encryption setup.\n\n'
                  'Please clear the app data:\n'
                  'Settings → Apps → Streakin → Storage → Clear Data',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to open database:\n$_error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return widget.child;
  }
}
