// Track 6A/6B: container format, three key modes, tamper detection.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:streakin/core/crypto/base32.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/data/ncx_reader.dart';
import 'package:streakin/features/sharing/data/ncx_writer.dart';
import 'package:streakin/features/sharing/domain/ncx_container.dart';

const _cheap = NcxKdf(ops: 1, memKiB: 8);

Map<String, Uint8List> _entries() => {
  'manifest.json': Uint8List.fromList(utf8.encode('{"format":1,"n":3}')),
  'records.ndjson': Uint8List.fromList(utf8.encode('{"t":"habits","r":{}}\n')),
  'attachments/a1': Uint8List.fromList(List.generate(200000, (i) => i % 251)),
};

void main() {
  late DeviceIdentity alice;
  late DeviceIdentity bob;

  setUp(() async {
    alice = await DeviceIdentity.fromSeed(SecureBytes.randomBytes(32));
    bob = await DeviceIdentity.fromSeed(SecureBytes.randomBytes(32));
  });

  test('magic bytes constant is NCX1 (guard against brand-rename changes)', () {
    expect(kNcxMagic, [0x4E, 0x43, 0x58, 0x31]);
    expect(String.fromCharCodes(kNcxMagic), 'NCX1');
  });

  test('passphrase round trip → manifest matches', () async {
    final bytes = await NcxWriter.build(
      scheme: NcxScheme.pass,
      entries: _entries(),
      identity: alice,
      senderName: 'A',
      passphrase: 'correct horse',
      kdf: _cheap,
    );
    final p = await NcxReader.open(bytes, passphrase: 'correct horse');
    expect(p.manifest['n'], 3);
    expect(p.entries['attachments/a1']!.length, 200000);
    expect(p.entries['attachments/a1']!.first, 0);
  });

  test('wrong passphrase → CryptoFailure', () async {
    final bytes = await NcxWriter.build(
      scheme: NcxScheme.pass,
      entries: _entries(),
      identity: alice,
      senderName: 'A',
      passphrase: 'right-pass',
      kdf: _cheap,
    );
    await expectLater(
      NcxReader.open(bytes, passphrase: 'wrong-pass'),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test('1-bit flip anywhere in the payload is rejected', () async {
    final bytes = await NcxWriter.build(
      scheme: NcxScheme.pass,
      entries: _entries(),
      identity: alice,
      senderName: 'A',
      passphrase: 'right-pass',
      kdf: _cheap,
    );
    final tampered = Uint8List.fromList(bytes);
    tampered[tampered.length ~/ 2] ^= 0x01;
    await expectLater(
      NcxReader.open(tampered, passphrase: 'right-pass'),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test(
    'modifying the cleartext header after writing fails authentication',
    () async {
      final bytes = await NcxWriter.build(
        scheme: NcxScheme.pass,
        entries: _entries(),
        identity: alice,
        senderName: 'Alice',
        passphrase: 'right-pass',
        kdf: _cheap,
      );
      final env = parseEnvelope(bytes);
      final s = utf8.decode(env.headerBytes).replaceFirst('Alice', 'Mallo');
      final newHeader = Uint8List.fromList(utf8.encode(s));
      final forged = serializeEnvelope(
        NcxEnvelope(
          header: env.header,
          headerBytes: newHeader,
          wrappedKey: env.wrappedKey,
          chunks: env.chunks,
          signature: env.signature,
        ),
      );
      await expectLater(
        NcxReader.open(forged, passphrase: 'right-pass'),
        throwsA(isA<CryptoFailure>()),
      );
    },
  );

  test('truncating chunks is rejected', () async {
    final bytes = await NcxWriter.build(
      scheme: NcxScheme.pass,
      entries: _entries(),
      identity: alice,
      senderName: 'A',
      passphrase: 'right-pass',
      kdf: _cheap,
    );
    final env = parseEnvelope(bytes);
    expect(env.chunks.length, greaterThan(1));
    final cut = serializeEnvelope(
      NcxEnvelope(
        header: env.header,
        headerBytes: env.headerBytes,
        wrappedKey: env.wrappedKey,
        chunks: env.chunks.sublist(0, env.chunks.length - 1),
        signature: env.signature,
      ),
    );
    await expectLater(
      NcxReader.open(cut, passphrase: 'right-pass'),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test('garbage input is not a valid share file', () {
    expect(
      () => parseEnvelope(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test('pairing: SAS is identical on both devices', () async {
    final a = await alice.sharedSecret(bob.public.x25519);
    final b = await bob.sharedSecret(alice.public.x25519);
    expect(DeviceIdentity.sasFor(a), DeviceIdentity.sasFor(b));
    expect(DeviceIdentity.sasFor(a), matches(RegExp(r'^\d{6}$')));
  });

  test(
    'pair mode: export → import on the paired device; sender verified',
    () async {
      final bytes = await NcxWriter.build(
        scheme: NcxScheme.pair,
        entries: _entries(),
        identity: alice,
        senderName: 'Alice',
        recipient: bob.public,
      );
      final p = await NcxReader.open(
        bytes,
        identity: bob,
        expectedSender: alice.public,
      );
      expect(p.manifest['n'], 3);
    },
  );

  test('pair mode: 1-bit tamper → rejected', () async {
    final bytes = await NcxWriter.build(
      scheme: NcxScheme.pair,
      entries: _entries(),
      identity: alice,
      senderName: 'Alice',
      recipient: bob.public,
    );
    final t = Uint8List.fromList(bytes);
    t[t.length - 100] ^= 0x80;
    await expectLater(
      NcxReader.open(t, identity: bob, expectedSender: alice.public),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test('pair mode: a third device cannot open it', () async {
    final carol = await DeviceIdentity.fromSeed(SecureBytes.randomBytes(32));
    final bytes = await NcxWriter.build(
      scheme: NcxScheme.pair,
      entries: _entries(),
      identity: alice,
      senderName: 'Alice',
      recipient: bob.public,
    );
    await expectLater(
      NcxReader.open(bytes, identity: carol),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test(
    'pair mode: wrong expected sender → rejected (signature check)',
    () async {
      final bytes = await NcxWriter.build(
        scheme: NcxScheme.pair,
        entries: _entries(),
        identity: alice,
        senderName: 'Alice',
        recipient: bob.public,
      );
      final mallory = await DeviceIdentity.fromSeed(
        SecureBytes.randomBytes(32),
      );
      await expectLater(
        NcxReader.open(bytes, identity: bob, expectedSender: mallory.public),
        throwsA(isA<CryptoFailure>()),
      );
    },
  );

  test('raw key mode: right key opens, wrong key fails', () async {
    final key = SecureBytes.randomBytes(32);
    final bytes = await NcxWriter.build(
      scheme: NcxScheme.key,
      entries: _entries(),
      identity: alice,
      senderName: 'A',
      rawKey: key,
    );
    final p = await NcxReader.open(bytes, rawKey: key);
    expect(p.manifest['n'], 3);
    await expectLater(
      NcxReader.open(bytes, rawKey: SecureBytes.randomBytes(32)),
      throwsA(isA<CryptoFailure>()),
    );
  });

  test('Base32 round trip and grouping', () {
    final raw = SecureBytes.randomBytes(32);
    final s = Base32.encode(raw);
    expect(Base32.decode(Base32.grouped(s)), raw);
  });

  test('device identity is deterministic from its seed', () async {
    final seed = SecureBytes.randomBytes(32);
    final a = await DeviceIdentity.fromSeed(seed);
    final b = await DeviceIdentity.fromSeed(seed);
    expect(a.public.base32, b.public.base32);
    expect(
      DevicePublicBundle.parse(a.public.base32).fingerprint,
      a.public.fingerprint,
    );
  });
}
