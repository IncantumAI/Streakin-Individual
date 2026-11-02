// lib/features/sharing/data/ncx_writer.dart
// Builds an encrypted share container for one of the three key modes.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/crypto/hkdf.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/domain/ncx_container.dart';

/// Argon2id cost for passphrase sharing (tests use cheap values).
class NcxKdf {
  const NcxKdf({this.ops = 3, this.memKiB = 64 * 1024, this.parallelism = 1});
  final int ops;
  final int memKiB;
  final int parallelism;
}

Future<Uint8List> deriveKek(String passphrase, Map<String, dynamic> kdf) async {
  final argon = DartArgon2id(
    parallelism: kdf['p'] as int,
    memory: kdf['mem'] as int,
    iterations: kdf['ops'] as int,
    hashLength: 32,
  );
  final k = await argon.deriveKeyFromPassword(
    password: passphrase,
    nonce: SecureBytes.fromHex(kdf['salt'] as String),
  );
  return Uint8List.fromList(await k.extractBytes());
}

Uint8List rawKeyKek(Uint8List raw) => HkdfDerive.deriveSync(raw, 'ncx-raw');
Uint8List pairKek(Uint8List sharedSecret) =>
    HkdfDerive.deriveSync(sharedSecret, 'ncx-pair');

class NcxWriter {
  NcxWriter._();

  /// Builds the container bytes.
  ///
  /// [entries] must contain `manifest.json`. For pair / raw-key modes pass the
  /// sender's [identity] so the file is signed.
  static Future<Uint8List> build({
    required NcxScheme scheme,
    required Map<String, Uint8List> entries,
    required DeviceIdentity identity,
    required String senderName,
    NcxScope scope = NcxScope.full,
    String? sinceHlc,
    String? passphrase,
    NcxKdf kdf = const NcxKdf(),
    DevicePublicBundle? recipient,
    Uint8List? rawKey,
    DateTime? now,
  }) async {
    // 1 — Key-encryption key + the header fields it needs.
    late Uint8List kek;
    Map<String, dynamic>? kdfParams;
    String? ephPub;
    String? recipientFp;
    switch (scheme) {
      case NcxScheme.pass:
        if (passphrase == null) throw ArgumentError('passphrase required');
        kdfParams = {
          'alg': 'argon2id',
          'ops': kdf.ops,
          'mem': kdf.memKiB,
          'p': kdf.parallelism,
          'salt': SecureBytes.toHex(SecureBytes.randomBytes(16)),
        };
        kek = await deriveKek(passphrase, kdfParams);
      case NcxScheme.pair:
        if (recipient == null) throw ArgumentError('recipient required');
        final eph = await EphemeralKeys.generate();
        kek = pairKek(await eph.sharedWith(recipient.x25519));
        ephPub = SecureBytes.toHex(eph.publicBytes);
        recipientFp = recipient.fingerprint;
      case NcxScheme.key:
        if (rawKey == null) throw ArgumentError('rawKey required');
        kek = rawKeyKek(rawKey);
    }

    final header = NcxHeader(
      scheme: scheme,
      senderDeviceId: identity.deviceId,
      senderName: senderName,
      createdAt: (now ?? DateTime.now().toUtc()).toIso8601String(),
      scope: scope,
      sinceHlc: sinceHlc,
      kdf: kdfParams,
      recipientFingerprint: recipientFp,
      ephemeralPub: ephPub,
      signerPub: scheme == NcxScheme.pass
          ? null
          : SecureBytes.toHex(identity.public.ed25519),
    );
    final headerBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(header.toJson())),
    );

    // 2 — Random content key, wrapped under the KEK (header is AAD).
    final ck = SecureBytes.randomBytes(32);
    final wrapped = await AesGcm256.encrypt(ck, kek, aad: headerBytes);
    SecureBytes.zeroFill(kek);

    // 3 — Chunked payload.
    final chunks = await encryptChunks(packArchive(entries), ck, headerBytes);
    SecureBytes.zeroFill(ck);

    // 4 — Signature (pair / raw-key).
    var sig = Uint8List(0);
    if (scheme != NcxScheme.pass) {
      sig = await identity.sign(
        signedMessage(
          headerBytes,
          wrapped,
          entries['manifest.json'] ?? Uint8List(0),
        ),
      );
    }

    return serializeEnvelope(
      NcxEnvelope(
        header: header,
        headerBytes: headerBytes,
        wrappedKey: wrapped,
        chunks: chunks,
        signature: sig,
      ),
    );
  }

  static Future<void> writeFile(String path, Uint8List bytes) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }
}
