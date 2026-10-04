// test/core/security/key_vault_test.dart
// Spec §11.2: KeyVault.isEmpty == true after dispose; key zeroed.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/security/key_vault.dart';

void main() {
  group('KeyVault', () {
    test('isEmpty is true before load', () {
      final vault = KeyVault();
      expect(vault.isEmpty, isTrue);
      expect(vault.isUnlocked, isFalse);
    });

    test('isEmpty is false after load', () {
      final vault = KeyVault();
      vault.load(SecureBytes.randomBytes(32));
      expect(vault.isEmpty, isFalse);
      expect(vault.isUnlocked, isTrue);
    });

    test('isEmpty is true after dispose', () {
      final vault = KeyVault();
      vault.load(SecureBytes.randomBytes(32));
      vault.dispose();
      expect(vault.isEmpty, isTrue);
    });

    test('use() provides key bytes', () async {
      final vault = KeyVault();
      final key = SecureBytes.randomBytes(32);
      vault.load(key);
      await vault.use((k) async {
        expect(k.length, 32);
      });
    });

    test('use() throws AuthFailure when locked', () {
      final vault = KeyVault();
      expect(
        () => vault.use((_) async => null),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('useSync() throws AuthFailure when locked', () {
      final vault = KeyVault();
      expect(
        () => vault.useSync((_) => null),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('dispose is idempotent (safe to call twice)', () {
      final vault = KeyVault();
      vault.load(SecureBytes.randomBytes(32));
      vault.dispose();
      expect(vault.dispose, returnsNormally);
      expect(vault.isEmpty, isTrue);
    });
  });
}
