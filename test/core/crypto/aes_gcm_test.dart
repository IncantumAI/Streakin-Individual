// test/core/crypto/aes_gcm_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';

void main() {
  group('AesGcm256', () {
    final key = SecureBytes.randomBytes(32);

    test('encrypt/decrypt round-trip', () async {
      final plaintext = Uint8List.fromList([72, 101, 108, 108, 111]);
      final ct = await AesGcm256.encrypt(plaintext, key);
      final dt = await AesGcm256.decrypt(ct, key);
      expect(dt, plaintext);
    });

    test('wrong key throws CryptoFailure', () async {
      final ct = await AesGcm256.encrypt(Uint8List.fromList([1, 2, 3, 4]), key);
      final wrongKey = SecureBytes.randomBytes(32);
      expect(
        () => AesGcm256.decrypt(ct, wrongKey),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test('bit-flip in ciphertext throws CryptoFailure', () async {
      final ct = await AesGcm256.encrypt(
        Uint8List.fromList([1, 2, 3, 4, 5]),
        key,
      );
      ct[15] ^= 0x01;
      expect(() => AesGcm256.decrypt(ct, key), throwsA(isA<CryptoFailure>()));
    });

    test('truncated ciphertext throws CryptoFailure', () {
      expect(
        () => AesGcm256.decrypt(
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
          key,
        ),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test('AAD mismatch throws CryptoFailure', () async {
      final ct = await AesGcm256.encrypt(
        Uint8List.fromList([1, 2, 3]),
        key,
        aad: [0x01],
      );
      expect(
        () => AesGcm256.decrypt(ct, key, aad: [0x02]),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test('nonces are unique (100 encryptions)', () async {
      final nonces = <String>{};
      for (int i = 0; i < 100; i++) {
        final ct = await AesGcm256.encrypt(Uint8List.fromList([i]), key);
        final nonce = SecureBytes.toHex(ct.sublist(0, 12));
        expect(
          nonces.contains(nonce),
          isFalse,
          reason: 'Duplicate nonce at i=$i',
        );
        nonces.add(nonce);
      }
    });
  });
}
