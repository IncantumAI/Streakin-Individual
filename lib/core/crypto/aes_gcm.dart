// lib/core/crypto/aes_gcm.dart
//
// AES-256-GCM wrapper using package:cryptography.
// Spec §8.1: 96-bit random nonce; per-object subkeys via HKDF.
// Nonce is prepended to ciphertext for storage.

import 'dart:typed_data';

import 'package:cryptography/dart.dart'; // pure-Dart backend — no platform channel
import 'package:cryptography/cryptography.dart';

import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';

/// AES-256-GCM encrypt/decrypt.
///
/// Storage format: [12-byte nonce][ciphertext + 16-byte GCM tag]
class AesGcm256 {
  AesGcm256._();

  static final _algo = DartAesGcm.with256bits(); // pure-Dart, safe in any isolate

  /// Encrypt [plaintext] with [keyBytes] (must be 32 bytes).
  /// Returns nonce+ciphertext concatenated.
  static Future<Uint8List> encrypt(
    Uint8List plaintext,
    Uint8List keyBytes, {
    List<int>? aad,
  }) async {
    assert(keyBytes.length == 32);
    final secretKey = SecretKeyData(keyBytes);
    final nonce = SecureBytes.randomBytes(12);
    final box = await _algo.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad ?? const [],
    );
    // Return: nonce (12) + ciphertext+tag
    final result = Uint8List(12 + box.cipherText.length + box.mac.bytes.length);
    result.setRange(0, 12, nonce);
    result.setRange(12, 12 + box.cipherText.length, box.cipherText);
    result.setRange(
      12 + box.cipherText.length,
      result.length,
      box.mac.bytes,
    );
    return result;
  }

  /// Decrypt a [nonceAndCiphertext] blob encrypted with [encrypt].
  /// Throws [CryptoFailure] on authentication failure.
  static Future<Uint8List> decrypt(
    Uint8List nonceAndCiphertext,
    Uint8List keyBytes, {
    List<int>? aad,
  }) async {
    assert(keyBytes.length == 32);
    if (nonceAndCiphertext.length < 12 + 16) {
      throw const CryptoFailure('Ciphertext too short');
    }
    final secretKey = SecretKeyData(keyBytes);
    final nonce = nonceAndCiphertext.sublist(0, 12);
    // Last 16 bytes are the GCM tag
    final ctLen = nonceAndCiphertext.length - 12 - 16;
    final cipherText = nonceAndCiphertext.sublist(12, 12 + ctLen);
    final mac = Mac(nonceAndCiphertext.sublist(12 + ctLen));

    try {
      final plaintext = await _algo.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
        aad: aad ?? const [],
      );
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError catch (_) {
      throw const CryptoFailure('AEAD authentication failed — wrong key or tampered data');
    } catch (e) {
      throw CryptoFailure('Decryption error: $e');
    }
  }
}
