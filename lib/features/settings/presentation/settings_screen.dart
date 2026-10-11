import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:streakin/core/design/tokens.dart';
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
                          fontWeight: FontWeight.w600),
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
                                  : colors.text),
                        ),
                        if (profile.username.isNotEmpty)
                          Text('@${profile.username}',
                              style: TextStyle(
                                  fontSize: 13, color: colors.textMuted)),
                        if (profile.bio.isNotEmpty)
                          Text(profile.bio,
                              style: TextStyle(
                                  fontSize: 12, color: colors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: colors.outline, height: 1),

          // ── Personalisation ──────────────────────────────────────────────
          _SectionHeader('Personalisation', colors: colors),
          _SettingsTile(
            icon: Icons.palette_outlined,
            label: 'Appearance',
            subtitle: 'Theme & display',
            onTap: () => context.push('/settings/appearance'),
            colors: colors,
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Permissions & preferences',
            onTap: () => context.push('/settings/notifications'),
            colors: colors,
          ),

          // ── Security ─────────────────────────────────────────────────────
          _SectionHeader('Security', colors: colors),
          _SettingsTile(
            icon: Icons.fingerprint,
            label: 'Biometric Unlock',
            subtitle: 'Face ID, fingerprint',
            onTap: () => context.push('/settings/biometric'),
            colors: colors,
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Auto-lock',
            subtitle: 'Timeout & behaviour',
            onTap: () => context.push('/settings/autolock'),
            colors: colors,
          ),

          // ── Goals ─────────────────────────────────────────────────────────
          _SectionHeader('Goals', colors: colors),
          _SettingsTile(
            icon: Icons.track_changes_outlined,
            label: 'Goal Reminders',
            subtitle: 'Cadence, time & content',
            onTap: () => context.push('/settings/goal-reminders'),
            colors: colors,
          ),

          // ── General ──────────────────────────────────────────────────────
          _SectionHeader('General', colors: colors),
          _SettingsTile(
            icon: Icons.calendar_today_outlined,
            label: 'Week & Day',
            subtitle: 'Week start, day boundary',
            onTap: () => context.push('/settings/week-day'),
            colors: colors,
          ),
          _SettingsTile(
            icon: Icons.accessibility_new_outlined,
            label: 'Accessibility',
            subtitle: 'Motion & haptics',
            onTap: () => context.push('/settings/accessibility'),
            colors: colors,
          ),

          // ── Support ──────────────────────────────────────────────────────
          _SectionHeader('Support', colors: colors),
          _SettingsTile(
            icon: Icons.mail_outline,
            label: 'Contact Us',
            onTap: () => _launchUrl('mailto:hello@incantum.in'),
            colors: colors,
            showChevron: false,
            trailingIcon: Icons.open_in_new,
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            onTap: () => _launchUrl('https://incantum.in/terms'),
            colors: colors,
            showChevron: false,
            trailingIcon: Icons.open_in_new,
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _launchUrl('https://incantum.in/privacy'),
            colors: colors,
            showChevron: false,
            trailingIcon: Icons.open_in_new,
          ),
          _SettingsTile(
            icon: Icons.star_outline,
            label: 'Rate the App',
            onTap: () => _launchUrl(
                'https://play.google.com/store/apps/details?id=in.incantum.streakin'),
            colors: colors,
            showChevron: false,
            trailingIcon: Icons.open_in_new,
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
            child: Text('Save',
                style: TextStyle(
                    color: colors.brand, fontWeight: FontWeight.w600)),
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
                  child: Consumer(builder: (_, ref, __) {
                    final p = ref.watch(profileProvider);
                    final name = _nameCtrl.text.isNotEmpty
                        ? _nameCtrl.text
                        : p.username;
                    final initials =
                        name.isEmpty ? '?' : name[0].toUpperCase();
                    return Text(initials,
                        style: TextStyle(
                            color: colors.onBrand,
                            fontSize: 28,
                            fontWeight: FontWeight.w600));
                  }),
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
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))
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
    await ref.read(profileProvider.notifier).save(
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
          title: const Text('Appearance'), backgroundColor: colors.surface),
      body: ListView(
        children: [
          _SectionHeader('Theme', colors: colors),
          ...{
            ThemeMode.light: ('Light', Icons.light_mode_outlined),
            ThemeMode.system: ('System default', Icons.brightness_auto_outlined),
            ThemeMode.dark: ('Dark', Icons.dark_mode_outlined),
          }.entries.map((e) => RadioListTile<ThemeMode>(
                value: e.key,
                groupValue: themeMode,
                onChanged: (v) =>
                    ref.read(themeModeProvider.notifier).set(v!),
                activeColor: colors.brand,
                secondary: Icon(e.value.$2, color: colors.brand),
                title: Text(e.value.$1,
                    style: TextStyle(color: colors.text)),
              )),
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Motion', colors: colors),
          SwitchListTile.adaptive(
            value: reduced,
            onChanged: (v) =>
                ref.read(reducedMotionProvider.notifier).set(v),
            activeColor: colors.brand,
            secondary: Icon(Icons.animation_outlined, color: colors.brand),
            title: Text('Reduce motion',
                style: TextStyle(color: colors.text)),
            subtitle: Text('Fewer animations throughout the app',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Notifications page ────────────────────────────────────────────────────────

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: colors.surface),
      body: ListView(
        children: [
          _SectionHeader('System', colors: colors),
          ListTile(
            leading: Icon(Icons.notifications_outlined, color: colors.brand),
            title: Text('Notification Permission',
                style: TextStyle(color: colors.text)),
            subtitle: Text(
                'Manage in Android Settings → Apps → Streakin → Notifications',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
            trailing: FilledButton.tonal(
              onPressed: () => _openSettings(),
              child: const Text('Open'),
            ),
          ),
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Reminders', colors: colors),
          ListTile(
            leading: Icon(Icons.check_box_outlined, color: colors.brand),
            title: Text('Habit reminders',
                style: TextStyle(color: colors.text)),
            subtitle: Text('Set per habit in Habits → Edit',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
            trailing: Icon(Icons.info_outline, color: colors.textMuted),
          ),
          ListTile(
            leading:
                Icon(Icons.track_changes_outlined, color: colors.brand),
            title: Text('Goal countdown reminders',
                style: TextStyle(color: colors.text)),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
            onTap: () => context.push('/settings/goal-reminders'),
          ),
          ListTile(
            leading:
                Icon(Icons.checklist_outlined, color: colors.brand),
            title: Text('Task reminders',
                style: TextStyle(color: colors.text)),
            subtitle: Text('Set per task in Tasks → Edit',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
            trailing: Icon(Icons.info_outline, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    const uri = 'app-settings:';
    if (await canLaunchUrl(Uri.parse(uri))) {
      await launchUrl(Uri.parse(uri));
    }
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
          backgroundColor: colors.surface),
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
                      border:
                          Border.all(color: colors.warning.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined,
                            color: colors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No biometric hardware found or not enrolled. Enrol in Android Settings → Security.',
                            style:
                                TextStyle(fontSize: 13, color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SwitchListTile.adaptive(
                value: enabled,
                onChanged: available
                    ? (v) =>
                        ref.read(biometricEnabledProvider.notifier).set(v)
                    : null,
                activeColor: colors.brand,
                secondary:
                    Icon(Icons.fingerprint, color: colors.brand),
                title: Text('Unlock with biometrics',
                    style: TextStyle(color: colors.text)),
                subtitle: Text(
                    'Use face or fingerprint instead of password',
                    style: TextStyle(
                        color: colors.textMuted, fontSize: 12)),
              ),
              Divider(color: colors.outline, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Your password is always available as a fallback.',
                  style:
                      TextStyle(fontSize: 12, color: colors.textMuted),
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
          title: const Text('Auto-lock'), backgroundColor: colors.surface),
      body: ListView(
        children: [
          _SectionHeader('Lock after inactivity', colors: colors),
          ..._options.map((opt) {
            final mins = opt.$1.inMinutes;
            final isNever = opt.$1.inDays > 1;
            final selected = isNever
                ? currentMinutes >= 999 * 60
                : currentMinutes == mins;
            return RadioListTile<int>(
              value: isNever ? 99999 : mins,
              groupValue: currentMinutes,
              onChanged: (v) => ref
                  .read(_lockTimeoutMinutesProvider.notifier)
                  .set(v!),
              activeColor: colors.brand,
              title: Text(opt.$2,
                  style: TextStyle(color: colors.text)),
            );
          }),
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

final _lockTimeoutMinutesProvider =
    NotifierProvider<_LockTimeoutNotifier, int>(_LockTimeoutNotifier.new);

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
          title: const Text('Week & Day'), backgroundColor: colors.surface),
      body: ListView(
        children: [
          _SectionHeader('Week Start', colors: colors),
          RadioListTile<int>(
            value: 1,
            groupValue: weekStart,
            onChanged: (v) =>
                ref.read(weekStartProvider.notifier).set(v!),
            activeColor: colors.brand,
            title: Text('Monday', style: TextStyle(color: colors.text)),
          ),
          RadioListTile<int>(
            value: 7,
            groupValue: weekStart,
            onChanged: (v) =>
                ref.read(weekStartProvider.notifier).set(v!),
            activeColor: colors.brand,
            title: Text('Sunday', style: TextStyle(color: colors.text)),
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
          ...[0, 60, 120, 180, 240].map((mins) {
            final label = mins == 0
                ? 'Midnight (00:00)'
                : '0${mins ~/ 60}:00 (${mins ~/ 60}h after midnight)';
            return RadioListTile<int>(
              value: mins,
              groupValue: boundaryMins,
              onChanged: (v) =>
                  ref.read(dayBoundaryMinutesProvider.notifier).set(v!),
              activeColor: colors.brand,
              title: Text(label, style: TextStyle(color: colors.text)),
            );
          }),
        ],
      ),
    );
  }
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
          backgroundColor: colors.surface),
      body: ListView(
        children: [
          _SectionHeader('Motion', colors: colors),
          SwitchListTile.adaptive(
            value: reduced,
            onChanged: (v) =>
                ref.read(reducedMotionProvider.notifier).set(v),
            activeColor: colors.brand,
            secondary:
                Icon(Icons.animation_outlined, color: colors.brand),
            title: Text('Reduce motion',
                style: TextStyle(color: colors.text)),
            subtitle: Text('Fewer animations & transitions',
                style:
                    TextStyle(color: colors.textMuted, fontSize: 12)),
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
          backgroundColor: colors.surface),
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
          ].map((opt) => _GoalReminderCadenceTile(
              value: opt.$1, label: opt.$2, colors: colors)),
          Divider(color: colors.outline, height: 1),
          _SectionHeader('Options', colors: colors),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalFinalStretch,
            label: 'Daily during final 7 days',
            icon: Icons.timer_outlined,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalMilestoneAlerts,
            label: 'Milestone alerts',
            icon: Icons.emoji_events_outlined,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalCompletionAlert,
            label: 'Completion alert',
            icon: Icons.check_circle_outlined,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalSuppressIfDone,
            label: 'Skip if all habits done today',
            icon: Icons.do_not_disturb_alt_outlined,
            colors: colors,
          ),
          _GoalReminderToggle(
            prefKey: AppIdentifiers.prefGoalShowTitle,
            label: 'Show goal title in notification',
            icon: Icons.title_outlined,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _GoalReminderCadenceTile extends ConsumerWidget {
  const _GoalReminderCadenceTile(
      {required this.value, required this.label, required this.colors});
  final String value;
  final String label;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_goalCadenceProvider);
    return RadioListTile<String>(
      value: value,
      groupValue: current,
      onChanged: (v) => ref.read(_goalCadenceProvider.notifier).set(v!),
      activeColor: colors.brand,
      title: Text(label, style: TextStyle(color: colors.text)),
    );
  }
}

final _goalCadenceProvider =
    NotifierProvider<_GoalCadenceNotifier, String>(_GoalCadenceNotifier.new);

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
  const _GoalReminderToggle(
      {required this.prefKey,
      required this.label,
      required this.icon,
      required this.colors});
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
          onChanged: (v) => _save(v),
          activeColor: colors.brand,
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
          leading: Icon(Icons.help_outline, color: colors.brand),
          title: Text('FAQ', style: TextStyle(color: colors.text)),
          trailing: Icon(Icons.open_in_new, size: 16, color: colors.textMuted),
          onTap: () =>
              _launch('https://incantum.in/faq'),
        ),
        ListTile(
          leading: Icon(Icons.info_outline, color: colors.brand),
          title: Text('About Streakin',
              style: TextStyle(color: colors.text)),
          trailing: Icon(Icons.chevron_right, color: colors.textMuted),
          onTap: () => context.push('/settings/about'),
        ),
        ListTile(
          leading: Icon(Icons.new_releases_outlined, color: colors.brand),
          title: Text('App Version',
              style: TextStyle(color: colors.text)),
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
    return Text('1.0.0-alpha',
        style: TextStyle(fontSize: 13, color: colors.textMuted));
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
      appBar:
          AppBar(title: const Text('About'), backgroundColor: colors.surface),
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
            child: Text('Streakin',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colors.brand)),
          ),
          Center(
            child: Text('Version 1.0.0-alpha',
                style: TextStyle(color: colors.textMuted, fontSize: 13)),
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
            child: Text('Built by Incantum · No telemetry · No cloud',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Your data stays yours',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
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
            letterSpacing: 0.8),
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
          ? Text(subtitle!,
              style: TextStyle(color: colors.textMuted, fontSize: 12))
          : null,
      trailing: Icon(
        trailingIcon ?? (showChevron ? Icons.chevron_right : null),
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
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted)),
            if (!required)
              Text(' (optional)',
                  style:
                      TextStyle(fontSize: 12, color: colors.textMuted)),
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
