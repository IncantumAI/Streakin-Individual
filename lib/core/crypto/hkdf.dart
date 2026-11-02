// lib/core/crypto/hkdf.dart
//
// HKDF-SHA-256 implemented directly using package:crypto (pure Dart).
// Does NOT use package:cryptography or package:cryptography_flutter —
// those route through FlutterHmac on Android (platform channel) even when
// using the "Dart" backend class names.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:streakin/core/storage/identifiers.dart';

class HkdfDerive {
  HkdfDerive._();

  // HKDF-Extract: PRK = HMAC-SHA256(salt, ikm)
  static Uint8List _extract(List<int> salt, List<int> ikm) {
    final hmac = Hmac(sha256, salt);
    final digest = hmac.convert(ikm);
    return Uint8List.fromList(digest.bytes);
  }

  // HKDF-Expand: OKM = T(1) || T(2) || ... where T(i) = HMAC-SHA256(PRK, T(i-1) || info || i)
  static Uint8List _expand(Uint8List prk, List<int> info, int length) {
    final okm = <int>[];
    var t = <int>[];
    int counter = 1;
    while (okm.length < length) {
      final hmac = Hmac(sha256, prk);
      final input = [...t, ...info, counter];
      t = hmac.convert(input).bytes;
      okm.addAll(t);
      counter++;
    }
    return Uint8List.fromList(okm.sublist(0, length));
  }

  /// Derive a 32-byte subkey from [inputKeyMaterial] with [label] as info.
  static Uint8List deriveSync(Uint8List inputKeyMaterial, String label) {
    // Use empty salt (spec default: zeroes of hash length)
    final salt = List<int>.filled(32, 0);
    final prk = _extract(salt, inputKeyMaterial);
    return _expand(prk, label.codeUnits, 32);
  }

  /// Derive the SQLCipher raw key (domain label: "db").
  static Future<Uint8List> deriveDbKey(Uint8List dek) async =>
      deriveSync(dek, AppIdentifiers.hkdfLabelDb);

  /// Derive an attachment encryption key (domain label: "attach").
  static Future<Uint8List> deriveAttachKey(Uint8List dek) async =>
      deriveSync(dek, AppIdentifiers.hkdfLabelAttach);

  /// Derive a vault key encryption key (domain label: "vault").
  static Future<Uint8List> deriveVaultKey(Uint8List dek) async =>
      deriveSync(dek, AppIdentifiers.hkdfLabelVault);

  /// Derive a sharing / export key (domain label: "share").
  static Future<Uint8List> deriveShareKey(Uint8List dek) async =>
      deriveSync(dek, AppIdentifiers.hkdfLabelShare);
}
