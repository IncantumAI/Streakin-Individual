// lib/features/sharing/data/ncx_reader.dart
// Reads a share container: authenticates the header, unwraps the content key
// for the given mode, verifies the Ed25519 signature (pair / raw-key) and
// decrypts the payload. Any failure → CryptoFailure("tampered or corrupted").

import 'dart:io';
import 'dart:typed_data';

import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/data/ncx_writer.dart';
import 'package:streakin/features/sharing/domain/ncx_container.dart';

const String kTamperedMessage =
    'This file has been tampered with or is corrupted.';

class NcxReader {
  NcxReader._();

  static Future<Uint8List> readFile(String path) => File(path).readAsBytes();

  /// Header only — no secrets needed. Used by the UI to pick the right
  /// prompt (passphrase / paired device / raw key).
  static NcxHeader peekHeader(Uint8List bytes) => parseEnvelope(bytes).header;

  /// Decrypts [bytes].
  ///
  /// * pass: [passphrase]
  /// * pair: [identity] (recipient) and [expectedSender] (the paired peer;
  ///   the signature must come from its Ed25519 key)
  /// * key : [rawKey] and, optionally, [expectedSender]
  static Future<NcxPayload> open(
    Uint8List bytes, {
    String? passphrase,
    DeviceIdentity? identity,
    DevicePublicBundle? expectedSender,
    Uint8List? rawKey,
  }) async {
    final env = parseEnvelope(bytes); // CryptoFailure if malformed
    final h = env.header;

    late Uint8List kek;
    switch (h.scheme) {
      case NcxScheme.pass:
        if (passphrase == null || h.kdf == null) {
          throw const CryptoFailure('Passphrase required');
        }
        kek = await deriveKek(passphrase, h.kdf!);
      case NcxScheme.pair:
        if (identity == null || h.ephemeralPub == null) {
          throw const CryptoFailure('Pairing required');
        }
        if (h.recipientFingerprint != identity.public.fingerprint) {
          throw const CryptoFailure(
            'This file was made for a different device',
          );
        }
        kek = pairKek(
          await identity.sharedSecret(SecureBytes.fromHex(h.ephemeralPub!)),
        );
      case NcxScheme.key:
        if (rawKey == null) throw const CryptoFailure('Key required');
        kek = rawKeyKek(rawKey);
    }

    final Uint8List ck;
    try {
      ck = await AesGcm256.decrypt(env.wrappedKey, kek, aad: env.headerBytes);
    } on CryptoFailure {
      // Wrong passphrase/key, or the header was modified after writing.
      throw CryptoFailure(
        h.scheme == NcxScheme.pass
            ? 'Wrong passphrase, or $kTamperedMessage'
            : kTamperedMessage,
      );
    } finally {
      SecureBytes.zeroFill(kek);
    }

    final Uint8List plain;
    try {
      plain = await decryptChunks(env.chunks, ck, env.headerBytes);
    } on CryptoFailure {
      throw const CryptoFailure(kTamperedMessage);
    } finally {
      SecureBytes.zeroFill(ck);
    }
    final entries = unpackArchive(plain);
    final payload = NcxPayload(entries);

    if (h.scheme != NcxScheme.pass) {
      final signer = h.signerPub;
      if (signer == null || env.signature.isEmpty) {
        throw const CryptoFailure(kTamperedMessage);
      }
      final signerBytes = SecureBytes.fromHex(signer);
      if (expectedSender != null &&
          !SecureBytes.constantTimeEqual(signerBytes, expectedSender.ed25519)) {
        throw const CryptoFailure('This file is not from the expected device');
      }
      final ok = await DeviceIdentity.verify(
        signedMessage(env.headerBytes, env.wrappedKey, payload.manifestBytes),
        env.signature,
        signerBytes,
      );
      if (!ok) throw const CryptoFailure(kTamperedMessage);
    }
    return payload;
  }
}
