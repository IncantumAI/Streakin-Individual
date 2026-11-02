// lib/features/notes/domain/vault_body_codec.dart
// Notes → security seam. The note repository asks this to encrypt/decrypt
// vault-scoped note titles/bodies; it never sees key material.

abstract interface class VaultBodyCodec {
  /// True while the vault's key is loaded in memory.
  bool isUnlocked(String vaultId);

  /// Encrypts [plaintext] under the vault key. Throws if locked.
  Future<String> encrypt(String vaultId, String plaintext);

  /// Decrypts a value produced by [encrypt]. Throws if locked or tampered.
  Future<String> decrypt(String vaultId, String ciphertext);
}
