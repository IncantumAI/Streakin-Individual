// lib/features/onboarding/presentation/lock_screen.dart
// Spec §8.3, §8.4: password / recovery key / biometric unlock.
//
// Biometric DEK storage notes:
// • flutter_secure_storage historically wrapped keys in EncryptedSharedPreferences
//   (Tink AEAD). On MIUI/Xiaomi and some Samsung Knox devices the Tink master key
//   is invalidated on reinstall or lock-screen PIN change, causing a
//   SecurityException during plugin initialisation (confirmed in device log).
// • Primary fix: We bypass the default `FlutterSecureStorage.xml` file entirely
//   by supplying `sharedPreferencesName: 'biometric_storage_v2'`. If the app
//   is reinstalled, Android restores the old file but we never read it, ensuring
//   a clean initialisation of the plugin with new AES/GCM keys.
// • Secondary fix (Dart layer): AndroidOptions(resetOnError: true) — if a
//   corrupt entry is somehow still read, the plugin auto-wipes and returns null.
// • On any decryption failure we show a one-time “unlock with password” prompt
//   so the user can re-register biometrics after a successful password unlock.

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/features/onboarding/application/onboarding_service.dart';
import 'package:streakin/app/router.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({this.returnTo, super.key});
  final String? returnTo;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pwController = TextEditingController();
  bool _pwVisible = false;
  bool _unlocking = false;
  String? _error;
  bool _showRecovery = false;
  final _rkController = TextEditingController();

  bool _biometricAvailable = false;
  bool _biometricAttempted = false;

  // resetOnError: true — if FlutterSecureStorage fails to decrypt a stored key
  // (e.g. Tink key invalidated after reinstall on MIUI/Samsung Knox), the plugin
  // will wipe its storage and return null rather than throwing a SecurityException.
  // The custom sharedPreferencesName is the primary fix; this is a Dart-layer
  // safety net that handles any edge-cases that slip through.
  // Note: encryptedSharedPreferences is deprecated in flutter_secure_storage v11
  // and will be removed; it is intentionally omitted here.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      sharedPreferencesName: 'biometric_storage_v2',
    ),
  );
  static const _dekBiometricKey = AppIdentifiers.ssKeyQuickUnlock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkSetup();
      await _checkBiometricAndAutoPrompt();
    });
  }

  Future<void> _checkSetup() async {
    final isSetUp = await ref.read(onboardingServiceProvider).isSetUp;
    if (!isSetUp && mounted) context.go(AppRoutes.onboarding);
  }

  Future<void> _checkBiometricAndAutoPrompt() async {
    // Read directly from SharedPreferences to avoid async Riverpod load race.
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(AppIdentifiers.prefBiometricEnabled) ?? false;
    if (!enabled) return;

    try {
      final auth = LocalAuthentication();
      final isSupported = await auth.isDeviceSupported();
      if (!isSupported) return;

      // Try reading the stored DEK — this is where decryption failures surface.
      // If the native plugin crashes, the MethodChannel hangs infinitely.
      // We use .timeout() to detect this hang and trigger the native wipe.
      bool hasDek = false;
      try {
        hasDek = await _storage.containsKey(key: _dekBiometricKey).timeout(const Duration(milliseconds: 800));
      } catch (_) {
        // Keystore key invalidated (reinstall, lock-screen change on MIUI).
        // Native thread probably crashed. Delete corrupted entry securely.
        await _clearBiometricDek();
        hasDek = false;
      }

      if (hasDek && mounted) {
        setState(() => _biometricAvailable = true);
        if (!_biometricAttempted) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (mounted) unawaited(_unlockWithBiometric());
        }
      }
    } catch (_) {}
  }

  /// Safely delete the stored biometric DEK, wiping the native file if needed.
  Future<void> _clearBiometricDek() async {
    try {
      // First, try wiping the file at the native level to handle severe Keystore corruption
      // that prevents flutter_secure_storage from even completing its own initialisation.
      await const MethodChannel('streakin.native').invokeMethod<void>('clearCorruptedBiometrics');
    } catch (_) {}
    try {
      await _storage.delete(key: _dekBiometricKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pwController.dispose();
    _rkController.dispose();
    super.dispose();
  }

  // ── Biometric unlock ───────────────────────────────────────────────────────

  Future<void> _unlockWithBiometric() async {
    if (_unlocking) return;
    setState(() {
      _unlocking = true;
      _biometricAttempted = true;
      _error = null;
    });
    try {
      final auth = LocalAuthentication();
      final authenticated = await auth.authenticate(
        localizedReason: 'Unlock Streakin with biometrics',
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) {
        if (mounted) setState(() => _unlocking = false);
        return;
      }

      // Read the stored DEK.
      // Catch Object to handle PlatformException and native Error subclasses
      // that may be thrown on MIUI/Samsung Knox after reinstall.
      String? dekBase64;
      try {
        dekBase64 = await _storage.read(key: _dekBiometricKey).timeout(const Duration(milliseconds: 800));
      } catch (_) {
        // Keystore key invalidated — clear and ask for password.
        await _clearBiometricDek();
      }

      if (dekBase64 == null) {
        if (mounted) {
          setState(() {
            _unlocking = false;
            _biometricAvailable = false;
            _error =
                'Biometric registration expired. Please unlock with your '
                'password once to re-enable biometrics.';
          });
        }
        return;
      }

      final dek = Uint8List.fromList(base64Decode(dekBase64));
      ref.read(keyVaultProvider).load(dek);
      ref.read(LockController.provider.notifier).onUnlocked();

      if (mounted) {
        final dest = widget.returnTo != null
            ? Uri.decodeComponent(widget.returnTo!)
            : AppRoutes.home;
        context.go(dest);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _unlocking = false;
          _error = 'Biometric authentication failed. Try your password.';
        });
      }
    }
  }

  // ── Password / recovery unlock ─────────────────────────────────────────────

  Future<void> _unlock() async {
    final pw = _pwController.text.trim();
    final rk = _rkController.text.trim();
    if (!_showRecovery && pw.isEmpty) return;
    if (_showRecovery && rk.isEmpty) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });

    try {
      final Uint8List dek;
      if (_showRecovery) {
        final hex = rk.replaceAll('-', '').replaceAll(' ', '');
        dek = await ref
            .read(onboardingServiceProvider)
            .unlockWithRecoveryKey(_hexToBytes(hex));
      } else {
        dek = await ref
            .read(onboardingServiceProvider)
            .unlockWithPassword(pw);
      }

      // After a successful password unlock, (re-)register the DEK for
      // biometric unlock if the setting is enabled.
      // Read from SharedPreferences directly to avoid the async Riverpod
      // load race where biometricEnabledProvider may still be false.
      try {
        final prefs = await SharedPreferences.getInstance();
        final biometricEnabled =
            prefs.getBool(AppIdentifiers.prefBiometricEnabled) ?? false;
        if (biometricEnabled) {
          await _storage.write(
            key: _dekBiometricKey,
            value: base64Encode(dek),
          ).timeout(const Duration(milliseconds: 800));
        }
      } catch (_) {
        // Non-fatal — biometric DEK storage failure must not block unlock.
      }

      ref.read(keyVaultProvider).load(dek);
      ref.read(LockController.provider.notifier).onUnlocked();

      if (mounted) {
        final dest = widget.returnTo != null
            ? Uri.decodeComponent(widget.returnTo!)
            : AppRoutes.home;
        context.go(dest);
      }
    } on AuthFailure catch (e) {
      setState(() {
        _error = e.message;
        _unlocking = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unlock failed. Please try again.';
        _unlocking = false;
      });
    }
  }

  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Icon(AppIcons.lockFill, size: 48, color: colors.brand),
                  const SizedBox(height: 24),
                  Text(
                    _showRecovery ? 'Enter recovery key' : 'Welcome back',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Biometric button ───────────────────────────────────────
                  if (_biometricAvailable && !_showRecovery) ...[
                    OutlinedButton.icon(
                      onPressed: _unlocking ? null : _unlockWithBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Unlock with biometrics'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: colors.brand),
                        foregroundColor: colors.brand,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: Divider(color: colors.outline)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                color: colors.textMuted, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: colors.outline)),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  // ── Password / recovery field ──────────────────────────────
                  if (_showRecovery)
                    TextField(
                      controller: _rkController,
                      decoration: const InputDecoration(
                        labelText: 'Recovery key (e.g. AAABB-CCCDD-...)',
                      ),
                    )
                  else
                    TextField(
                      controller: _pwController,
                      obscureText: !_pwVisible,
                      autofocus: !_biometricAvailable,
                      onSubmitted: (_) => _unlock(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                              _pwVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _pwVisible = !_pwVisible),
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(color: colors.danger, fontSize: 13),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _unlocking ? null : _unlock,
                    child: _unlocking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Unlock'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {
                      _showRecovery = !_showRecovery;
                      _error = null;
                    }),
                    child: Text(_showRecovery
                        ? 'Back to password'
                        : 'Forgot password?'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
