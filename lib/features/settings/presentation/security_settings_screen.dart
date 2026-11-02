// lib/features/settings/presentation/security_settings_screen.dart
// Spec §4.10 (Phase 5D): app-lock method, password change, vaults, recovery
// key, screenshot protection, wipe-after-N-failures. Plus the Data settings
// page (storage usage, clear caches, erase all data).

import 'package:streakin/core/design/icons.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streakin/app/router.dart' show AppRoutes;
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/platform/windows_capture_guard.dart';
import 'package:streakin/core/security/erase_all_data_service.dart';
import 'package:streakin/core/security/password_strength.dart';
import 'package:streakin/core/security/vault_manager.dart';
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/features/onboarding/application/onboarding_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _vaultListProvider = FutureProvider.autoDispose<List<VaultRecord>>((ref) {
  ref.watch(unlockedVaultIdsProvider); // refresh on lock/unlock
  final vm = ref.watch(vaultManagerStateProvider);
  return vm == null ? Future.value(const []) : vm.vaults();
});

final _recoveryDaysProvider = FutureProvider.autoDispose<int>(
  (ref) => OnboardingService.daysUntilRecoveryReminder(),
);

final _wipeAfterProvider = FutureProvider.autoDispose<int>(
  (ref) async =>
      (await SharedPreferences.getInstance()).getInt(
        AppIdentifiers.prefWipeAfterFailures,
      ) ??
      0,
);

final _libsecretProvider = FutureProvider.autoDispose<bool>(
  (ref) => linuxSecretServiceAvailable(),
);

// ── Strength meter ────────────────────────────────────────────────────────────

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, super.key});
  final String password;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = PasswordStrength.estimate(password);
    final color = s.score < 2
        ? colors.danger
        : s.score == 2
        ? colors.warning
        : colors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: (s.score + 1) / 5,
          color: color,
          backgroundColor: colors.outline,
        ),
        const SizedBox(height: 4),
        Text(
          password.isEmpty
              ? 'Minimum ${PasswordStrength.minLength} characters'
              : '${s.label} · would take ${s.crackTimeLabel} to crack',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
      ],
    );
  }
}

// ── Security settings ─────────────────────────────────────────────────────────

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final vaults = ref.watch(_vaultListProvider).value ?? const [];
    final unlocked = ref.watch(unlockedVaultIdsProvider);
    final days = ref.watch(_recoveryDaysProvider).value;
    final wipe = ref.watch(_wipeAfterProvider).value ?? 0;
    final capture = ref.watch(captureBlockedProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          if (Platform.isLinux)
            ref
                .watch(_libsecretProvider)
                .maybeWhen(
                  data: (ok) => ok
                      ? const SizedBox.shrink()
                      : const MaterialBanner(
                          content: Text(
                            'No system keyring found (GNOME Keyring / KWallet). '
                            'Install libsecret so quick-unlock data is protected. '
                            'Biometrics are not available on Linux.',
                          ),
                          actions: [SizedBox.shrink()],
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
          _header('App lock', colors),
          ListTile(
            leading: Icon(AppIcons.password, color: colors.brand),
            title: const Text('Change password'),
            subtitle: const Text(
              'Your data stays readable; biometrics keep working',
            ),
            onTap: () => _changePassword(context, ref),
          ),
          ListTile(
            leading: Icon(AppIcons.biometric, color: colors.brand),
            title: const Text('Biometric unlock'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.push('/settings/biometric'),
          ),
          ListTile(
            leading: Icon(AppIcons.timerOutlined, color: colors.brand),
            title: const Text('Auto-lock delay'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.push('/settings/autolock'),
          ),
          const Divider(height: 1),
          _header('Vaults', colors),
          for (final v in vaults)
            ListTile(
              leading: Icon(
                unlocked.contains(v.id) ? AppIcons.lockOpen : AppIcons.lockFill,
                color: colors.brand,
              ),
              title: Text(v.name),
              subtitle: Text(
                unlocked.contains(v.id)
                    ? 'Unlocked · auto-lock ${_idleLabel(v.autoLockSeconds)}'
                    : 'Locked',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (a) => _vaultAction(context, ref, v, a),
                itemBuilder: (_) => [
                  if (unlocked.contains(v.id))
                    const PopupMenuItem(value: 'lock', child: Text('Lock now'))
                  else if (!v.usesAppCredential)
                    const PopupMenuItem(value: 'unlock', child: Text('Unlock')),
                  const PopupMenuItem(
                    value: 'idle',
                    child: Text('Auto-lock idle time'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete vault'),
                  ),
                ],
              ),
            ),
          ListTile(
            leading: Icon(AppIcons.addModeratorOutlined, color: colors.brand),
            title: const Text('Create vault'),
            onTap: () => _createVault(context, ref),
          ),
          const Divider(height: 1),
          _header('Recovery key', colors),
          ListTile(
            leading: Icon(AppIcons.recoveryKey, color: colors.brand),
            title: const Text('Verify recovery key'),
            subtitle: Text(
              days == null
                  ? ''
                  : days <= 0
                  ? 'Verification is due'
                  : 'Next reminder in $days days',
            ),
            onTap: () => _verifyRecovery(context, ref),
          ),
          ListTile(
            leading: Icon(AppIcons.autorenew, color: colors.brand),
            title: const Text('Regenerate recovery key'),
            subtitle: const Text(
              'Requires your password; the old key stops working',
            ),
            onTap: () => _regenerate(context, ref),
          ),
          const Divider(height: 1),
          _header('Privacy', colors),
          SwitchListTile.adaptive(
            value: capture,
            onChanged: (v) => ref.read(captureBlockedProvider.notifier).set(v),
            title: const Text('Block screenshots & screen recording'),
            subtitle: Text(
              Platform.isLinux
                  ? 'Not available on Linux (no capture-exclusion API).'
                  : Platform.isWindows
                  ? 'Uses Windows display affinity.'
                  : 'Also blanks the app in the recent-apps view.',
            ),
          ),
          const Divider(height: 1),
          _header('Brute-force protection', colors),
          ListTile(
            leading: Icon(AppIcons.deleteForeverOutlined, color: colors.danger),
            title: const Text('Wipe after failed attempts'),
            subtitle: Text(
              wipe == 0
                  ? 'Off'
                  : 'All data is erased after $wipe consecutive failures',
            ),
            trailing: DropdownButton<int>(
              value: wipe,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 20, child: Text('20')),
              ],
              onChanged: (v) => _setWipe(context, ref, v ?? 0),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _header(String t, AppColorTokens colors) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.textMuted,
      ),
    ),
  );

  static String _idleLabel(int s) => s <= 0
      ? 'never'
      : s % 60 == 0
      ? '${s ~/ 60} min'
      : '$s s';

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _setWipe(BuildContext context, WidgetRef ref, int n) async {
    if (n > 0) {
      final ok = await _confirm(
        context,
        'Enable wipe?',
        'After $n consecutive failed unlock attempts ALL data on this device '
            'is erased. This cannot be undone.',
        destructive: true,
        confirmLabel: 'Enable',
      );
      if (!ok) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppIdentifiers.prefWipeAfterFailures, n);
    ref.invalidate(_wipeAfterProvider);
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cur,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                TextField(
                  controller: next,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 8),
                PasswordStrengthMeter(password: next.text),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(color: ctx.colors.danger),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (next.text != confirm.text) {
                  setState(() => error = 'Passwords do not match');
                  return;
                }
                if (!PasswordStrength.estimate(next.text).acceptable) {
                  setState(() => error = 'New password is too weak');
                  return;
                }
                try {
                  await ref
                      .read(onboardingServiceProvider)
                      .changePassword(cur.text, next.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } on AuthFailure catch (e) {
                  setState(() => error = e.message);
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
    cur.dispose();
    next.dispose();
    confirm.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password changed')));
    }
  }

  Future<void> _verifyRecovery(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final key = await _prompt(
      context,
      'Verify recovery key',
      'Enter your recovery key',
      ctrl,
    );
    ctrl.dispose();
    if (key == null || !context.mounted) return;
    final hex = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    final ok =
        hex.length == 64 &&
        await ref
            .read(onboardingServiceProvider)
            .verifyRecoveryKey(Uint8List64.fromHex(hex));
    ref.invalidate(_recoveryDaysProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Recovery key verified'
              : 'That key does not match. Check it and try again.',
        ),
      ),
    );
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      'Regenerate recovery key?',
      'Your current recovery key will stop working. You must save the new one.',
      confirmLabel: 'Continue',
    );
    if (!confirmed || !context.mounted) return;
    final ctrl = TextEditingController();
    final pw = await _prompt(
      context,
      'Confirm password',
      'Current password',
      ctrl,
      obscure: true,
    );
    ctrl.dispose();
    if (pw == null || !context.mounted) return;
    try {
      final key = await ref
          .read(onboardingServiceProvider)
          .regenerateRecoveryKey(pw);
      final hex = key
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      final groups = [
        for (var i = 0; i < hex.length; i += 5)
          hex.substring(i, (i + 5).clamp(0, hex.length)),
      ].join('-');
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('New recovery key'),
          content: SelectableText(groups),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('I saved it'),
            ),
          ],
        ),
      );
      ref.invalidate(_recoveryDaysProvider);
    } on AuthFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _createVault(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create vault'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Vault name'),
              ),
              TextField(
                controller: pw,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Vault password'),
              ),
              const SizedBox(height: 8),
              PasswordStrengthMeter(password: pw.text),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  name.text.trim().isEmpty ||
                      !PasswordStrength.estimate(pw.text).acceptable
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref
          .read(vaultManagerStateProvider)
          ?.createVault(name.text.trim(), pw.text);
      ref.invalidate(_vaultListProvider);
    }
    name.dispose();
    pw.dispose();
  }

  Future<void> _vaultAction(
    BuildContext context,
    WidgetRef ref,
    VaultRecord v,
    String action,
  ) async {
    final vm = ref.read(vaultManagerStateProvider);
    if (vm == null) return;
    switch (action) {
      case 'lock':
        vm.lockVault(v.id);
      case 'unlock':
        final ctrl = TextEditingController();
        final pw = await _prompt(
          context,
          'Unlock ${v.name}',
          'Vault password',
          ctrl,
          obscure: true,
        );
        ctrl.dispose();
        if (pw == null) return;
        try {
          await vm.unlockVault(v.id, pw);
        } on AuthFailure catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      case 'idle':
        final secs = await showDialog<int>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Auto-lock after idle'),
            children: [
              for (final s in [30, 60, 120, 300, 600, 0])
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Text(_idleLabel(s)),
                ),
            ],
          ),
        );
        if (secs != null) await vm.setAutoLockSeconds(v.id, secs);
      case 'delete':
        if (await _confirm(
          context,
          'Delete vault?',
          'Notes inside become unreadable. Move them out first.',
          destructive: true,
          confirmLabel: 'Delete',
        )) {
          await vm.deleteVault(v.id);
        }
    }
    ref.invalidate(_vaultListProvider);
  }
}

/// Hex → bytes helper kept local to avoid a dependency on SecureBytes in UI.
class Uint8List64 {
  static Uint8List fromHex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

// ── Data settings ─────────────────────────────────────────────────────────────

class _StorageUsage {
  const _StorageUsage(this.db, this.attachments, this.cache);
  final int db;
  final int attachments;
  final int cache;
}

final _storageUsageProvider = FutureProvider.autoDispose<_StorageUsage>((
  ref,
) async {
  final support = await getApplicationSupportDirectory();
  Future<int> dirSize(Directory d) async {
    if (!d.existsSync()) return 0;
    var n = 0;
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File) n += await e.length();
    }
    return n;
  }

  Future<int> fileSize(String name) async {
    final f = File(p.join(support.path, name));
    return f.existsSync() ? f.lengthSync() : 0;
  }

  final db =
      await fileSize(AppIdentifiers.dbFileName) +
      await fileSize('${AppIdentifiers.dbFileName}-wal');
  final attachments = await dirSize(
    Directory(p.join(support.path, 'attachments')),
  );
  final cache = await dirSize(await getTemporaryDirectory());
  return _StorageUsage(db, attachments, cache);
});

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final usage = ref.watch(_storageUsageProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Data'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(AppIcons.swapHoriz, color: colors.brand),
            title: const Text('Export / Import / Devices'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.push('/settings/sharing'),
          ),
          const Divider(height: 1),
          usage.when(
            data: (u) => Column(
              children: [
                ListTile(
                  title: const Text('Database'),
                  trailing: Text(formatBytes(u.db)),
                ),
                ListTile(
                  title: const Text('Attachments'),
                  trailing: Text(formatBytes(u.attachments)),
                ),
                ListTile(
                  title: const Text('Caches'),
                  trailing: Text(formatBytes(u.cache)),
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            error: (_, _) => const ListTile(title: Text('Usage unavailable')),
          ),
          ListTile(
            leading: Icon(
              AppIcons.cleaningServicesOutlined,
              color: colors.brand,
            ),
            title: const Text('Clear caches'),
            onTap: () async {
              await clearCaches();
              ref.invalidate(_storageUsageProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Caches cleared')));
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(AppIcons.deleteForever, color: colors.danger),
            title: Text(
              'Erase all data',
              style: TextStyle(color: colors.danger),
            ),
            subtitle: const Text(
              'Deletes everything on this device. Irreversible.',
            ),
            onTap: () => _erase(context, ref),
          ),
        ],
      ),
    );
  }

  /// Deletes thumbnail/temp cache files and the in-memory image cache.
  static Future<void> clearCaches() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final tmp = await getTemporaryDirectory();
    if (tmp.existsSync()) {
      await for (final e in tmp.list()) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final first = await _confirm(
      context,
      'Erase all data?',
      'Habits, notes, tasks, vaults and keys will be deleted from this device.',
      destructive: true,
      confirmLabel: 'Continue',
    );
    if (!first || !context.mounted) return;
    final second = await _confirm(
      context,
      'This cannot be undone',
      'Without an export, nothing can bring your data back. Erase now?',
      destructive: true,
      confirmLabel: 'Erase everything',
    );
    if (!second) return;
    await ref.read(eraseAllDataServiceProvider).eraseAll();
    if (context.mounted) context.go(AppRoutes.onboarding);
  }
}

// ── Shared dialogs ────────────────────────────────────────────────────────────

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body, {
  bool destructive = false,
  String confirmLabel = 'OK',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.colors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> _prompt(
  BuildContext context,
  String title,
  String label,
  TextEditingController ctrl, {
  bool obscure = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        obscureText: obscure,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
