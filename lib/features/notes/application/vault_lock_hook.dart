// lib/features/notes/application/vault_lock_hook.dart
// Surfaces ask this hook whether a vault is locked (graph, calendar, …).
// Backed by VaultManager's unlocked set (Phase 5): a vault is locked unless
// its key is currently in memory.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/security/vault_manager.dart'
    show unlockedVaultIdsProvider;

typedef IsVaultLocked = bool Function(String vaultId);

final isVaultLockedProvider = Provider<IsVaultLocked>((ref) {
  final unlocked = ref.watch(unlockedVaultIdsProvider);
  return (id) => !unlocked.contains(id);
});
