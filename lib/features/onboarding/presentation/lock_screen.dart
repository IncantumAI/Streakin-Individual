// lib/features/onboarding/presentation/lock_screen.dart
// Spec §8.3, §8.4: password / recovery key unlock with escalating lockout.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/security/lock_controller.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSetup());
  }

  Future<void> _checkSetup() async {
    final isSetUp = await ref.read(onboardingServiceProvider).isSetUp;
    if (!isSetUp && mounted) context.go(AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _pwController.dispose();
    _rkController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final pw = _pwController.text.trim();
    final rk = _rkController.text.trim();
    if (!_showRecovery && pw.isEmpty) return;
    if (_showRecovery && rk.isEmpty) return;
    setState(() { _unlocking = true; _error = null; });

    try {
      final Uint8List dek;
      if (_showRecovery) {
        final hex = rk.replaceAll('-', '').replaceAll(' ', '');
        dek = await ref.read(onboardingServiceProvider)
            .unlockWithRecoveryKey(_hexToBytes(hex));
      } else {
        dek = await ref.read(onboardingServiceProvider).unlockWithPassword(pw);
      }

      ref.read(keyVaultProvider).load(dek);
      // DEK decrypted successfully — key is correct. No further verification needed.
      ref.read(LockController.provider.notifier).onUnlocked();

      if (mounted) {
        final dest = widget.returnTo != null
            ? Uri.decodeComponent(widget.returnTo!)
            : AppRoutes.home;
        context.go(dest);
      }
    } on AuthFailure catch (e) {
      setState(() { _error = e.message; _unlocking = false; });
    } catch (e) {
      setState(() { _error = 'Unlock failed. Please try again.'; _unlocking = false; });
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(AppIcons.lockFill, size: 48, color: colors.brand),
                  const SizedBox(height: 24),
                  Text(
                    _showRecovery ? 'Enter recovery key' : 'Welcome back',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
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
                      autofocus: true,
                      onSubmitted: (_) => _unlock(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_pwVisible ? AppIcons.lockOpen : AppIcons.lock),
                          onPressed: () => setState(() => _pwVisible = !_pwVisible),
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
                            height: 20, width: 20,
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
                    child: Text(
                        _showRecovery ? 'Back to password' : 'Forgot password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
