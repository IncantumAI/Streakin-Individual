// Track 6C/6D: export → import between two in-memory databases, merge rules,
// preview, tombstones, conflict copies, vault ciphertext, rollback, tamper.

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/features/sharing/application/export_service.dart';
import 'package:streakin/features/sharing/application/import_service.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/data/ncx_writer.dart';
import 'package:streakin/features/sharing/data/sync_peer_store.dart';
import 'package:streakin/features/sharing/domain/ncx_container.dart';

const _cheap = NcxKdf(ops: 1, memKiB: 8);

String hlc(int ms, [int c = 0]) =>
    '$ms-${c.toRadixString(16).padLeft(4, '0')}-0001';

Future<void> addHabit(
  AppDatabase db,
  String id,
  String name,
  String h, {
  String? deleted,
}) => db
    .into(db.habits)
    .insertOnConflictUpdate(
      HabitsCompanion.insert(
        id: id,
        name: name,
        startDate: '2026-01-01',
        hlc: h,
        deletedAt: Value(deleted),
      ),
    );

Future<void> addNote(
  AppDatabase db,
  String id,
  String title,
  String body,
  String h, {
  String? vault,
}) => db
    .into(db.notes)
    .insertOnConflictUpdate(
      NotesCompanion.insert(
        id: id,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        hlc: h,
        title: Value(title),
        body: Value(body),
        vaultId: Value(vault),
      ),
    );

void main() {
  late AppDatabase a;
  late AppDatabase b;
  late DeviceIdentity idA;
  late DeviceIdentity idB;
  late ExportService exportA;
  late ImportService importB;

  ExportService exporter(
    AppDatabase db,
    DeviceIdentity id, {
    bool Function(String)? unlocked,
  }) => ExportService(
    db: db,
    identity: id,
    peers: SyncPeerStore(db),
    isVaultUnlocked: unlocked ?? (_) => false,
    loadAttachmentPlain: (_) async => null,
    deviceName: 'Device A',
    kdf: _cheap,
  );

  ImportService importer(
    AppDatabase db,
    DeviceIdentity id, {
    Future<void> Function(Set<String>)? onApplied,
  }) => ImportService(
    db: db,
    identity: id,
    peers: SyncPeerStore(db),
    saveAttachment: (_, _) async {},
    onApplied: onApplied,
  );

  setUp(() async {
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    idA = await DeviceIdentity.fromSeed(SecureBytes.randomBytes(32));
    idB = await DeviceIdentity.fromSeed(SecureBytes.randomBytes(32));
    exportA = exporter(a, idA);
    importB = importer(b, idB);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<ImportSession> transfer({String pass = 'a-good-pass'}) async {
    final r = await exportA.export(scheme: NcxScheme.pass, passphrase: pass);
    return importB.open(r.bytes, passphrase: pass);
  }

  test('full export imports into a clean instance: data equal', () async {
    await addHabit(a, 'h1', 'Read', hlc(1000));
    await addNote(a, 'n1', 'Hello', '[]', hlc(1000));
    final s = await transfer();
    final pv = await importB.preview(s);
    expect(pv.newCount, 2);
    // Preview must not have written anything.
    expect(await b.select(b.habits).get(), isEmpty);

    await importB.apply(s);
    expect((await b.select(b.habits).get()).single.name, 'Read');
    expect((await b.select(b.notes).get()).single.title, 'Hello');
  });

  test('last-writer-wins for habits; older incoming is ignored', () async {
    await addHabit(b, 'h1', 'Local newer', hlc(5000));
    await addHabit(a, 'h1', 'Remote older', hlc(1000));
    await importB.apply(await transfer());
    expect((await b.select(b.habits).get()).single.name, 'Local newer');

    await addHabit(a, 'h1', 'Remote newest', hlc(9000));
    await importB.apply(await transfer());
    expect((await b.select(b.habits).get()).single.name, 'Remote newest');
  });

  test(
    'tombstone on sender soft-deletes locally and counts as deleted',
    () async {
      await addHabit(b, 'h1', 'Read', hlc(1000));
      await addHabit(a, 'h1', 'Read', hlc(2000), deleted: '2026-02-01');
      final s = await transfer();
      expect((await importB.preview(s)).deletedCount, 1);
      await importB.apply(s);
      expect((await b.select(b.habits).get()).single.deletedAt, isNotNull);
    },
  );

  test('both sides edited a note since last sync → conflict copy', () async {
    // Paired devices with a recorded last-sync point.
    final peers = SyncPeerStore(b);
    await peers.add(idA.public, 'Device A');
    await peers.setLastRecv(idA.public.fingerprint, hlc(1000));

    await addNote(b, 'n1', 'Plan', '[{"b":"local edit"}]', hlc(3000));
    await addNote(a, 'n1', 'Plan', '[{"b":"remote edit"}]', hlc(4000));

    final r = await exporter(a, idA).export(
      scheme: NcxScheme.pair,
      peer: await SyncPeerStore(a).add(idB.public, 'Device B'),
    );
    final s = await importB.open(r.bytes);
    expect((await importB.preview(s)).conflictCount, 1);
    await importB.apply(s);

    final notes = await b.select(b.notes).get();
    expect(notes.length, 2);
    expect(notes.where((n) => n.title.startsWith('Plan (conflict')).length, 1);
    expect(notes.firstWhere((n) => n.id == 'n1').body, contains('remote edit'));
  });

  test(
    'delta export contains only newer records and updates lastSentHlc',
    () async {
      final peerOnA = await SyncPeerStore(a).add(idB.public, 'Device B');
      await addHabit(a, 'old', 'Old', hlc(1000));
      await addHabit(a, 'new', 'New', hlc(9000));
      await SyncPeerStore(a).setLastSent(peerOnA.deviceId, hlc(5000));
      final fresh = (await SyncPeerStore(a).byDeviceId(peerOnA.deviceId))!;

      final r = await exportA.export(
        scheme: NcxScheme.pair,
        scope: NcxScope.delta,
        peer: fresh,
      );
      await SyncPeerStore(b).add(idA.public, 'Device A');
      final s = await importer(b, idB).open(r.bytes);
      expect(s.records.tables['habits']!.map((h) => h['id']), ['new']);
      final after = (await SyncPeerStore(a).byDeviceId(peerOnA.deviceId))!;
      expect(after.lastSentHlc, hlc(9000));
    },
  );

  test(
    'vault notes travel as ciphertext only when the vault is unlocked',
    () async {
      await addNote(
        a,
        'v1',
        'vlt1:AAAA',
        'vlt1:BBBB',
        hlc(1000),
        vault: 'vault1',
      );
      await a
          .into(a.vaults)
          .insert(
            VaultsCompanion.insert(
              id: 'vault1',
              name: 'Priv',
              kdfParams: '{}',
              wrappedVaultKey: 'ab',
            ),
          );

      final locked = await exporter(
        a,
        idA,
      ).export(scheme: NcxScheme.pass, passphrase: 'a-good-pass');
      expect(locked.excludedLockedVaults, ['vault1']);
      final s1 = await importB.open(locked.bytes, passphrase: 'a-good-pass');
      expect(s1.records.tables['notes'] ?? const [], isEmpty);

      final open = await exporter(
        a,
        idA,
        unlocked: (_) => true,
      ).export(scheme: NcxScheme.pass, passphrase: 'a-good-pass');
      final s2 = await importB.open(open.bytes, passphrase: 'a-good-pass');
      expect(s2.records.tables['notes']!.single['body'], 'vlt1:BBBB');
      expect(s2.records.tables['vaults'], isNotEmpty);
    },
  );

  test('tampered file is refused', () async {
    await addHabit(a, 'h1', 'Read', hlc(1000));
    final r = await exportA.export(
      scheme: NcxScheme.pass,
      passphrase: 'a-good-pass',
    );
    final t = Uint8List.fromList(r.bytes);
    t[t.length ~/ 2] ^= 1;
    await expectLater(
      importB.open(t, passphrase: 'a-good-pass'),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test('failure mid-import leaves no partial data (rollback)', () async {
    await addHabit(a, 'h1', 'Read', hlc(1000));
    await addNote(a, 'n1', 'Hello', '[]', hlc(1000));
    final s = await transfer();
    // Corrupt one incoming row so the transaction fails after habits applied.
    s.records.tables['notes']!.single['createdAt'] = null;
    await expectLater(importB.apply(s), throwsA(anything));
    expect(await b.select(b.habits).get(), isEmpty);
    expect(await b.select(b.notes).get(), isEmpty);
  });

  test(
    'onApplied is called with the written note ids (reconcile hook)',
    () async {
      await addNote(a, 'n1', 'Hello', '[]', hlc(1000));
      Set<String>? seen;
      final imp = importer(b, idB, onApplied: (ids) async => seen = ids);
      final r = await exportA.export(
        scheme: NcxScheme.pass,
        passphrase: 'a-good-pass',
      );
      await imp.apply(await imp.open(r.bytes, passphrase: 'a-good-pass'));
      expect(seen, {'n1'});
    },
  );

  test('newer-schema file is refused', () async {
    final r = await exportA.export(
      scheme: NcxScheme.pass,
      passphrase: 'a-good-pass',
    );
    final s = await importB.open(r.bytes, passphrase: 'a-good-pass');
    s.payload.entries['manifest.json'] = Uint8List.fromList(
      '{"schemaVer": 999}'.codeUnits,
    );
    await expectLater(importB.apply(s), throwsA(isA<ValidationFailure>()));
  });
}
