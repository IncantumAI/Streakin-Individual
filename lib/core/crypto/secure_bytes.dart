// lib/core/crypto/secure_bytes.dart
//
// Spec §11.1: keys are Uint8List only; zeroFill in finally blocks; constantTimeEqual.

import 'dart:math';
import 'dart:typed_data';

class SecureBytes {
  SecureBytes._();

  /// Zero all bytes in [data]. Call in finally blocks after using key material.
  static void zeroFill(Uint8List data) {
    for (int i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }

  /// Constant-time equality comparison. Returns true if [a] and [b] are equal.
  /// Never short-circuits — safe against timing attacks on HMAC / tag comparisons.
  static bool constantTimeEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Generate [length] cryptographically random bytes using OS CSPRNG.
  static Uint8List randomBytes(int length) {
    final rng = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  /// Convert a byte array to lowercase hex string.
  static String toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Convert a lowercase hex string to bytes.
  static Uint8List fromHex(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
