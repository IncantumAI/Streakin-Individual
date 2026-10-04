// lib/core/security/key_vault.dart
//
// KeyVault — the single owner of all live key material.
// Spec §11.1: a single KeyVault service owns all key material;
// everything else asks it to use(key => …) in a scoped callback.

import 'dart:typed_data';

import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';

/// Holds the DEK (Data Encryption Key) as raw bytes while unlocked.
/// Exposes only a scoped callback API — key bytes never leave this class.
///
/// Lives in SessionScope so it is automatically disposed on lock.
class KeyVault {
  Uint8List? _dek;

  /// True when the vault holds no key (locked state).
  bool get isEmpty => _dek == null;

  /// True when the vault holds the DEK (unlocked state).
  bool get isUnlocked => _dek != null;

  /// Load the DEK. Call only from the unlock sequence.
  void load(Uint8List dek) {
    assert(dek.length == 32, 'DEK must be 32 bytes');
    _dek = Uint8List.fromList(dek); // defensive copy
  }

  /// Execute [callback] with the raw DEK bytes.
  /// The bytes must not be stored beyond the callback scope.
  Future<T> use<T>(Future<T> Function(Uint8List key) callback) async {
    if (_dek == null) throw const AuthFailure('KeyVault is locked');
    return callback(_dek!);
  }

  /// Synchronous variant for non-async consumers.
  T useSync<T>(T Function(Uint8List key) callback) {
    if (_dek == null) throw const AuthFailure('KeyVault is locked');
    return callback(_dek!);
  }

  /// Zero and drop the DEK. Called as part of the lock sequence.
  void dispose() {
    if (_dek != null) {
      SecureBytes.zeroFill(_dek!);
      _dek = null;
    }
  }
}
