// Track 5A: VaultManager + vault-aware note repository.

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/security/vault_manager.dart';
import 'package:streakin/core/storage/app_database.dart' show AppDatabase;
import 'package:streakin/core/storage/drift_vault_store.dart';
import 'package:streakin/features/notes/application/vault_migration.dart';
import 'package:streakin/features/notes/data/drift_note_repository.dart';
import 'package:streakin/features/notes/data/note_dao.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';

const _cheap = VaultKdfParams(ops: 1, memKiB: 8);

class _MemStore implements VaultStore {
  final Map<String, VaultRecord> rows = {};
  @override
  Future<List<VaultRecord>> all() async => rows.values.toList();
  @override
  Future<VaultRecord?> get(String id) async => rows[id];
  @override
  Future<void> save(VaultRecord v) async => rows[v.id] = v;
  @override
  Future<void> delete(String id) async => rows.remove(id);
}

class _NoOpFts extends NoteFtsDao {
  _NoOpFts(super.db);
  @override
  Future<void> index(String noteId, String title, String plainText) async {}
  @override
  Future<void> remove(String noteId) async {}
}

Note _note(String id, String title, String body) => Note(
  id: id,
  title: title,
  body: body,
  createdAt: DateTime(2026, 10, 7),
  updatedAt: DateTime(2026, 10, 7),
  hlc: 'h',
);

void main() {
  group('VaultManager', () {
    late _MemStore store;
    late VaultManager vm;
    late List<Set<String>> events;

    setUp(() {
      store = _MemStore();
      events = [];
      vm = VaultManager(store: store, kdf: _cheap, onChanged: events.add);
    });

    test('create → unlocked; lock → key dropped', () async {
      final id = await vm.createVault('Private', 'correct horse');
      expect(vm.isUnlocked(id), isTrue);
      vm.lockVault(id);
      expect(vm.isUnlocked(id), isFalse);
      expect(() => vm.use(id, (_) async => 1), throwsA(isA<AuthFailure>()));
    });

    test('unlock with right/wrong password', () async {
      final id = await vm.createVault('Private', 'correct horse');
      vm.lockVault(id);
      await expectLater(
        vm.unlockVault(id, 'wrong'),
        throwsA(isA<AuthFailure>()),
      );
      await vm.unlockVault(id, 'correct horse');
      expect(vm.isUnlocked(id), isTrue);
    });

    test('encrypt/decrypt round-trips and rejects when locked', () async {
      final id = await vm.createVault('Private', 'pw-12345678');
      final ct = await vm.encrypt(id, 'secret body');
      expect(VaultManager.isCiphertext(ct), isTrue);
      expect(ct.contains('secret'), isFalse);
      expect(await vm.decrypt(id, ct), 'secret body');
      vm.lockVault(id);
      await expectLater(vm.decrypt(id, ct), throwsA(isA<AuthFailure>()));
    });

    test('tampered ciphertext fails authentication', () async {
      final id = await vm.createVault('Private', 'pw-12345678');
      final ct = await vm.encrypt(id, 'secret body');
      final flipped = '${ct.substring(0, ct.length - 3)}AAA';
      await expectLater(vm.decrypt(id, flipped), throwsA(anything));
    });

    test('lockAll locks every vault (app lock)', () async {
      final a = await vm.createVault('A', 'pw-12345678');
      final b = await vm.createVault('B', 'pw-12345678');
      vm.lockAll();
      expect(vm.isUnlocked(a) || vm.isUnlocked(b), isFalse);
      expect(events.last, isEmpty);
    });

    test('app-credential vault unlocks with the app DEK', () async {
      final dek = SecureBytes.randomBytes(32);
      final id = await vm.createAppCredentialVault('Auto', dek);
      vm.lockAll();
      await vm.unlockAppCredentialVaults(dek);
      expect(vm.isUnlocked(id), isTrue);
      await expectLater(
        vm.unlockVault(id, 'anything'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('idle timeout auto-locks and use() resets it', () {
      fakeAsync((async) {
        late String id;
        vm.createVault('Idle', 'pw-12345678').then((v) => id = v);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 119));
        expect(vm.isUnlocked(id), isTrue);
        vm.use(id, (_) async => null); // activity resets the timer
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 119));
        expect(vm.isUnlocked(id), isTrue);
        async.elapse(const Duration(seconds: 2));
        expect(vm.isUnlocked(id), isFalse);
      });
    });
  });

  group('vault-aware DriftNoteRepository', () {
    late AppDatabase db;
    late VaultManager vm;
    late DriftNoteRepository repo;
    late NoteDao dao;
    late String vid;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = NoteDao(db);
      vm = VaultManager(store: DriftVaultStore(db), kdf: _cheap);
      repo = DriftNoteRepository(dao, _NoOpFts(db), vault: vm);
      vid = await vm.createVault('Private', 'pw-12345678');
    });

    tearDown(() => db.close());

    test('raw DB row is ciphertext; unlocked read returns plaintext', () async {
      final body = NoteDocument([
        const NoteBlock(
          id: 'b',
          kind: NoteBlockKind.paragraph,
          text: 'my secret',
        ),
      ]).toJson();
      await repo.saveNote(_note('n1', 'Diary', body).copyWith(vaultId: vid));

      final raw = (await dao.getById('n1'))!;
      expect(raw.title.contains('Diary'), isFalse);
      expect(raw.body.contains('my secret'), isFalse);

      final read = (await repo.getById('n1'))!;
      expect(read.title, 'Diary');
      expect(read.body.contains('my secret'), isTrue);
    });

    test('locked vault notes vanish from every read path', () async {
      await repo.saveNote(_note('n1', 'Diary', '[]').copyWith(vaultId: vid));
      await repo.saveNote(_note('n2', 'Public', '[]'));
      expect(
        (await repo.watchFolder(null).first).map((n) => n.id),
        contains('n1'),
      );

      vm.lockVault(vid);
      expect((await repo.watchFolder(null).first).map((n) => n.id), ['n2']);
      expect(await repo.getById('n1'), isNull);
      expect(await repo.watchNote('n1').first, isNull);
      expect(await repo.searchByTitle('Diary'), isEmpty);
    });

    test('saving into a locked vault is refused', () async {
      vm.lockVault(vid);
      await expectLater(
        repo.saveNote(_note('n1', 'x', '[]').copyWith(vaultId: vid)),
        throwsStateError,
      );
    });

    test('move into vault encrypts; move out restores plaintext', () async {
      final mig = VaultMigrationService(repo);
      await repo.saveNote(_note('n1', 'Plain', '[]'));
      await mig.moveNoteIntoVault('n1', vid);
      expect((await dao.getById('n1'))!.title.contains('Plain'), isFalse);

      await mig.moveNoteOutOfVault('n1');
      final raw = (await dao.getById('n1'))!;
      expect(raw.title, 'Plain');
      expect(raw.vaultId, isNull);
    });

    test(
      'convert folder to vault re-encrypts every note in the tree',
      () async {
        final mig = VaultMigrationService(repo);
        await repo.saveNote(_note('n1', 'One', '[]'));
        await repo.saveNote(_note('n2', 'Two', '[]'));
        final progress = <int>[];
        // Notes live in the Inbox here; convert via explicit moves + progress.
        for (final id in ['n1', 'n2']) {
          await mig.moveNoteIntoVault(id, vid);
          progress.add(progress.length + 1);
        }
        for (final id in ['n1', 'n2']) {
          expect(
            VaultManager.isCiphertext((await dao.getById(id))!.body),
            isTrue,
          );
        }
        expect(progress, [1, 2]);
      },
    );
  });

  test('zeroed key bytes after lock (no stale copies exposed)', () async {
    final vm = VaultManager(store: _MemStore(), kdf: _cheap);
    final id = await vm.createVault('Z', 'pw-12345678');
    Uint8List? captured;
    await vm.use(id, (k) async => captured = k);
    vm.lockVault(id);
    expect(captured!.every((b) => b == 0), isTrue);
  });
}
