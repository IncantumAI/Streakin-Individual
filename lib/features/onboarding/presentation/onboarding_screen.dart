// lib/features/onboarding/presentation/onboarding_screen.dart
// Spec §4.1: 3-step onboarding — appearance, lock setup, recovery key.
// Steps transition on a horizontal shared axis; progress is animated.

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streakin/core/security/password_strength.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import 'package:streakin/app/brand.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/features/settings/presentation/security_settings_screen.dart'
    show PasswordStrengthMeter;
import 'package:streakin/shared/feedback/haptics.dart';
import 'package:streakin/shared/widgets/shake.dart';
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
  final _shake = ShakeController();

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
    _shake.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = resolvedDuration(context, AppDurations.slow);
    final steps = <Widget>[
      _Step1Appearance(onNext: _next),
      _Step2Lock(
        pwController: _pwController,
        pwConfirmController: _pwConfirmController,
        pwVisible: _pwVisible,
        pwError: _pwError,
        settingUp: _settingUp,
        shake: _shake,
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
    ];
    return Scaffold(
      backgroundColor: colors.bg,
      // resizeToAvoidBottomInset: true keeps Scaffold from blocking keyboard,
      // but we handle overflow ourselves via SingleChildScrollView in each step.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // Progress indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl,
                    AppSpace.lg,
                    AppSpace.xl,
                    AppSpace.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP ${_step + 1} OF 3',
                        style: AppTypography.overline.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Row(
                        children: List.generate(
                          3,
                          (i) => Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.only(
                                right: i < 2 ? AppSpace.xs + 2 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceAlt,
                                borderRadius: AppRadius.brPill,
                              ),
                              alignment: Alignment.centerLeft,
                              child: AnimatedFractionallySizedBox(
                                duration: d,
                                curve: AppCurves.emphasized,
                                widthFactor: i <= _step ? 1 : 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.brand,
                                    borderRadius: AppRadius.brPill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageTransitionSwitcher(
                    duration: d == Duration.zero
                        ? const Duration(milliseconds: 1)
                        : AppDurations.pageTransition,
                    transitionBuilder: (child, primary, secondary) =>
                        SharedAxisTransition(
                          animation: primary,
                          secondaryAnimation: secondary,
                          transitionType: SharedAxisTransitionType.horizontal,
                          fillColor: colors.bg,
                          child: child,
                        ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: steps[_step],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pwFail(String message) {
    setState(() => _pwError = message);
    _shake.shake();
    ref.read(hapticsProvider).error();
  }

  Future<void> _handlePasswordSetup() async {
    final pw = _pwController.text;
    final confirm = _pwConfirmController.text;
    if (pw.length < 10) {
      _pwFail('Password must be at least 10 characters');
      return;
    }
    if (pw != confirm) {
      _pwFail('Passwords do not match');
      return;
    }
    final strength = PasswordStrength.estimate(pw);
    if (!strength.acceptable) {
      _pwFail(
        'Too easy to guess (${strength.label.toLowerCase()}, cracked in '
        '${strength.crackTimeLabel}). Add more words or characters.',
      );
      return;
    }
    setState(() {
      _settingUp = true;
      _pwError = null;
    });
    try {
      final rk = await ref.read(onboardingServiceProvider).setupPassword(pw);
      final hex = rk
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
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
      setState(() {
        _pwError = 'Setup failed: $e';
        _settingUp = false;
      });
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

// ── Shared step layout ────────────────────────────────────────────────────────

/// Scrollable step body with a pinned primary action at the bottom.
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.action,
    this.leading,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget action;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              0,
              AppSpace.xl,
              AppSpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(height: AppSpace.lg),
                ],
                Text(title, style: context.text.displayMedium),
                const SizedBox(height: AppSpace.sm),
                Text(
                  subtitle,
                  style: context.text.bodyLarge!.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),
                ...children,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.sm,
            AppSpace.xl,
            AppSpace.xl,
          ),
          child: SizedBox(width: double.infinity, child: action),
        ),
      ],
    );
  }
}

Widget _buttonSpinner(BuildContext context) => SizedBox(
  height: 20,
  width: 20,
  child: CircularProgressIndicator(
    strokeWidth: 2,
    color: context.colors.textMuted,
  ),
);

// ── Step 1: Appearance ────────────────────────────────────────────────────────

class _Step1Appearance extends ConsumerWidget {
  const _Step1Appearance({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return _StepLayout(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/icon.png',
          width: 56,
          height: 56,
          semanticLabel: Brand.appName,
        ),
      ),
      title: 'Welcome to ${Brand.appName}',
      subtitle:
          '${Brand.tagline}\nPrivate by design. Choose a look to get started; you can change it any time.',
      action: FilledButton(onPressed: onNext, child: const Text('Continue')),
      children: [
        _ThemeOption(
          label: 'Light',
          icon: AppIcons.lightModeOutlined,
          mode: ThemeMode.light,
          selected: mode == ThemeMode.light,
        ),
        const SizedBox(height: AppSpace.md),
        _ThemeOption(
          label: 'Dark',
          icon: AppIcons.darkModeOutlined,
          mode: ThemeMode.dark,
          selected: mode == ThemeMode.dark,
        ),
        const SizedBox(height: AppSpace.md),
        _ThemeOption(
          label: 'Follow system',
          icon: AppIcons.brightnessAutoOutlined,
          mode: ThemeMode.system,
          selected: mode == ThemeMode.system,
        ),
      ],
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.mode,
    required this.selected,
  });
  final String label;
  final IconData icon;
  final ThemeMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final d = resolvedDuration(context, AppDurations.base);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          ref.read(hapticsProvider).selection();
          ref.read(themeModeProvider.notifier).set(mode);
        },
        child: AnimatedContainer(
          duration: d,
          curve: AppCurves.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.lg,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.brandSubtle : colors.surface,
            border: Border.all(
              color: selected ? colors.brand : colors.outline,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: AppRadius.brLg,
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? colors.brandText : colors.textMuted),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: context.text.titleSmall!.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: d,
                curve: AppCurves.overshoot,
                child: Icon(
                  AppIcons.checkCircleOutlined,
                  color: colors.brandText,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
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
    required this.shake,
    required this.onToggleVisible,
    required this.onNext,
  });
  final ShakeController shake;
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
      if (mounted) {
        setState(() => _biometricAvailable = canCheck && isSupported);
      }
    } catch (_) {
      // Device doesn't support biometrics — hide the option.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final d = resolvedDuration(context, AppDurations.base);
    return _StepLayout(
      title: 'Protect your data',
      subtitle: 'Your password encrypts everything on this device. It never leaves it, so choose something memorable.',
      action: FilledButton(
        onPressed: widget.settingUp ? null : widget.onNext,
        child: widget.settingUp
            ? _buttonSpinner(context)
            : const Text('Set password & continue'),
      ),
      children: [
        Shake(
          controller: widget.shake,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: widget.pwController,
                obscureText: !widget.pwVisible,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(AppIcons.password),
                  suffixIcon: IconButton(
                    tooltip: widget.pwVisible
                        ? 'Hide password'
                        : 'Show password',
                    icon: Icon(
                      widget.pwVisible
                          ? AppIcons.visibility
                          : AppIcons.visibilityOff,
                    ),
                    onPressed: widget.onToggleVisible,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              PasswordStrengthMeter(password: widget.pwController.text),
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: widget.pwConfirmController,
                obscureText: !widget.pwVisible,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => widget.onNext(),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(AppIcons.lockReset),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: d,
          curve: AppCurves.standard,
          child: widget.pwError == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpace.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.pwError!,
                      style: context.text.bodySmall!.copyWith(
                        color: colors.danger,
                      ),
                    ),
                  ),
                ),
        ),
        if (_biometricAvailable) ...[
          const SizedBox(height: AppSpace.xl),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.brLg,
              border: Border.all(color: colors.outline),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.xs,
              ),
              value: biometricEnabled,
              onChanged: (v) =>
                  ref.read(biometricEnabledProvider.notifier).set(v),
              title: Text(
                'Enable biometric unlock',
                style: context.text.titleSmall,
              ),
              subtitle: Text(
                'Use fingerprint or face unlock after your password is set.',
                style: context.text.bodySmall,
              ),
              secondary: Icon(AppIcons.biometric, color: colors.brandText),
            ),
          ),
        ],
      ],
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
    return _StepLayout(
      title: 'Save your recovery key',
      subtitle: 'If you forget your password, this key is the only way back in. Write it down and keep it somewhere safe.',
      action: FilledButton(
        onPressed: (savedConfirmed && !finishing) ? onFinish : null,
        child: finishing
            ? _buttonSpinner(context)
            : const Text("I'm ready — let's go"),
      ),
      children: [
        if (recoveryKey != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.brLg,
              border: Border.all(color: colors.brand.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.recoveryKey,
                      size: AppSizes.iconMd,
                      color: colors.brandText,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        'RECOVERY KEY',
                        style: AppTypography.overline.copyWith(
                          color: colors.brandText,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: recoveryKey!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recovery key copied'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(AppIcons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: SelectableText(
                    recoveryKey!,
                    style: AppTypography.mono.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                      letterSpacing: 1.5,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        Container(
          decoration: BoxDecoration(
            color: savedConfirmed ? colors.successSubtle : colors.surface,
            borderRadius: AppRadius.brLg,
            border: Border.all(
              color: savedConfirmed
                  ? colors.success.withValues(alpha: 0.5)
                  : colors.outline,
            ),
          ),
          child: CheckboxListTile(
            value: savedConfirmed,
            onChanged: (v) => onConfirm(v ?? false),
            title: Text(
              'I have written down my recovery key',
              style: context.text.titleSmall,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }
}
