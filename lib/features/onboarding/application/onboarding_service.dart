// lib/features/onboarding/application/onboarding_service.dart
// Argon2id via package:cryptography (pure Dart, no native build hooks needed).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart'; // pure-Dart — no platform channel
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/storage/identifiers.dart';

final onboardingServiceProvider = Provider(OnboardingService.new);

class OnboardingService {
  OnboardingService(this._ref);
  // ignore: unused_field
  final Ref _ref;

  // Argon2id parameters — match spec §3.2
  static const int _opsLimit = 3; // iterations
  static const int _memLimit =
      64 * 1024; // 64 MiB in KiB (cryptography uses KiB)
  static const int _parallelism = 1;
  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  Argon2id get _argon2id => const DartArgon2id(
    parallelism: _parallelism,
    memory: _memLimit,
    iterations: _opsLimit,
    hashLength: _keyBytes,
  );

  Future<Uint8List> _deriveKey(String password, Uint8List salt) async {
    final secretKey = await _argon2id.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  // ── Password setup ────────────────────────────────────────────────────────

  Future<Uint8List> setupPassword(String password) async {
    final salt = SecureBytes.randomBytes(_saltBytes);

    final kekPw = await _deriveKey(password, salt);

    final dek = SecureBytes.randomBytes(_keyBytes);
    final dekWrappedPw = await AesGcm256.encrypt(dek, kekPw);
    SecureBytes.zeroFill(kekPw);

    final recoveryKey = SecureBytes.randomBytes(_keyBytes);
    final kekRk = _deriveKek(recoveryKey, 'recovery_kek');
    final dekWrappedRk = await AesGcm256.encrypt(dek, kekRk);
    SecureBytes.zeroFill(kekRk);

    await _writeKeyring(
      kdfParams: {
        'alg': 'argon2id',
        'ops': _opsLimit,
        'mem': _memLimit,
        'parallelism': _parallelism,
        'salt': SecureBytes.toHex(salt),
      },
      dekWrappedPw: dekWrappedPw,
      dekWrappedRk: dekWrappedRk,
    );

    SecureBytes.zeroFill(dek);
    return recoveryKey;
  }

  Future<Uint8List> unlockWithPassword(String password) async {
    final keyring = await _readKeyring();

    final params = keyring['kdf_params'] as Map<String, dynamic>;
    final salt = SecureBytes.fromHex(params['salt'] as String);

    final kekPw = await _deriveKey(password, salt);

    try {
      final wrapped = SecureBytes.fromHex(keyring['dek_pw'] as String);
      final dek = await AesGcm256.decrypt(wrapped, kekPw);
      SecureBytes.zeroFill(kekPw);
      return dek;
    } on CryptoFailure {
      SecureBytes.zeroFill(kekPw);
      throw const AuthFailure('Incorrect password');
    }
  }

  Future<Uint8List> unlockWithRecoveryKey(Uint8List recoveryKey) async {
    final keyring = await _readKeyring();
    final kekRk = _deriveKek(recoveryKey, 'recovery_kek');
    try {
      final wrapped = SecureBytes.fromHex(keyring['dek_rk'] as String);
      final dek = await AesGcm256.decrypt(wrapped, kekRk);
      SecureBytes.zeroFill(kekRk);
      return dek;
    } on CryptoFailure {
      SecureBytes.zeroFill(kekRk);
      throw const AuthFailure('Incorrect recovery key');
    }
  }

  // ── Password change / recovery key regeneration (Phase 5C/5D) ─────────────
  //
  // Both only re-wrap the DEK; the DEK itself (and therefore the database and
  // biometric quick-unlock wrapping) is unchanged.

  /// Verifies [currentPassword], then re-wraps the DEK under [newPassword]
  /// with a fresh salt. The old password stops working immediately.
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final dek = await unlockWithPassword(currentPassword);
    try {
      final keyring = await _readKeyring();
      final salt = SecureBytes.randomBytes(_saltBytes);
      final kek = await _deriveKey(newPassword, salt);
      final wrapped = await AesGcm256.encrypt(dek, kek);
      SecureBytes.zeroFill(kek);
      await _writeKeyring(
        kdfParams: {
          'alg': 'argon2id',
          'ops': _opsLimit,
          'mem': _memLimit,
          'parallelism': _parallelism,
          'salt': SecureBytes.toHex(salt),
        },
        dekWrappedPw: wrapped,
        dekWrappedRk: SecureBytes.fromHex(keyring['dek_rk'] as String),
      );
    } finally {
      SecureBytes.zeroFill(dek);
    }
  }

  /// Requires the current password. Generates a new recovery key, re-wraps
  /// the DEK under it and returns it (shown once). The old key stops working.
  Future<Uint8List> regenerateRecoveryKey(String currentPassword) async {
    final dek = await unlockWithPassword(currentPassword);
    try {
      final keyring = await _readKeyring();
      final recoveryKey = SecureBytes.randomBytes(_keyBytes);
      final kekRk = _deriveKek(recoveryKey, 'recovery_kek');
      final wrappedRk = await AesGcm256.encrypt(dek, kekRk);
      SecureBytes.zeroFill(kekRk);
      await _writeKeyring(
        kdfParams: Map<String, dynamic>.from(
          keyring['kdf_params'] as Map<String, dynamic>,
        ),
        dekWrappedPw: SecureBytes.fromHex(keyring['dek_pw'] as String),
        dekWrappedRk: wrappedRk,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        AppIdentifiers.prefRecoveryVerifiedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      return recoveryKey;
    } finally {
      SecureBytes.zeroFill(dek);
    }
  }

  /// True if [recoveryKey] opens the keyring (does not unlock the app).
  Future<bool> verifyRecoveryKey(Uint8List recoveryKey) async {
    try {
      final dek = await unlockWithRecoveryKey(recoveryKey);
      SecureBytes.zeroFill(dek);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        AppIdentifiers.prefRecoveryVerifiedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      return true;
    } on AuthFailure {
      return false;
    }
  }

  /// Days until the next "Verify your recovery key" nudge (≤ 0 → due now).
  static Future<int> daysUntilRecoveryReminder({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(AppIdentifiers.prefRecoveryVerifiedAt);
    if (last == null) return 0;
    final elapsed = (now ?? DateTime.now())
        .difference(DateTime.fromMillisecondsSinceEpoch(last))
        .inDays;
    return 30 - elapsed;
  }

  Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppIdentifiers.prefOnboardingDone, true);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Uint8List _deriveKek(Uint8List key, String label) {
    final labelBytes = utf8.encode(label);
    final result = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      result[i] = key[i % key.length] ^ labelBytes[i % labelBytes.length] ^ i;
    }
    return result;
  }

  Future<void> _writeKeyring({
    required Map<String, dynamic> kdfParams,
    required Uint8List dekWrappedPw,
    required Uint8List dekWrappedRk,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, AppIdentifiers.keyringFileName));
    final data = jsonEncode({
      'magic': AppIdentifiers.keyringMagic,
      'ver': 1,
      'kdf_params': kdfParams,
      'dek_pw': SecureBytes.toHex(dekWrappedPw),
      'dek_rk': SecureBytes.toHex(dekWrappedRk),
    });
    file.writeAsStringSync(data);
  }

  Future<Map<String, dynamic>> _readKeyring() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, AppIdentifiers.keyringFileName));
    if (!file.existsSync()) {
      throw const AuthFailure('No keyring found — app not set up');
    }
    final raw = file.readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<bool> get isSetUp async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, AppIdentifiers.keyringFileName));
    return file.existsSync();
  }
}
