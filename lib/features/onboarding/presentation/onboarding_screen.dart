// lib/features/onboarding/presentation/onboarding_screen.dart
// Spec §4.1: 3-step onboarding — appearance, lock setup, recovery key.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';
import 'package:streakin/features/onboarding/application/onboarding_service.dart';
import 'package:streakin/app/router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final _pageController = PageController();

  // Step 2 state
  final _pwController = TextEditingController();
  final _pwConfirmController = TextEditingController();
  bool _pwVisible = false;
  String? _pwError;
  bool _settingUp = false;

  // Step 3 state
  String? _recoveryKey;
  bool _savedConfirmed = false;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      // resizeToAvoidBottomInset: true keeps Scaffold from blocking keyboard,
      // but we handle overflow ourselves via SingleChildScrollView in each step.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i <= _step ? colors.brand : colors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step1Appearance(onNext: _next),
                  _Step2Lock(
                    pwController: _pwController,
                    pwConfirmController: _pwConfirmController,
                    pwVisible: _pwVisible,
                    pwError: _pwError,
                    settingUp: _settingUp,
                    onToggleVisible: () => setState(() => _pwVisible = !_pwVisible),
                    onNext: _handlePasswordSetup,
                  ),
                  _Step3RecoveryKey(
                    recoveryKey: _recoveryKey,
                    savedConfirmed: _savedConfirmed,
                    finishing: _finishing,
                    onConfirm: (v) => setState(() => _savedConfirmed = v),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePasswordSetup() async {
    final pw = _pwController.text;
    final confirm = _pwConfirmController.text;
    if (pw.length < 10) {
      setState(() => _pwError = 'Password must be at least 10 characters');
      return;
    }
    if (pw != confirm) {
      setState(() => _pwError = 'Passwords do not match');
      return;
    }
    setState(() { _settingUp = true; _pwError = null; });
    try {
      final rk = await ref.read(onboardingServiceProvider).setupPassword(pw);
      final hex = rk.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
      final groups = <String>[];
      for (int i = 0; i < hex.length; i += 5) {
        groups.add(hex.substring(i, (i + 5).clamp(0, hex.length)));
      }
      setState(() {
        _recoveryKey = groups.join('-');
        _settingUp = false;
      });
      _next();
    } catch (e) {
      setState(() { _pwError = 'Setup failed: $e'; _settingUp = false; });
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref.read(onboardingServiceProvider).markDone();
      // Invalidate so onboardingDoneProvider re-reads SharedPreferences.
      // This triggers _RouterListenable → router redirect → /lock.
      ref.invalidate(onboardingDoneProvider);
      // Router will redirect automatically; no explicit context.go() needed.
      // Fallback in case invalidation alone doesn't navigate fast enough:
      if (mounted) context.go(AppRoutes.lock);
    } catch (e) {
      if (mounted) setState(() => _finishing = false);
    }
  }
}

// ── Step 1: Appearance ────────────────────────────────────────────────────────

class _Step1Appearance extends ConsumerWidget {
  const _Step1Appearance({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mode = ref.watch(themeModeProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose your look', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text('You can change this anytime in settings.',
              style: TextStyle(color: colors.textMuted)),
          const SizedBox(height: 32),
          _ThemeOption(label: 'Light', mode: ThemeMode.light, selected: mode == ThemeMode.light),
          const SizedBox(height: 12),
          _ThemeOption(label: 'Dark', mode: ThemeMode.dark, selected: mode == ThemeMode.dark),
          const SizedBox(height: 12),
          _ThemeOption(label: 'Follow system', mode: ThemeMode.system, selected: mode == ThemeMode.system),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  const _ThemeOption({required this.label, required this.mode, required this.selected});
  final String label;
  final ThemeMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).set(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colors.brand.withValues(alpha: 0.1) : colors.surfaceAlt,
          border: Border.all(color: selected ? colors.brand : colors.outline, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.normal))),
          if (selected) Icon(AppIcons.check, color: colors.brand, size: 20),
        ]),
      ),
    );
  }
}

// ── Step 2: Lock setup ────────────────────────────────────────────────────────

class _Step2Lock extends ConsumerStatefulWidget {
  const _Step2Lock({
    required this.pwController,
    required this.pwConfirmController,
    required this.pwVisible,
    required this.pwError,
    required this.settingUp,
    required this.onToggleVisible,
    required this.onNext,
  });
  final TextEditingController pwController;
  final TextEditingController pwConfirmController;
  final bool pwVisible;
  final String? pwError;
  final bool settingUp;
  final VoidCallback onToggleVisible;
  final VoidCallback onNext;

  @override
  ConsumerState<_Step2Lock> createState() => _Step2LockState();
}

class _Step2LockState extends ConsumerState<_Step2Lock> {
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      if (mounted) setState(() => _biometricAvailable = canCheck && isSupported);
    } catch (_) {
      // Device doesn't support biometrics — hide the option.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Protect your data', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text('Your password encrypts all your data locally.\nMinimum 10 characters.',
              style: TextStyle(color: colors.textMuted)),
          const SizedBox(height: 32),
          TextField(
            controller: widget.pwController,
            obscureText: !widget.pwVisible,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(widget.pwVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: widget.onToggleVisible,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.pwConfirmController,
            obscureText: !widget.pwVisible,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          if (widget.pwError != null) ...[
            const SizedBox(height: 8),
            Text(widget.pwError!, style: TextStyle(color: colors.danger, fontSize: 13)),
          ],
          if (_biometricAvailable) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outline),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: biometricEnabled,
                activeColor: colors.brand,
                onChanged: (v) =>
                    ref.read(biometricEnabledProvider.notifier).set(v),
                title: Text('Enable biometric unlock',
                    style: TextStyle(color: colors.text, fontSize: 14)),
                subtitle: Text(
                    'Use fingerprint or face ID to unlock after password is set.',
                    style: TextStyle(color: colors.textMuted, fontSize: 12)),
                secondary: Icon(Icons.fingerprint, color: colors.brand),
              ),
            ),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.settingUp ? null : widget.onNext,
              child: widget.settingUp
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Set password & continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Recovery key ──────────────────────────────────────────────────────

class _Step3RecoveryKey extends StatelessWidget {
  const _Step3RecoveryKey({
    required this.recoveryKey,
    required this.savedConfirmed,
    required this.finishing,
    required this.onConfirm,
    required this.onFinish,
  });
  final String? recoveryKey;
  final bool savedConfirmed;
  final bool finishing;
  final ValueChanged<bool> onConfirm;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Save your recovery key', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            'If you forget your password, this key is your only way back in.\nWrite it down somewhere safe.',
            style: TextStyle(color: colors.textMuted),
          ),
          const SizedBox(height: 24),
          if (recoveryKey != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outline),
              ),
              child: SelectableText(
                recoveryKey!,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: savedConfirmed,
            onChanged: (v) => onConfirm(v ?? false),
            title: const Text('I have written down my recovery key'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (savedConfirmed && !finishing) ? onFinish : null,
              child: finishing
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("I'm ready — let's go"),
            ),
          ),
        ],
      ),
    );
  }
}
