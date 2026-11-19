import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:streakin/core/notifications/notification_reconciler.dart'
    show showTestNotification, openNotificationSettings;

import 'package:streakin/app/brand.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/platform/startup_registration.dart';
import 'package:streakin/core/platform/tray_service.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';
import 'package:streakin/shared/widgets/widgets.dart';

// ── Settings root ─────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(profileProvider);
    final initials = _initials(profile.name, profile.username);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ReadableListView(
        children: [
          // ── Profile header ───────────────────────────────────────────────
          AppCard(
            onTap: () => context.push('/settings/profile'),
            semanticLabel: 'Edit profile',
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.brand,
                  child: Text(
                    initials,
                    style: context.text.titleMedium!.copyWith(
                      color: colors.onBrand,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name.isEmpty ? 'Set your name' : profile.name,
                        style: context.text.titleMedium!.copyWith(
                          color: profile.name.isEmpty
                              ? colors.textMuted
                              : colors.text,
                        ),
                      ),
                      if (profile.username.isNotEmpty)
                        Text(
                          '@${profile.username}',
                          style: context.text.bodySmall,
                        ),
                      if (profile.bio.isNotEmpty)
                        Text(
                          profile.bio,
                          style: context.text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight, color: colors.textMuted),
              ],
            ),
          ),

          SettingsGroup(
            title: 'Personalisation',
            children: [
              SettingsTile.nav(
                icon: AppIcons.paletteOutlined,
                title: 'Appearance',
                subtitle: 'Theme & display',
                onTap: () => context.push('/settings/appearance'),
              ),
              SettingsTile.nav(
                icon: AppIcons.notification,
                title: 'Notifications',
                subtitle: 'Permissions & preferences',
                onTap: () => context.push('/settings/notifications'),
              ),
            ],
          ),

          SettingsGroup(
            title: 'Security',
            children: [
              SettingsTile.nav(
                icon: AppIcons.biometric,
                title: 'Biometric unlock',
                subtitle: 'Face ID, fingerprint',
                onTap: () => context.push('/settings/biometric'),
              ),
              SettingsTile.nav(
                icon: AppIcons.lock,
                title: 'Auto-lock',
                subtitle: 'Timeout & behaviour',
                onTap: () => context.push('/settings/autolock'),
              ),
              SettingsTile.nav(
                icon: AppIcons.shieldOutlined,
                title: 'Security',
                subtitle: 'Password, vaults, recovery key',
                onTap: () => context.push('/settings/security'),
              ),
              SettingsTile.nav(
                icon: AppIcons.storageOutlined,
                title: 'Data',
                subtitle: 'Storage, export & import, erase',
                onTap: () => context.push('/settings/data'),
              ),
            ],
          ),

          SettingsGroup(
            title: 'Goals',
            children: [
              SettingsTile.nav(
                icon: AppIcons.trackChangesOutlined,
                title: 'Goal reminders',
                subtitle: 'Cadence, time & content',
                onTap: () => context.push('/settings/goal-reminders'),
              ),
            ],
          ),

          SettingsGroup(
            title: 'General',
            children: [
              SettingsTile.nav(
                icon: AppIcons.calendarTodayOutlined,
                title: 'Week & day',
                subtitle: 'Week start, day boundary',
                onTap: () => context.push('/settings/week-day'),
              ),
              if (Platform.isWindows || Platform.isLinux)
                SettingsTile.nav(
                  icon: AppIcons.keyboardOutlined,
                  title: 'Keyboard shortcuts',
                  onTap: () => context.push('/settings/shortcuts'),
                ),
              SettingsTile.nav(
                icon: AppIcons.accessibilityNewOutlined,
                title: 'Accessibility',
                subtitle: 'Motion & haptics',
                onTap: () => context.push('/settings/accessibility'),
              ),
            ],
          ),

          SettingsGroup(
            title: 'Support',
            children: [
              _ExternalTile(
                icon: AppIcons.mailOutline,
                title: 'Contact us',
                onTap: () => _launchUrl('mailto:hello@incantum.in'),
              ),
              _ExternalTile(
                icon: AppIcons.descriptionOutlined,
                title: 'Terms of Service',
                onTap: () => _launchUrl('https://incantum.in/terms'),
              ),
              _ExternalTile(
                icon: AppIcons.privacyTipOutlined,
                title: 'Privacy Policy',
                onTap: () => _launchUrl('https://incantum.in/privacy'),
              ),
              _ExternalTile(
                icon: AppIcons.habitDefault,
                title: 'Rate the app',
                onTap: () => _launchUrl(
                  'https://play.google.com/store/apps/details?id=in.incantum.streakin.individual',
                ),
              ),
            ],
          ),

          // ── About ─────────────────────────────────────────────────────────
          const _AboutRow(),
        ],
      ),
    );
  }

  String _initials(String name, String username) {
    final src = name.isNotEmpty ? name : username;
    if (src.isEmpty) return '?';
    final parts = src.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return src[0].toUpperCase();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ── Profile page ──────────────────────────────────────────────────────────────

class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});
  @override
  ConsumerState<ProfileSettingsPage> createState() =>
      _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _nameCtrl = TextEditingController(text: p.name);
    _usernameCtrl = TextEditingController(text: p.username);
    _bioCtrl = TextEditingController(text: p.bio);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: ReadableListView(
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colors.brand,
                  child: Consumer(
                    builder: (_, ref, _) {
                      final p = ref.watch(profileProvider);
                      final name = _nameCtrl.text.isNotEmpty
                          ? _nameCtrl.text
                          : p.username;
                      final initials = name.isEmpty
                          ? '?'
                          : name[0].toUpperCase();
                      return Text(
                        initials,
                        style: context.text.headlineLarge!.copyWith(
                          color: colors.onBrand,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          _Field(
            controller: _nameCtrl,
            label: 'Name',
            hint: 'Your display name',
            maxLength: 50,
            colors: colors,
          ),
          const SizedBox(height: AppSpace.lg),
          _Field(
            controller: _usernameCtrl,
            label: 'Username',
            hint: 'e.g. john_doe',
            maxLength: 30,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            ],
            colors: colors,
            prefix: '@',
          ),
          const SizedBox(height: AppSpace.lg),
          _Field(
            controller: _bioCtrl,
            label: 'Bio',
            hint: 'Optional — a line about you',
            maxLength: 140,
            maxLines: 3,
            colors: colors,
            required: false,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(profileProvider.notifier)
        .save(
          name: _nameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          bio: _bioCtrl.text.trim(),
        );
    if (mounted) {
      setState(() => _saving = false);
      context.pop();
    }
  }
}

// ── Appearance page ───────────────────────────────────────────────────────────

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Appearance')),
      body: ReadableListView(
        children: [
          const SectionHeader('Theme'),
          Row(
            children: [
              for (final e in {
                ThemeMode.light: ('Light', AppIcons.lightModeOutlined),
                ThemeMode.system: ('System', AppIcons.brightnessAutoOutlined),
                ThemeMode.dark: ('Dark', AppIcons.darkModeOutlined),
              }.entries) ...[
                if (e.key != ThemeMode.light)
                  const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ThemePreviewCard(
                    label: e.value.$1,
                    icon: e.value.$2,
                    mode: e.key,
                    selected: themeMode == e.key,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).set(e.key),
                  ),
                ),
              ],
            ],
          ),
          const _MotionFeedbackGroup(),
        ],
      ),
    );
  }
}

/// Mini mock of the app in the given theme.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.label,
    required this.icon,
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const light = AppColorTokens.light;
    const dark = AppColorTokens.dark;
    Widget pane(AppColorTokens t) => Container(
      color: t.bg,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 8,
            width: 28,
            decoration: BoxDecoration(
              color: t.brand,
              borderRadius: AppRadius.brPill,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          for (var i = 0; i < 2; i++) ...[
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: AppRadius.brXs,
                border: Border.all(color: t.outline),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
          ],
        ],
      ),
    );
    final preview = switch (mode) {
      ThemeMode.light => pane(light),
      ThemeMode.dark => pane(dark),
      ThemeMode.system => Row(
        children: [
          Expanded(child: pane(light)),
          Expanded(child: pane(dark)),
        ],
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.sm),
        borderColor: selected ? c.brand : null,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: AppRadius.brSm,
              child: SizedBox(height: 72, child: preview),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? AppIcons.checkCircleOutlined : icon,
                  size: 16,
                  color: selected ? c.brandText : c.textMuted,
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  label,
                  style: context.text.labelLarge!.copyWith(
                    color: selected ? c.brandText : c.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reduce motion + haptics (shown on Appearance and Accessibility pages).
class _MotionFeedbackGroup extends ConsumerWidget {
  const _MotionFeedbackGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced = ref.watch(reducedMotionProvider);
    final haptics = ref.watch(hapticsEnabledProvider);
    return SettingsGroup(
      title: 'Motion & feedback',
      footer: 'Reduce motion also follows your system accessibility setting.',
      children: [
        SettingsTile.toggle(
          icon: AppIcons.animationOutlined,
          title: 'Reduce motion',
          subtitle: 'Fewer animations & transitions',
          value: reduced,
          onChanged: (v) => ref.read(reducedMotionProvider.notifier).set(v),
        ),
        SettingsTile.toggle(
          icon: AppIcons.devices,
          title: 'Haptics',
          subtitle: 'Vibration feedback on taps and wins',
          value: haptics,
          onChanged: (v) => ref.read(hapticsEnabledProvider.notifier).set(v),
        ),
      ],
    );
  }
}

// ── Notifications page ────────────────────────────────────────────────────────

/// Desktop shortcut reference (Spec §5.7).
class KeyboardShortcutsPage extends StatelessWidget {
  const KeyboardShortcutsPage({super.key});

  static const rows = <(String, String)>[
    ('Ctrl+N', 'New note'),
    ('Ctrl+T', 'New task'),
    ('Ctrl+K', 'Search notes'),
    ('Ctrl+L', 'Lock the app'),
    ('Ctrl+/', 'Slash menu (editor)'),
    ('Ctrl+B / I / U', 'Bold / italic / underline (editor)'),
    ('Ctrl+Z / Ctrl+Shift+Z', 'Undo / redo (editor)'),
    ('F11', 'Toggle fullscreen'),
    ('Esc', 'Close dialog / exit Zen'),
    ('Tab / Shift+Tab', 'Move focus'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Keyboard shortcuts')),
      body: ReadableListView(
        children: [
          SettingsGroup(
            children: [
              for (final r in rows)
                SettingsTile(
                  title: r.$2,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: AppSpace.xxs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: AppRadius.brXs,
                      border: Border.all(color: colors.outline),
                    ),
                    child: Text(
                      r.$1,
                      style: AppTypography.mono.copyWith(
                        fontSize: 12,
                        color: colors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationsSettingsPage extends ConsumerWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Notifications')),
      body: ReadableListView(
        children: [
          SettingsGroup(
            title: 'System',
            children: [
              const SettingsTile(
                icon: AppIcons.notification,
                title: 'Notification permission',
                subtitle: 'Manage in Android Settings → Apps → Streakin → Notifications',
                trailing: FilledButton.tonal(
                  onPressed: openNotificationSettings,
                  child: Text('Open'),
                ),
              ),
              SettingsTile(
                icon: AppIcons.notificationAddOutlined,
                title: 'Test notification',
                subtitle: 'Send a notification right now to check it works',
                trailing: FilledButton.tonal(
                  onPressed: () => _sendTest(context),
                  child: const Text('Send'),
                ),
              ),
              if (StartupRegistration.supported) const _TrayToggle(),
            ],
          ),
          SettingsGroup(
            title: 'Reminders',
            children: [
              SettingsTile.toggle(
                icon: AppIcons.habits,
                title: 'Habit reminders',
                subtitle: 'Set per habit in Habits → Edit',
                value: ref.watch(notifHabitsEnabledProvider),
                onChanged: (v) =>
                    ref.read(notifHabitsEnabledProvider.notifier).set(v),
              ),
              SettingsTile.toggle(
                icon: AppIcons.lockClockOutlined,
                title: 'Evening lock-in nudge',
                subtitle: 'A reminder if habits are still open',
                value: ref.watch(notifLockInNudgeEnabledProvider),
                onChanged: (v) =>
                    ref.read(notifLockInNudgeEnabledProvider.notifier).set(v),
              ),
              SettingsTile.toggle(
                icon: AppIcons.alternateEmail,
                title: 'Note @date reminders',
                value: ref.watch(notifMentionsEnabledProvider),
                onChanged: (v) =>
                    ref.read(notifMentionsEnabledProvider.notifier).set(v),
              ),
              SettingsTile.nav(
                icon: AppIcons.trackChangesOutlined,
                title: 'Goal countdown reminders',
                onTap: () => context.push('/settings/goal-reminders'),
              ),
              SettingsTile.toggle(
                icon: AppIcons.checklistOutlined,
                title: 'Task reminders',
                subtitle: 'Set per task in Tasks → Edit',
                value: ref.watch(notifTodosEnabledProvider),
                onChanged: (v) =>
                    ref.read(notifTodosEnabledProvider.notifier).set(v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendTest(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    bool ok;
    try {
      ok = await showTestNotification();
    } catch (_) {
      ok = false;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Test notification sent'
              : 'Notifications are blocked. Tap Open to enable them.',
        ),
      ),
    );
  }
}

class _TrayToggle extends StatefulWidget {
  const _TrayToggle();

  @override
  State<_TrayToggle> createState() => _TrayToggleState();
}

class _TrayToggleState extends State<_TrayToggle> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    StartupRegistration.isEnabled().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile.toggle(
      icon: AppIcons.inboxOutlined,
      title: 'Keep running in tray for reminders',
      subtitle: 'Starts with your computer; data stays locked',
      value: _on,
      onChanged: (v) async {
        await StartupRegistration.setEnabled(v);
        TrayService.instance.keepInTray = v;
        if (mounted) setState(() => _on = v);
      },
    );
  }
}

// ── Biometric page ────────────────────────────────────────────────────────────

class BiometricSettingsPage extends ConsumerWidget {
  const BiometricSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final enabled = ref.watch(biometricEnabledProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Biometric unlock')),
      body: FutureBuilder<bool>(
        future: _checkAvailable(),
        builder: (_, snap) {
          final available = snap.data ?? false;
          return ReadableListView(
            children: [
              if (!available && snap.connectionState == ConnectionState.done)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.lg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: colors.warningSubtle,
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.warningAmberOutlined,
                          color: colors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            'No biometric hardware found or not enrolled. Enrol in Android Settings → Security.',
                            style: context.text.bodySmall!.copyWith(
                              color: colors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SettingsGroup(
                title: 'Unlock method',
                footer: 'Your password is always available as a fallback.',
                children: [
                  SettingsTile.toggle(
                    icon: AppIcons.biometric,
                    title: 'Unlock with biometrics',
                    subtitle: 'Use face or fingerprint instead of password',
                    value: enabled,
                    enabled: available,
                    onChanged: available
                        ? (v) =>
                              ref.read(biometricEnabledProvider.notifier).set(v)
                        : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _checkAvailable() async {
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}

// ── Auto-lock page ────────────────────────────────────────────────────────────

class AutoLockSettingsPage extends ConsumerWidget {
  const AutoLockSettingsPage({super.key});

  static const _options = [
    (Duration(minutes: 1), 'After 1 minute'),
    (Duration(minutes: 5), 'After 5 minutes'),
    (Duration(minutes: 15), 'After 15 minutes'),
    (Duration(minutes: 30), 'After 30 minutes'),
    (Duration(hours: 1), 'After 1 hour'),
    (Duration(days: 999), 'Never'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // Read current timeout from LockController — default 5 min
    // We show the closest match and persist via SharedPreferences
    final currentMinutes = ref.watch(_lockTimeoutMinutesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Auto-lock')),
      body: ReadableListView(
        children: [
          RadioGroup<int>(
            groupValue: currentMinutes,
            onChanged: (v) =>
                ref.read(_lockTimeoutMinutesProvider.notifier).set(v!),
            child: SettingsGroup(
              title: 'Lock after inactivity',
              footer: 'The app locks when moved to the background for longer than this duration.',
              children: [
                for (final opt in _options)
                  RadioListTile<int>(
                    value: opt.$1.inDays > 1 ? 99999 : opt.$1.inMinutes,
                    title: Text(opt.$2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _lockTimeoutMinutesProvider = NotifierProvider<_LockTimeoutNotifier, int>(
  _LockTimeoutNotifier.new,
);

class _LockTimeoutNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 5;
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getInt('core.lock_timeout_minutes') ?? 5;
  }

  Future<void> set(int minutes) async {
    state = minutes;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt('core.lock_timeout_minutes', minutes);
    // Apply to the live LockController
    // (imported via lock_controller to avoid circular dep)
  }
}

// ── Week & Day page ───────────────────────────────────────────────────────────

class WeekDaySettingsPage extends ConsumerWidget {
  const WeekDaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final weekStart = ref.watch(weekStartProvider);
    final boundaryMins = ref.watch(dayBoundaryMinutesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Week & day')),
      body: ReadableListView(
        children: [
          const SectionHeader('Week start'),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('Monday')),
              ButtonSegment(value: 7, label: Text('Sunday')),
            ],
            selected: {weekStart},
            onSelectionChanged: (v) =>
                ref.read(weekStartProvider.notifier).set(v.first),
          ),
          RadioGroup<int>(
            groupValue: boundaryMins,
            onChanged: (v) =>
                ref.read(dayBoundaryMinutesProvider.notifier).set(v!),
            child: SettingsGroup(
              title: 'Day boundary',
              footer: 'Days end at midnight by default. Shift the boundary if your nights run past midnight.',
              children: [
                for (final mins in [0, 60, 120, 180, 240])
                  RadioListTile<int>(
                    value: mins,
                    title: Text(
                      mins == 0
                          ? 'Midnight (00:00)'
                          : '0${mins ~/ 60}:00 (${mins ~/ 60}h after midnight)',
                    ),
                  ),
              ],
            ),
          ),
          SettingsGroup(
            title: 'Time',
            children: [
              SettingsTile.toggle(
                icon: AppIcons.scheduleOutlined,
                title: '24-hour time',
                value: ref.watch(timeFormat24hProvider),
                onChanged: (v) =>
                    ref.read(timeFormat24hProvider.notifier).set(v),
              ),
              SettingsTile.nav(
                icon: AppIcons.timerOutlined,
                title: 'Default reminder time',
                subtitle: 'Used for all-day items',
                trailing: Text(
                  _fmtMinutes(ref.watch(defaultReminderMinutesProvider)),
                  style: context.text.labelLarge!.copyWith(
                    color: colors.brandText,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                onTap: () async {
                  final cur = ref.read(defaultReminderMinutesProvider);
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
                  );
                  if (picked != null) {
                    await ref
                        .read(defaultReminderMinutesProvider.notifier)
                        .set(picked.hour * 60 + picked.minute);
                  }
                },
              ),
            ],
          ),
          SettingsGroup(
            title: 'Lock-in',
            children: [
              SettingsTile.toggle(
                icon: AppIcons.lockFill,
                title: 'Count to-dos for lock-in',
                subtitle: 'Flagged tasks due today must be done before the day locks in',
                value: ref.watch(countTodosForLockInProvider),
                onChanged: (v) =>
                    ref.read(countTodosForLockInProvider.notifier).set(v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtMinutes(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

// ── Accessibility page ────────────────────────────────────────────────────────

class AccessibilitySettingsPage extends ConsumerWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Accessibility')),
      body: const ReadableListView(children: [_MotionFeedbackGroup()]),
    );
  }
}

// ── Goal reminders page (stub wiring) ────────────────────────────────────────

class GoalRemindersSettingsPage extends ConsumerWidget {
  const GoalRemindersSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final cadence = ref.watch(_goalCadenceProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Goal reminders')),
      body: ReadableListView(
        children: [
          RadioGroup<String>(
            groupValue: cadence,
            onChanged: (v) => ref.read(_goalCadenceProvider.notifier).set(v!),
            child: SettingsGroup(
              title: 'Reminder cadence',
              children: [
                for (final opt in const [
                  ('off', 'Off'),
                  ('daily', 'Daily'),
                  ('every2', 'Every 2 days'),
                  ('every3', 'Every 3 days'),
                  ('every5', 'Every 5 days'),
                  ('weekly', 'Weekly'),
                  ('milestones_only', 'Milestones only'),
                ])
                  _GoalReminderCadenceTile(value: opt.$1, label: opt.$2),
              ],
            ),
          ),
          const SettingsGroup(
            title: 'Options',
            children: [
              _GoalReminderToggle(
                prefKey: AppIdentifiers.prefGoalFinalStretch,
                label: 'Daily during final 7 days',
                icon: AppIcons.timerOutlined,
              ),
              _GoalReminderToggle(
                prefKey: AppIdentifiers.prefGoalMilestoneAlerts,
                label: 'Milestone alerts',
                icon: AppIcons.milestone,
              ),
              _GoalReminderToggle(
                prefKey: AppIdentifiers.prefGoalCompletionAlert,
                label: 'Completion alert',
                icon: AppIcons.checkCircleOutlined,
              ),
              _GoalReminderToggle(
                prefKey: AppIdentifiers.prefGoalSuppressIfDone,
                label: 'Skip if all habits done today',
                icon: AppIcons.doNotDisturbAltOutlined,
              ),
              _GoalReminderToggle(
                prefKey: AppIdentifiers.prefGoalShowTitle,
                label: 'Show goal title in notification',
                icon: AppIcons.titleOutlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalReminderCadenceTile extends StatelessWidget {
  const _GoalReminderCadenceTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(value: value, title: Text(label));
  }
}

final _goalCadenceProvider = NotifierProvider<_GoalCadenceNotifier, String>(
  _GoalCadenceNotifier.new,
);

class _GoalCadenceNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'daily';
  }

  Future<void> _load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getString(AppIdentifiers.prefGoalReminderCadence) ?? 'daily';
  }

  Future<void> set(String v) async {
    state = v;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(AppIdentifiers.prefGoalReminderCadence, v);
  }
}

class _GoalReminderToggle extends StatefulWidget {
  const _GoalReminderToggle({
    required this.prefKey,
    required this.label,
    required this.icon,
  });
  final String prefKey;
  final String label;
  final IconData icon;

  @override
  State<_GoalReminderToggle> createState() => _GoalReminderToggleState();
}

class _GoalReminderToggleState extends State<_GoalReminderToggle> {
  bool _val = true;

  @override
  void initState() {
    super.initState();
    _load().then((v) {
      if (mounted) setState(() => _val = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile.toggle(
      icon: widget.icon,
      title: widget.label,
      value: _val,
      onChanged: (v) {
        setState(() => _val = v);
        _save(v);
      },
    );
  }

  Future<bool> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(widget.prefKey) ?? true;
  }

  Future<void> _save(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.prefKey, v);
  }
}

// ── About row ─────────────────────────────────────────────────────────────────

class _AboutRow extends ConsumerWidget {
  const _AboutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      title: 'About',
      children: [
        _ExternalTile(
          icon: AppIcons.helpOutline,
          title: 'FAQ',
          onTap: () => _launch('https://incantum.in/faq'),
        ),
        SettingsTile.nav(
          icon: AppIcons.infoOutline,
          title: 'About ${Brand.appName}',
          onTap: () => context.push('/settings/about'),
        ),
        const SettingsTile(
          icon: AppIcons.newReleasesOutlined,
          title: 'App version',
          trailing: _VersionBadge(),
        ),
      ],
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StatusPill('1.0.0-alpha', color: colors.brand);
  }
}

// ── About page ────────────────────────────────────────────────────────────────

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('About')),
      body: ReadableListView(
        children: [
          const SizedBox(height: AppSpace.xl),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/icon.png', width: 88, height: 88),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Center(child: Text(Brand.appName, style: context.text.displaySmall)),
          const SizedBox(height: AppSpace.xs),
          const Center(child: _VersionBadge()),
          const SizedBox(height: AppSpace.xl),
          Text(
            'A private, calm, beautiful place to build habits and think in notes.',
            style: context.text.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xl),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              StatusPill('No telemetry', icon: AppIcons.shieldOutlined),
              StatusPill('No cloud', icon: AppIcons.lock),
              StatusPill('Encrypted', icon: AppIcons.vault),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Center(
            child: Text(
              'Built by ${Brand.companyName} · Your data stays yours',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

/// Row that opens an external link.
class _ExternalTile extends StatelessWidget {
  const _ExternalTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      onTap: onTap,
      trailing: Icon(
        AppIcons.openInNew,
        size: AppSizes.iconSm,
        color: context.colors.textMuted,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    required this.colors,
    this.maxLines = 1,
    this.inputFormatters,
    this.prefix,
    this.required = true,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final AppColorTokens colors;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefix;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: context.text.labelLarge!.copyWith(color: colors.textMuted),
            ),
            if (!required) Text(' (optional)', style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixText: prefix,
          ),
        ),
      ],
    );
  }
}
