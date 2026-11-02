// lib/app/shell/app_shell.dart
// Responsive shell with custom navbar — diamond Notes centre button.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/app/router.dart' show AppRoutes;
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/features/notes/notes_module.dart' show showNewNoteFlow;
import 'package:streakin/features/todos/presentation/todos_screen.dart'
    show showAddTaskSheet;
import 'package:window_manager/window_manager.dart';
import 'package:streakin/core/notifications/notification_reconciler.dart'
    show notificationTapPayload;

class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final Widget body;
    if (width < 600) {
      body = _CompactShell(shell: shell);
    } else if (width < 1024) {
      body = _MediumShell(shell: shell);
    } else {
      body = _ExpandedShell(shell: shell);
    }
    return _NotificationTapListener(child: _DesktopShortcuts(child: body));
  }
}

/// App-level desktop shortcuts (Spec §5.7). Editor-level shortcuts (Ctrl+B/I/U,
/// Ctrl+Z …) are provided by the editor itself.
class _DesktopShortcuts extends ConsumerWidget {
  const _DesktopShortcuts({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) return child;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            showNewNoteFlow(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () =>
            showAddTaskSheet(context),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            GoRouter.of(context).push('/notes/search'),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
            ref.read(LockController.provider.notifier).lock(),
        const SingleActivator(LogicalKeyboardKey.f11): () async {
          final full = await windowManager.isFullScreen();
          await windowManager.setFullScreen(!full);
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

/// Routes a tapped notification (opaque `type:id` payload) to its entity.
/// The shell only exists after unlock, so a tap while locked first goes
/// through the lock screen and is consumed here afterwards.
class _NotificationTapListener extends StatefulWidget {
  const _NotificationTapListener({required this.child});
  final Widget child;

  @override
  State<_NotificationTapListener> createState() =>
      _NotificationTapListenerState();
}

class _NotificationTapListenerState extends State<_NotificationTapListener> {
  @override
  void initState() {
    super.initState();
    notificationTapPayload.addListener(_consume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consume());
  }

  @override
  void dispose() {
    notificationTapPayload.removeListener(_consume);
    super.dispose();
  }

  void _consume() {
    final payload = notificationTapPayload.value;
    if (payload == null || !mounted) return;
    notificationTapPayload.value = null;
    final sep = payload.indexOf(':');
    if (sep < 0) return;
    final type = payload.substring(0, sep);
    final id = payload.substring(sep + 1);
    final router = GoRouter.of(context);
    switch (type) {
      case 'habit':
      case 'lockin':
        router.go(AppRoutes.habits);
      case 'todo':
        router.go(AppRoutes.tasks);
      case 'date_mention':
        router.push('/notes/$id');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Indices: 0=Home, 1=Habits, 2=Notes, 3=Calendar, 4=Tasks
const _sideItems = [
  _NavItem(label: 'Home', icon: AppIcons.home, activeIcon: AppIcons.homeActive),
  _NavItem(
    label: 'Habits',
    icon: AppIcons.habits,
    activeIcon: AppIcons.habitsActive,
  ),
  _NavItem(
    label: 'Notes',
    icon: AppIcons.notes,
    activeIcon: AppIcons.notesActive,
  ),
  _NavItem(
    label: 'Calendar',
    icon: AppIcons.calendar,
    activeIcon: AppIcons.calendarActive,
  ),
  _NavItem(
    label: 'Tasks',
    icon: AppIcons.tasks,
    activeIcon: AppIcons.tasksActive,
  ),
];

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

// ── Compact (mobile) ──────────────────────────────────────────────────────────

class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: shell,
      bottomNavigationBar: _CustomNavBar(
        currentIndex: shell.currentIndex,
        onTap: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        colors: colors,
      ),
    );
  }
}

class _CustomNavBar extends StatelessWidget {
  const _CustomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.colors,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;
  final AppColorTokens colors;

  // Layout: [0=Home, 1=Habits, _Diamond=2=Notes, 3=Calendar, 4=Tasks]
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 4 regular tabs — two on each side of centre
          Row(
            children: [
              _RegularTab(
                index: 0,
                item: _sideItems[0],
                selected: currentIndex == 0,
                onTap: () => onTap(0),
                colors: colors,
              ),
              _RegularTab(
                index: 1,
                item: _sideItems[1],
                selected: currentIndex == 1,
                onTap: () => onTap(1),
                colors: colors,
              ),
              // Centre spacer for the diamond
              const Expanded(child: SizedBox()),
              _RegularTab(
                index: 3,
                item: _sideItems[3],
                selected: currentIndex == 3,
                onTap: () => onTap(3),
                colors: colors,
              ),
              _RegularTab(
                index: 4,
                item: _sideItems[4],
                selected: currentIndex == 4,
                onTap: () => onTap(4),
                colors: colors,
              ),
            ],
          ),
          // Diamond Notes button — floats above the bar centre
          Positioned(
            top: -18,
            left: 0,
            right: 0,
            child: Center(
              child: _DiamondNotesButton(
                selected: currentIndex == 2,
                onTap: () => onTap(2),
                colors: colors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegularTab extends StatelessWidget {
  const _RegularTab({
    required this.index,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.colors,
  });
  final int index;
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                color: selected ? colors.brand : colors.textMuted,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? colors.brand : colors.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiamondNotesButton extends StatelessWidget {
  const _DiamondNotesButton({
    required this.selected,
    required this.onTap,
    required this.colors,
  });
  final bool selected;
  final VoidCallback onTap;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: 60,
        child: CustomPaint(
          painter: _DiamondPainter(
            fillColor: selected ? colors.brand : colors.brand,
            shadowColor: colors.brand.withAlpha(80),
          ),
          child: Center(
            child: Icon(
              selected ? AppIcons.notesActive : AppIcons.notes,
              color: colors.onBrand,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter({required this.fillColor, required this.shadowColor});
  final Color fillColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;

    final path = Path()
      ..moveTo(cx, cy - r) // top
      ..lineTo(cx + r, cy) // right
      ..lineTo(cx, cy + r) // bottom
      ..lineTo(cx - r, cy) // left
      ..close();

    // Shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);

    // Fill
    canvas.drawPath(path, Paint()..color = fillColor);

    // Subtle inner highlight
    final highlightPath = Path()
      ..moveTo(cx, cy - r + 6)
      ..lineTo(cx + r - 6, cy)
      ..lineTo(cx, cy + r - 6)
      ..lineTo(cx - r + 6, cy)
      ..close();
    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = Colors.white.withAlpha(25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) => old.fillColor != fillColor;
}

// ── Medium (tablet rail) ───────────────────────────────────────────────────────

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
            indicatorColor: colors.brand.withAlpha(38),
            labelType: NavigationRailLabelType.all,
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: Icon(AppIcons.settings, color: colors.textMuted),
                    tooltip: 'Settings',
                    onPressed: () => context.push(AppRoutes.settings),
                  ),
                ),
              ),
            ),
            destinations: _sideItems
                .map(
                  (n) => NavigationRailDestination(
                    icon: Icon(n.icon),
                    selectedIcon: Icon(n.activeIcon, color: colors.brand),
                    label: Text(n.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

// ── Expanded (desktop) ────────────────────────────────────────────────────────

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
              indicatorColor: colors.brand.withAlpha(38),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: Icon(AppIcons.settings, color: colors.textMuted),
                      title: Text(
                        'Settings',
                        style: TextStyle(color: colors.textMuted),
                      ),
                      onTap: () => context.push(AppRoutes.settings),
                    ),
                  ),
                ),
              ),
              destinations: _sideItems
                  .map(
                    (n) => NavigationRailDestination(
                      icon: Icon(n.icon),
                      selectedIcon: Icon(n.activeIcon, color: colors.brand),
                      label: Text(n.label),
                    ),
                  )
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
