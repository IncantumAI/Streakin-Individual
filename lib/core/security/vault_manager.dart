// lib/core/security/vault_manager.dart
// Spec §8.2/§8.3/§4.4.7: per-vault 256-bit key (VK) wrapped under an
// Argon2id-derived KEK_v (or under a key derived from the app DEK for
// "use app credential" vaults). VK lives only in memory while unlocked.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/crypto/hkdf.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/features/notes/domain/vault_body_codec.dart';

/// Argon2id cost parameters for vault passwords. Tests use cheap values.
class VaultKdfParams {
  const VaultKdfParams({
    this.ops = 3,
    this.memKiB = 64 * 1024,
    this.parallelism = 1,
  });
  final int ops;
  final int memKiB;
  final int parallelism;
}

/// Persisted vault row (maps to the `vaults` table).
class VaultRecord {
  const VaultRecord({
    required this.id,
    required this.name,
    required this.kdfParams,
    required this.wrappedVaultKey,
    this.wrappedVaultKeyRecovery,
    this.autoLockSeconds = 120,
  });

  final String id;
  final String name;

  /// JSON: {alg, ops, mem, p, salt, mode: 'password'|'app'}
  final Map<String, dynamic> kdfParams;
  final String wrappedVaultKey; // hex
  final String? wrappedVaultKeyRecovery; // hex
  final int autoLockSeconds;

  bool get usesAppCredential => kdfParams['mode'] == 'app';

  VaultRecord copyWith({int? autoLockSeconds, String? name}) => VaultRecord(
    id: id,
    name: name ?? this.name,
    kdfParams: kdfParams,
    wrappedVaultKey: wrappedVaultKey,
    wrappedVaultKeyRecovery: wrappedVaultKeyRecovery,
    autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
  );
}

abstract interface class VaultStore {
  Future<List<VaultRecord>> all();
  Future<VaultRecord?> get(String id);
  Future<void> save(VaultRecord vault);
  Future<void> delete(String id);
}

class VaultManager implements VaultBodyCodec {
  VaultManager({
    required this._store,
    this._kdf = const VaultKdfParams(),
    this._onChanged,
  });

  final VaultStore _store;
  final VaultKdfParams _kdf;
  final void Function(Set<String> unlocked)? _onChanged;

  final Map<String, Uint8List> _keys = {};
  final Map<String, Timer> _idle = {};
  final Map<String, int> _idleSeconds = {};

  static const _uuid = Uuid();
  static const _bodyPrefix = 'vlt1:';

  // ── State ───────────────────────────────────────────────────────────────

  @override
  bool isUnlocked(String vaultId) => _keys.containsKey(vaultId);

  Set<String> get unlockedIds => _keys.keys.toSet();

  Future<List<VaultRecord>> vaults() => _store.all();

  // ── Create ──────────────────────────────────────────────────────────────

  /// Creates a vault protected by its own [password]; returns its id.
  /// The new vault is left unlocked.
  Future<String> createVault(String name, String password) async {
    final id = _uuid.v4();
    final salt = SecureBytes.randomBytes(16);
    final kek = await _derive(password, salt, _kdf);
    final vk = SecureBytes.randomBytes(32);
    final wrapped = await AesGcm256.encrypt(vk, kek);
    SecureBytes.zeroFill(kek);
    await _store.save(
      VaultRecord(
        id: id,
        name: name,
        kdfParams: {
          'alg': 'argon2id',
          'ops': _kdf.ops,
          'mem': _kdf.memKiB,
          'p': _kdf.parallelism,
          'salt': SecureBytes.toHex(salt),
          'mode': 'password',
        },
        wrappedVaultKey: SecureBytes.toHex(wrapped),
      ),
    );
    _load(id, vk, 120);
    return id;
  }

  /// Creates a vault that unlocks automatically whenever the app unlocks
  /// ("use app credential"). [appDek] is the app's data-encryption key.
  Future<String> createAppCredentialVault(String name, Uint8List appDek) async {
    final id = _uuid.v4();
    final vk = SecureBytes.randomBytes(32);
    final kek = HkdfDerive.deriveSync(appDek, 'vault:$id');
    final wrapped = await AesGcm256.encrypt(vk, kek);
    SecureBytes.zeroFill(kek);
    await _store.save(
      VaultRecord(
        id: id,
        name: name,
        kdfParams: {'mode': 'app'},
        wrappedVaultKey: SecureBytes.toHex(wrapped),
      ),
    );
    _load(id, vk, 120);
    return id;
  }

  // ── Unlock / lock ───────────────────────────────────────────────────────

  Future<void> unlockVault(String vaultId, String password) async {
    final v = await _requireVault(vaultId);
    if (v.usesAppCredential) {
      throw const AuthFailure('This vault unlocks with the app credential');
    }
    final p = v.kdfParams;
    final kdf = VaultKdfParams(
      ops: p['ops'] as int,
      memKiB: p['mem'] as int,
      parallelism: p['p'] as int,
    );
    final kek = await _derive(
      password,
      SecureBytes.fromHex(p['salt'] as String),
      kdf,
    );
    try {
      final vk = await AesGcm256.decrypt(
        SecureBytes.fromHex(v.wrappedVaultKey),
        kek,
      );
      _load(vaultId, vk, v.autoLockSeconds);
    } on CryptoFailure {
      throw const AuthFailure('Incorrect vault password');
    } finally {
      SecureBytes.zeroFill(kek);
    }
  }

  /// Called when the app unlocks: opens every "use app credential" vault.
  Future<void> unlockAppCredentialVaults(Uint8List appDek) async {
    for (final v in await _store.all()) {
      if (!v.usesAppCredential || isUnlocked(v.id)) continue;
      final kek = HkdfDerive.deriveSync(appDek, 'vault:${v.id}');
      try {
        final vk = await AesGcm256.decrypt(
          SecureBytes.fromHex(v.wrappedVaultKey),
          kek,
        );
        _load(v.id, vk, v.autoLockSeconds);
      } on CryptoFailure {
        // Leave locked; surfaced in the vault list.
      } finally {
        SecureBytes.zeroFill(kek);
      }
    }
  }

  void lockVault(String vaultId) {
    _idle.remove(vaultId)?.cancel();
    _idleSeconds.remove(vaultId);
    final key = _keys.remove(vaultId);
    if (key != null) SecureBytes.zeroFill(key);
    _notify();
  }

  /// App lock / background: every vault locks.
  void lockAll() {
    for (final id in _keys.keys.toList()) {
      _idle.remove(id)?.cancel();
      SecureBytes.zeroFill(_keys[id]!);
    }
    _keys.clear();
    _idle.clear();
    _idleSeconds.clear();
    _notify();
  }

  Future<void> setAutoLockSeconds(String vaultId, int seconds) async {
    final v = await _requireVault(vaultId);
    await _store.save(v.copyWith(autoLockSeconds: seconds));
    if (isUnlocked(vaultId)) _armIdle(vaultId, seconds);
  }

  Future<void> deleteVault(String vaultId) async {
    lockVault(vaultId);
    await _store.delete(vaultId);
  }

  // ── Scoped key access ───────────────────────────────────────────────────

  /// Runs [callback] with the vault key and resets the idle timer.
  Future<T> use<T>(
    String vaultId,
    Future<T> Function(Uint8List vaultKey) callback,
  ) async {
    final key = _keys[vaultId];
    if (key == null) throw const AuthFailure('Vault is locked');
    final secs = _idleSeconds[vaultId];
    if (secs != null) _armIdle(vaultId, secs);
    return callback(key);
  }

  // ── VaultBodyCodec ──────────────────────────────────────────────────────

  @override
  Future<String> encrypt(String vaultId, String plaintext) =>
      use(vaultId, (vk) async {
        final enc = await AesGcm256.encrypt(
          Uint8List.fromList(utf8.encode(plaintext)),
          vk,
        );
        return _bodyPrefix + base64.encode(enc);
      });

  @override
  Future<String> decrypt(String vaultId, String ciphertext) =>
      use(vaultId, (vk) async {
        if (!ciphertext.startsWith(_bodyPrefix)) {
          throw const CryptoFailure('Not a vault ciphertext');
        }
        final raw = base64.decode(ciphertext.substring(_bodyPrefix.length));
        final plain = await AesGcm256.decrypt(Uint8List.fromList(raw), vk);
        return utf8.decode(plain);
      });

  /// True if [value] looks like vault ciphertext (used by tests/export).
  static bool isCiphertext(String value) => value.startsWith(_bodyPrefix);

  // ── Internals ───────────────────────────────────────────────────────────

  void _load(String id, Uint8List vk, int autoLockSeconds) {
    _keys[id] = Uint8List.fromList(vk);
    SecureBytes.zeroFill(vk);
    _idleSeconds[id] = autoLockSeconds;
    _armIdle(id, autoLockSeconds);
    _notify();
  }

  void _armIdle(String id, int seconds) {
    _idleSeconds[id] = seconds;
    _idle.remove(id)?.cancel();
    if (seconds <= 0) return; // 0 = never auto-lock
    _idle[id] = Timer(Duration(seconds: seconds), () => lockVault(id));
  }

  Future<VaultRecord> _requireVault(String id) async {
    final v = await _store.get(id);
    if (v == null) throw const StorageFailure('Vault not found');
    return v;
  }

  void _notify() => _onChanged?.call(unlockedIds);

  static Future<Uint8List> _derive(
    String password,
    Uint8List salt,
    VaultKdfParams p,
  ) async {
    final argon = DartArgon2id(
      parallelism: p.parallelism,
      memory: p.memKiB,
      iterations: p.ops,
      hashLength: 32,
    );
    final key = await argon.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}

// ── Riverpod ─────────────────────────────────────────────────────────────────

/// Ids of vaults whose key is currently in memory. UI/guards watch this.
class _UnlockedVaultsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void set(Set<String> ids) => state = ids;
}

final unlockedVaultIdsProvider =
    NotifierProvider<_UnlockedVaultsNotifier, Set<String>>(
      _UnlockedVaultsNotifier.new,
    );

class _VaultManagerNotifier extends Notifier<VaultManager?> {
  @override
  VaultManager? build() => null;
  void set(VaultManager m) => state = m;
  void clear() {
    state?.lockAll();
    state = null;
  }
}

final vaultManagerStateProvider =
    NotifierProvider<_VaultManagerNotifier, VaultManager?>(
      _VaultManagerNotifier.new,
    );
