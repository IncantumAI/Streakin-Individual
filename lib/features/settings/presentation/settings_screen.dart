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

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/platform/startup_registration.dart';
import 'package:streakin/core/platform/tray_service.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';

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
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          // ── Profile header ───────────────────────────────────────────────
          InkWell(
            onTap: () => context.push('/settings/profile'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              color: colors.surface,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.brand,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: colors.onBrand,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.isEmpty ? 'Set your name' : profile.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: profile.name.isEmpty
                                ? colors.textMuted
                                : colors.text,
                          ),
                        ),
                        if (profile.username.isNotEmpty)
                          Text(
                            '@${profile.username}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textMuted,
                            ),
                          ),
                        if (profile.bio.isNotEmpty)
                          Text(
                            profile.bio,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
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
          ),
          const SizedBox(height: 8),
          Divider(color: colors.outline, height: 1),

          // ── Personalisation ──────────────────────────────────────────────
          _SectionHeader('Personalisation', colors: colors),
          _SettingsTile(
            icon: AppIcons.paletteOutlined,
            label: 'Appearance',
            subtitle: 'Theme & display',
            onTap: () => context.push('/settings/appearance'),
            colors: colors,
          ),
          _SettingsTile(
            icon: AppIcons.notification,
            label: 'Notifications',
            subtitle: 'Permissions & preferences',
            onTap: () => context.push('/settings/notifications'),
            colors: colors,
          ),

          // ── Security ─────────────────────────────────────────────────────
          _SectionHeader('Security', colors: colors),
          _SettingsTile(
            icon: AppIcons.biometric,
            label: 'Biometric Unlock',
            subtitle: 'Face ID, fingerprint',
            onTap: () => context.push('/settings/biometric'),
            colors: colors,
          ),
          _SettingsTile(
            icon: AppIcons.lock,
            label: 'Auto-lock',
            subtitle: 'Timeout & behaviour',
            onTap: () => context.push('/settings/autolock'),
            colors: colors,
          ),
          _SettingsTile(
            icon: AppIcons.shieldOutlined,
            label: 'Security',
            subtitle: 'Password, vaults, recovery key',
            onTap: () => context.push('/settings/security'),
            colors: colors,
          ),
          _SettingsTile(
            icon: AppIcons.storageOutlined,
            label: 'Data',
            subtitle: 'Storage, export & import, erase',
            onTap: () => context.push('/settings/data'),
            colors: colors,
          ),

          // ── Goals ─────────────────────────────────────────────────────────
          _SectionHeader('Goals', colors: colors),
          _SettingsTile(
            icon: AppIcons.trackChangesOutlined,
            label: 'Goal Reminders',
            subtitle: 'Cadence, time & content',
            onTap: () => context.push('/settings/goal-reminders'),
            colors: colors,
          ),

          // ── General ──────────────────────────────────────────────────────
          _SectionHeader('General', colors: colors),
          _SettingsTile(
            icon: AppIcons.calendarTodayOutlined,
            label: 'Week & Day',
            subtitle: 'Week start, day boundary',
            onTap: () => context.push('/settings/week-day'),
            colors: colors,
          ),
          if (Platform.isWindows || Platform.isLinux)
            _SettingsTile(
              icon: AppIcons.keyboardOutlined,
              label: 'Keyboard shortcuts',
              onTap: () => context.push('/settings/shortcuts'),
              colors: colors,
            ),
          _SettingsTile(
            icon: AppIcons.accessibilityNewOutlined,
            label: 'Accessibility',
            subtitle: 'Motion & haptics',
            onTap: () => context.push('/settings/accessibility'),
            colors: colors,
          ),

          // ── Support ──────────────────────────────────────────────────────
          _SectionHeader('Support', colors: colors),
          _SettingsTile(
            icon: AppIcons.mailOutline,
            label: 'Contact Us',
            onTap: () => _launchUrl('mailto:hello@incantum.in'),
            colors: colors,
            showChevron: false,
            trailingIcon: AppIcons.openInNew,
          ),
          _SettingsTile(
            icon: AppIcons.descriptionOutlined,
            label: 'Terms of Service',
            onTap: () => _launchUrl('https://incantum.in/terms'),
            colors: colors,
            showChevron: false,
            trailingIcon: AppIcons.openInNew,
          ),
          _SettingsTile(
            icon: AppIcons.privacyTipOutlined,
            label: 'Privacy Policy',
            onTap: () => _launchUrl('https://incantum.in/privacy'),
            colors: colors,
            showChevron: false,
            trailingIcon: AppIcons.openInNew,
          ),
          _SettingsTile(
            icon: AppIcons.habitDefault,
            label: 'Rate the App',
            onTap: () => _launchUrl(
              'https://play.google.com/store/apps/details?id=in.incantum.streakin',
            ),
            colors: colors,
            showChevron: false,
            trailingIcon: AppIcons.openInNew,
          ),

          // ── About ─────────────────────────────────────────────────────────
          Divider(color: colors.outline, height: 1),
          _AboutRow(colors: colors),
          const SizedBox(height: 32),
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
        backgroundColor: colors.surface,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: colors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
                        style: TextStyle(
                          color: colors.onBrand,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Field(
            controller: _nameCtrl,
            label: 'Name',
            hint: 'Your display name',
            maxLength: 50,
            colors: colors,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
    final reduced = ref.watch(reducedMotionProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Appearance'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          _SectionHeader('Theme', colors: colors),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
            child: Column(
              children: [
                for (final e in {
                  ThemeMode.light: ('Light', AppIcons.lightModeOutlined),
                  ThemeMode.system: (
                    'System default',
                    AppIcons.brightnessAutoOutlined,
                  ),
                  ThemeMode.dark: ('Dark', AppIcons.darkModeOutlined),
                }.entries)
                  RadioListTile<ThemeMode>(
                    value: e.key,
                    activeColor: colors.brand,
                    secondary: Icon(e.value.$2, color: colors.brand),
                    title: Text(
                      e.value.$1,
                      style: TextStyle(color: colors.text),
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Motion', colors: colors),
          SwitchListTile.adaptive(
            value: reduced,
            onChanged: (v) => ref.read(reducedMotionProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            secondary: Icon(AppIcons.animationOutlined, color: colors.brand),
            title: Text('Reduce motion', style: TextStyle(color: colors.text)),
            subtitle: Text(
              'Fewer animations throughout the app',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: const Text('Keyboard shortcuts'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          for (final r in rows)
            ListTile(
              dense: true,
              title: Text(r.$2, style: TextStyle(color: colors.text)),
              trailing: Text(
                r.$1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: colors.textMuted,
                ),
              ),
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
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          _SectionHeader('System', colors: colors),
          ListTile(
            leading: Icon(AppIcons.notification, color: colors.brand),
            title: Text(
              'Notification Permission',
              style: TextStyle(color: colors.text),
            ),
            subtitle: Text(
              'Manage in Android Settings → Apps → Streakin → Notifications',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            trailing: const FilledButton.tonal(
              onPressed: openNotificationSettings,
              child: Text('Open'),
            ),
          ),
          ListTile(
            leading: Icon(
              AppIcons.notificationAddOutlined,
              color: colors.brand,
            ),
            title: Text(
              'Test notification',
              style: TextStyle(color: colors.text),
            ),
            subtitle: Text(
              'Send a notification right now to check it works',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            trailing: FilledButton.tonal(
              onPressed: () => _sendTest(context),
              child: const Text('Send'),
            ),
          ),
          if (StartupRegistration.supported) ...[
            Divider(color: colors.outline, height: 1),
            _TrayToggle(colors: colors),
          ],
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Reminders', colors: colors),
          SwitchListTile.adaptive(
            value: ref.watch(notifHabitsEnabledProvider),
            onChanged: (v) =>
                ref.read(notifHabitsEnabledProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            secondary: Icon(AppIcons.habits, color: colors.brand),
            title: Text(
              'Habit reminders',
              style: TextStyle(color: colors.text),
            ),
            subtitle: Text(
              'Set per habit in Habits → Edit',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          SwitchListTile.adaptive(
            value: ref.watch(notifLockInNudgeEnabledProvider),
            onChanged: (v) =>
                ref.read(notifLockInNudgeEnabledProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            secondary: Icon(AppIcons.lockClockOutlined, color: colors.brand),
            title: Text(
              'Evening lock-in nudge',
              style: TextStyle(color: colors.text),
            ),
            subtitle: Text(
              'A reminder if habits are still open',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          SwitchListTile.adaptive(
            value: ref.watch(notifMentionsEnabledProvider),
            onChanged: (v) =>
                ref.read(notifMentionsEnabledProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            secondary: Icon(AppIcons.alternateEmail, color: colors.brand),
            title: Text(
              'Note @date reminders',
              style: TextStyle(color: colors.text),
            ),
          ),
          ListTile(
            leading: Icon(AppIcons.trackChangesOutlined, color: colors.brand),
            title: Text(
              'Goal countdown reminders',
              style: TextStyle(color: colors.text),
            ),
            trailing: Icon(AppIcons.chevronRight, color: colors.textMuted),
            onTap: () => context.push('/settings/goal-reminders'),
          ),
          SwitchListTile.adaptive(
            value: ref.watch(notifTodosEnabledProvider),
            onChanged: (v) =>
                ref.read(notifTodosEnabledProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            secondary: Icon(AppIcons.checklistOutlined, color: colors.brand),
            title: Text('Task reminders', style: TextStyle(color: colors.text)),
            subtitle: Text(
              'Set per task in Tasks → Edit',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
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
  const _TrayToggle({required this.colors});
  final AppColorTokens colors;

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
    return SwitchListTile.adaptive(
      value: _on,
      onChanged: (v) async {
        await StartupRegistration.setEnabled(v);
        TrayService.instance.keepInTray = v;
        if (mounted) setState(() => _on = v);
      },
      activeThumbColor: widget.colors.brand,
      secondary: Icon(AppIcons.inboxOutlined, color: widget.colors.brand),
      title: Text(
        'Keep running in tray for reminders',
        style: TextStyle(color: widget.colors.text),
      ),
      subtitle: Text(
        'Starts with your computer; data stays locked',
        style: TextStyle(color: widget.colors.textMuted, fontSize: 12),
      ),
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
      appBar: AppBar(
        title: const Text('Biometric Unlock'),
        backgroundColor: colors.surface,
      ),
      body: FutureBuilder<bool>(
        future: _checkAvailable(),
        builder: (_, snap) {
          final available = snap.data ?? false;
          return ListView(
            children: [
              _SectionHeader('Unlock Method', colors: colors),
              if (!available)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.warning.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.warningAmberOutlined,
                          color: colors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No biometric hardware found or not enrolled. Enrol in Android Settings → Security.',
                            style: TextStyle(fontSize: 13, color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SwitchListTile.adaptive(
                value: enabled,
                onChanged: available
                    ? (v) => ref.read(biometricEnabledProvider.notifier).set(v)
                    : null,
                activeThumbColor: colors.brand,
                secondary: Icon(AppIcons.biometric, color: colors.brand),
                title: Text(
                  'Unlock with biometrics',
                  style: TextStyle(color: colors.text),
                ),
                subtitle: Text(
                  'Use face or fingerprint instead of password',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
              Divider(color: colors.outline, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Your password is always available as a fallback.',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
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
      appBar: AppBar(
        title: const Text('Auto-lock'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          _SectionHeader('Lock after inactivity', colors: colors),
          RadioGroup<int>(
            groupValue: currentMinutes,
            onChanged: (v) =>
                ref.read(_lockTimeoutMinutesProvider.notifier).set(v!),
            child: Column(
              children: [
                for (final opt in _options)
                  RadioListTile<int>(
                    value: opt.$1.inDays > 1 ? 99999 : opt.$1.inMinutes,
                    activeColor: colors.brand,
                    title: Text(opt.$2, style: TextStyle(color: colors.text)),
                  ),
              ],
            ),
          ),
          Divider(color: colors.outline, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'The app locks when moved to the background for longer than this duration.',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
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
      appBar: AppBar(
        title: const Text('Week & Day'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          _SectionHeader('Week Start', colors: colors),
          RadioGroup<int>(
            groupValue: weekStart,
            onChanged: (v) => ref.read(weekStartProvider.notifier).set(v!),
            child: Column(
              children: [
                RadioListTile<int>(
                  value: 1,
                  activeColor: colors.brand,
                  title: Text('Monday', style: TextStyle(color: colors.text)),
                ),
                RadioListTile<int>(
                  value: 7,
                  activeColor: colors.brand,
                  title: Text('Sunday', style: TextStyle(color: colors.text)),
                ),
              ],
            ),
          ),
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Day Boundary', colors: colors),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Days end at midnight by default. Shift the boundary if your nights run past midnight.',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ),
          RadioGroup<int>(
            groupValue: boundaryMins,
            onChanged: (v) =>
                ref.read(dayBoundaryMinutesProvider.notifier).set(v!),
            child: Column(
              children: [
                for (final mins in [0, 60, 120, 180, 240])
                  RadioListTile<int>(
                    value: mins,
                    activeColor: colors.brand,
                    title: Text(
                      mins == 0
                          ? 'Midnight (00:00)'
                          : '0${mins ~/ 60}:00 (${mins ~/ 60}h after midnight)',
                      style: TextStyle(color: colors.text),
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Time', colors: colors),
          SwitchListTile.adaptive(
            value: ref.watch(timeFormat24hProvider),
            onChanged: (v) => ref.read(timeFormat24hProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            title: Text('24-hour time', style: TextStyle(color: colors.text)),
          ),
          ListTile(
            title: Text(
              'Default reminder time',
              style: TextStyle(color: colors.text),
            ),
            subtitle: Text(
              'Used for all-day items',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            trailing: Text(
              _fmtMinutes(ref.watch(defaultReminderMinutesProvider)),
              style: TextStyle(color: colors.brand),
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
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Lock-in', colors: colors),
          SwitchListTile.adaptive(
            value: ref.watch(countTodosForLockInProvider),
            onChanged: (v) =>
                ref.read(countTodosForLockInProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            title: Text(
              'Count to-dos for lock-in',
              style: TextStyle(color: colors.text),
            ),
            subtitle: Text(
              'Flagged tasks due today must be done before the day locks in',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
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
    final reduced = ref.watch(reducedMotionProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Accessibility'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          _SectionHeader('Motion', colors: colors),
          SwitchListTile.adaptive(
            value: reduced,
            onChanged: (v) => ref.read(reducedMotionProvider.notifier).set(v),
            activeThumbColor: colors.brand,
            secondary: Icon(AppIcons.animationOutlined, color: colors.brand),
            title: Text('Reduce motion', style: TextStyle(color: colors.text)),
            subtitle: Text(
              'Fewer animations & transitions',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Goal reminders page (stub wiring) ────────────────────────────────────────

class GoalRemindersSettingsPage extends ConsumerWidget {
  const GoalRemindersSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Goal Reminders'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          _SectionHeader('Reminder cadence', colors: colors),
          ...[
            ('off', 'Off'),
            ('daily', 'Daily'),
            ('every2', 'Every 2 days'),
            ('every3', 'Every 3 days'),
            ('every5', 'Every 5 days'),
            ('weekly', 'Weekly'),
            ('milestones_only', 'Milestones only'),
          ].map(
            (opt) => _GoalReminderCadenceTile(
              value: opt.$1,
              label: opt.$2,
              colors: colors,
            ),
          ),
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Options', colors: colors),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalFinalStretch,
            label: 'Daily during final 7 days',
            icon: AppIcons.timerOutlined,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalMilestoneAlerts,
            label: 'Milestone alerts',
            icon: AppIcons.milestone,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalCompletionAlert,
            label: 'Completion alert',
            icon: AppIcons.checkCircleOutlined,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalSuppressIfDone,
            label: 'Skip if all habits done today',
            icon: AppIcons.doNotDisturbAltOutlined,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalShowTitle,
            label: 'Show goal title in notification',
            icon: AppIcons.titleOutlined,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _GoalReminderCadenceTile extends ConsumerWidget {
  const _GoalReminderCadenceTile({
    required this.value,
    required this.label,
    required this.colors,
  });
  final String value;
  final String label;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_goalCadenceProvider);
    return RadioGroup<String>(
      groupValue: current,
      onChanged: (v) => ref.read(_goalCadenceProvider.notifier).set(v!),
      child: RadioListTile<String>(
        value: value,
        activeColor: colors.brand,
        title: Text(label, style: TextStyle(color: colors.text)),
      ),
    );
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

class _GoalReminderToggle extends ConsumerWidget {
  const _GoalReminderToggle({
    required this.prefKey,
    required this.label,
    required this.icon,
    required this.colors,
  });
  final String prefKey;
  final String label;
  final IconData icon;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: _load(),
      builder: (ctx, snap) {
        final val = snap.data ?? true;
        return SwitchListTile.adaptive(
          value: val,
          onChanged: _save,
          activeThumbColor: colors.brand,
          secondary: Icon(icon, color: colors.brand),
          title: Text(label, style: TextStyle(color: colors.text)),
        );
      },
    );
  }

  Future<bool> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? true;
  }

  Future<void> _save(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, v);
  }
}

// ── About row ─────────────────────────────────────────────────────────────────

class _AboutRow extends ConsumerWidget {
  const _AboutRow({required this.colors});
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: Icon(AppIcons.helpOutline, color: colors.brand),
          title: Text('FAQ', style: TextStyle(color: colors.text)),
          trailing: Icon(AppIcons.openInNew, size: 16, color: colors.textMuted),
          onTap: () => _launch('https://incantum.in/faq'),
        ),
        ListTile(
          leading: Icon(AppIcons.infoOutline, color: colors.brand),
          title: Text('About Streakin', style: TextStyle(color: colors.text)),
          trailing: Icon(AppIcons.chevronRight, color: colors.textMuted),
          onTap: () => context.push('/settings/about'),
        ),
        ListTile(
          leading: Icon(AppIcons.newReleasesOutlined, color: colors.brand),
          title: Text('App Version', style: TextStyle(color: colors.text)),
          trailing: const _VersionBadge(),
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
    return Text(
      '1.0.0-alpha',
      style: TextStyle(fontSize: 13, color: colors.textMuted),
    );
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
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/icon.png', width: 80, height: 80),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Streakin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.brand,
              ),
            ),
          ),
          Center(
            child: Text(
              'Version 1.0.0-alpha',
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'A private, calm, beautiful place to build habits and think in notes.',
            style: TextStyle(color: colors.text, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Divider(color: colors.outline),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Built by Incantum · No telemetry · No cloud',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Your data stays yours',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.colors});
  final String title;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    this.subtitle,
    this.showChevron = true,
    this.trailingIcon,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final AppColorTokens colors;
  final bool showChevron;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.brand.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colors.brand, size: 20),
      ),
      title: Text(label, style: TextStyle(color: colors.text, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            )
          : null,
      trailing: Icon(
        trailingIcon ?? (showChevron ? AppIcons.chevronRight : null),
        color: colors.textMuted,
        size: 18,
      ),
      onTap: onTap,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
            if (!required)
              Text(
                ' (optional)',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 6),
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
