// test/core/crypto/secure_bytes_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';

void main() {
  group('SecureBytes', () {
    test('zeroFill clears all bytes', () {
      final data = SecureBytes.randomBytes(32);
      for (int i = 0; i < data.length; i++) {
        data[i] = 0xFF;
      }
      SecureBytes.zeroFill(data);
      expect(data.every((b) => b == 0), isTrue);
    });

    test('constantTimeEqual returns true for equal arrays', () {
      final a = SecureBytes.randomBytes(32);
      final b = Uint8List.fromList(a);
      expect(SecureBytes.constantTimeEqual(a, b), isTrue);
    });

    test('constantTimeEqual returns false for different arrays', () {
      final a = SecureBytes.randomBytes(32);
      final b = SecureBytes.randomBytes(32);
      expect(SecureBytes.constantTimeEqual(a, b), isFalse);
    });

    test('constantTimeEqual returns false for different lengths', () {
      final a = SecureBytes.randomBytes(32);
      final b = SecureBytes.randomBytes(16);
      expect(SecureBytes.constantTimeEqual(a, b), isFalse);
    });

    test('randomBytes generates non-zero bytes (statistical)', () {
      final bytes = SecureBytes.randomBytes(256);
      expect(bytes.every((b) => b == 0), isFalse);
    });

    test('toHex / fromHex round-trip', () {
      final original = SecureBytes.randomBytes(16);
      final hex = SecureBytes.toHex(original);
      final recovered = SecureBytes.fromHex(hex);
      expect(SecureBytes.constantTimeEqual(original, recovered), isTrue);
    });
  });
}
