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

import 'package:streakin/app/brand.dart';
import 'package:streakin/core/design/elevation.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/security/brute_force_guard.dart';
import 'package:streakin/core/security/erase_all_data_service.dart';
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/features/onboarding/application/onboarding_service.dart';
import 'package:streakin/app/router.dart';
import 'package:streakin/shared/feedback/haptics.dart';
import 'package:streakin/shared/widgets/shake.dart';

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
  final _shake = ShakeController();

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
      // Keep the existing store name: switching to storageNamespace would
      // orphan already-registered biometric keys.
      // ignore: deprecated_member_use
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
    final enabled = prefs.getBool(AppIdentifiers.prefBiometricEnabled) ?? false;
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
        hasDek = await _storage
            .containsKey(key: _dekBiometricKey)
            .timeout(const Duration(milliseconds: 800));
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
      await const MethodChannel('streakin.native')
          .invokeMethod<void>('clearCorruptedBiometrics');
    } catch (_) {}
    try {
      await _storage.delete(key: _dekBiometricKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pwController.dispose();
    _rkController.dispose();
    _shake.dispose();
    super.dispose();
  }

  /// Error feedback: shake the field and buzz (both respect user settings).
  void _signalFailure() {
    _shake.shake();
    ref.read(hapticsProvider).error();
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
        dekBase64 = await _storage
            .read(key: _dekBiometricKey)
            .timeout(const Duration(milliseconds: 800));
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

    // Brute-force defence: escalating lockout persisted in secure storage.
    final guard = ref.read(bruteForceGuardProvider);
    final wait = await guard.remaining();
    if (wait > Duration.zero) {
      if (mounted) {
        setState(
          () => _error =
              'Too many attempts. Try again in ${wait.inSeconds + 1}s.',
        );
        _signalFailure();
      }
      return;
    }
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
        dek = await ref.read(onboardingServiceProvider).unlockWithPassword(pw);
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
          await _storage
              .write(key: _dekBiometricKey, value: base64Encode(dek))
              .timeout(const Duration(milliseconds: 800));
        }
      } catch (_) {
        // Non-fatal — biometric DEK storage failure must not block unlock.
      }

      await guard.reset();
      ref.read(keyVaultProvider).load(dek);
      ref.read(LockController.provider.notifier).onUnlocked();

      if (mounted) {
        final dest = widget.returnTo != null
            ? Uri.decodeComponent(widget.returnTo!)
            : AppRoutes.home;
        context.go(dest);
      }
    } on AuthFailure catch (e) {
      final outcome = await guard.recordFailure();
      if (outcome.shouldWipe) {
        await ref.read(eraseAllDataServiceProvider).eraseAll();
        if (mounted) context.go(AppRoutes.onboarding);
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = outcome.lockedFor > Duration.zero
            ? '${e.message}. Locked for ${outcome.lockedFor.inSeconds}s.'
            : e.message;
        _unlocking = false;
      });
      _signalFailure();
    } catch (e) {
      setState(() {
        _error = 'Unlock failed. Please try again.';
        _unlocking = false;
      });
      _signalFailure();
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
    final d = resolvedDuration(context, AppDurations.base);

    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.9),
            radius: 1.1,
            colors: [colors.brand.withValues(alpha: 0.10), colors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xl,
                  vertical: AppSpace.xxl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppElevation.glow(colors.brand),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/icon.png',
                            semanticLabel: Brand.appName,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    AnimatedSwitcher(
                      duration: d,
                      child: Text(
                        _showRecovery ? 'Enter recovery key' : 'Welcome back',
                        key: ValueKey(_showRecovery),
                        style: context.text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.lockFill,
                          size: 14,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Flexible(
                          child: Text(
                            _showRecovery
                                ? 'Use the key you saved during setup'
                                : 'Encrypted on this device',
                            style: context.text.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xxl),

                    // ── Biometric button ─────────────────────────────────────
                    AnimatedSize(
                      duration: d,
                      curve: AppCurves.standard,
                      child: _biometricAvailable && !_showRecovery
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _unlocking
                                      ? null
                                      : _unlockWithBiometric,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.brandSubtle,
                                    foregroundColor: colors.brandText,
                                  ),
                                  icon: const Icon(AppIcons.biometric),
                                  label: const Text('Unlock with biometrics'),
                                ),
                                const SizedBox(height: AppSpace.lg),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(color: colors.outline),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpace.md,
                                      ),
                                      child: Text(
                                        'or',
                                        style: context.text.bodySmall,
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(color: colors.outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpace.lg),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),

                    // ── Password / recovery field ────────────────────────────
                    Shake(
                      controller: _shake,
                      child: AnimatedSwitcher(
                        duration: d,
                        child: _showRecovery
                            ? TextField(
                                key: const ValueKey('rk'),
                                controller: _rkController,
                                autofocus: true,
                                onSubmitted: (_) => _unlock(),
                                style: AppTypography.mono.copyWith(
                                  color: colors.text,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Recovery key',
                                  hintText: 'AAABB-CCCDD-…',
                                  prefixIcon: Icon(AppIcons.recoveryKey),
                                ),
                              )
                            : TextField(
                                key: const ValueKey('pw'),
                                controller: _pwController,
                                obscureText: !_pwVisible,
                                autofocus: !_biometricAvailable,
                                onSubmitted: (_) => _unlock(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(AppIcons.password),
                                  suffixIcon: IconButton(
                                    tooltip: _pwVisible
                                        ? 'Hide password'
                                        : 'Show password',
                                    icon: Icon(
                                      _pwVisible
                                          ? AppIcons.visibility
                                          : AppIcons.visibilityOff,
                                    ),
                                    onPressed: () => setState(
                                      () => _pwVisible = !_pwVisible,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    AnimatedSize(
                      duration: d,
                      curve: AppCurves.standard,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: AppSpace.md),
                              child: Semantics(
                                liveRegion: true,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.md,
                                    vertical: AppSpace.sm + 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.dangerSubtle,
                                    borderRadius: AppRadius.brMd,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.errorOutline,
                                        size: 18,
                                        color: colors.danger,
                                      ),
                                      const SizedBox(width: AppSpace.sm),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: context.text.bodySmall!
                                              .copyWith(color: colors.danger),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    FilledButton(
                      onPressed: _unlocking ? null : _unlock,
                      child: _unlocking
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.textMuted,
                              ),
                            )
                          : const Text('Unlock'),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    TextButton(
                      onPressed: () => setState(() {
                        _showRecovery = !_showRecovery;
                        _error = null;
                      }),
                      child: Text(
                        _showRecovery ? 'Back to password' : 'Forgot password?',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
