// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Section(title: 'Appearance', children: [
            ListTile(
              leading: Icon(AppIcons.habits, color: colors.brand),
              title: const Text('Theme'),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).set(s.first),
              ),
            ),
          ]),
          _Section(title: 'Security', children: [
            ListTile(
              leading: Icon(AppIcons.lock, color: colors.brand),
              title: const Text('App Lock'),
              subtitle: const Text('Phase 5 — coming soon'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ]),
          _Section(title: 'Data', children: [
            ListTile(
              leading: Icon(AppIcons.export_, color: colors.brand),
              title: const Text('Export / Import'),
              subtitle: const Text('Phase 6 — coming soon'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                  letterSpacing: 0.8)),
        ),
        ...children,
        Divider(color: colors.outline, height: 1),
      ],
    );
  }
}
