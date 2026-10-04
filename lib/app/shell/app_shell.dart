// lib/app/shell/app_shell.dart
// Responsive shell: NavigationBar (compact), NavigationRail (medium+).
// DB opening and ProviderScope override handled by SessionScope (parent).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return _CompactShell(shell: shell);
    if (width < 1024) return _MediumShell(shell: shell);
    return _ExpandedShell(shell: shell);
  }
}

const _navItems = [
  _NavItem(label: 'Home', icon: AppIcons.home, activeIcon: AppIcons.homeActive),
  _NavItem(label: 'Habits', icon: AppIcons.habits, activeIcon: AppIcons.habitsActive),
  _NavItem(label: 'Notes', icon: AppIcons.notes, activeIcon: AppIcons.notesActive),
  _NavItem(label: 'Calendar', icon: AppIcons.calendar, activeIcon: AppIcons.calendarActive),
  _NavItem(label: 'Tasks', icon: AppIcons.tasks, activeIcon: AppIcons.tasksActive),
];

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _onTap,
        backgroundColor: colors.surface,
        destinations: _navItems
            .map((n) => NavigationDestination(
                  icon: Icon(n.icon),
                  selectedIcon: Icon(n.activeIcon, color: colors.brand),
                  label: n.label,
                ))
            .toList(),
      ),
    );
  }

  void _onTap(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
}

class _MediumShell extends StatelessWidget {
  const _MediumShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            backgroundColor: colors.surface,
            indicatorColor: colors.brand.withValues(alpha: 0.15),
            labelType: NavigationRailLabelType.all,
            destinations: _navItems
                .map((n) => NavigationRailDestination(
                      icon: Icon(n.icon),
                      selectedIcon: Icon(n.activeIcon, color: colors.brand),
                      label: Text(n.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

class _ExpandedShell extends StatelessWidget {
  const _ExpandedShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: NavigationRail(
              extended: true,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
              backgroundColor: colors.surface,
              indicatorColor: colors.brand.withValues(alpha: 0.15),
              destinations: _navItems
                  .map((n) => NavigationRailDestination(
                        icon: Icon(n.icon),
                        selectedIcon: Icon(n.activeIcon, color: colors.brand),
                        label: Text(n.label),
                      ))
                  .toList(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
