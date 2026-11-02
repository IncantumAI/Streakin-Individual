// lib/app/shell/app_shell.dart
// Responsive shell with custom navbar — diamond Notes centre button.
// Compact: floating bottom bar with animated pill indicators.
// Medium: NavigationRail. Expanded: branded sidebar rail.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/app/brand.dart';
import 'package:streakin/core/design/elevation.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/app/router.dart' show AppRoutes;
import 'package:streakin/shared/feedback/haptics.dart';
import 'package:streakin/shared/widgets/pressable_scale.dart';
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/features/habits/application/habit_providers.dart'
    show lockedInTodayProvider;
import 'package:streakin/shared/widgets/celebration_overlay.dart';
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
    return _LockInCelebration(
      child: _NotificationTapListener(child: _DesktopShortcuts(child: body)),
    );
  }
}

/// Celebrates the moment the day becomes locked in (false → true while the
/// app is open). Never fires on cold start when the day is already locked in.
class _LockInCelebration extends ConsumerWidget {
  const _LockInCelebration({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(lockedInTodayProvider, (prev, next) {
      final was = prev?.value;
      final now = next.value;
      if (was == false && now == true) {
        context.celebrate(CelebrationKind.lockIn);
      }
    });
    return child;
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

/// Switches branch; re-tapping the active tab returns it to its root.
void _goBranch(WidgetRef ref, StatefulNavigationShell shell, int i) {
  if (i != shell.currentIndex) ref.read(hapticsProvider).selection();
  shell.goBranch(i, initialLocation: i == shell.currentIndex);
}

class _CompactShell extends ConsumerWidget {
  const _CompactShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: _CustomNavBar(
        currentIndex: shell.currentIndex,
        onTap: (i) => _goBranch(ref, shell, i),
      ),
    );
  }
}

class _CustomNavBar extends StatelessWidget {
  const _CustomNavBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  // Layout: [0=Home, 1=Habits, _Diamond=2=Notes, 3=Calendar, 4=Tasks]
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget tab(int i) => _RegularTab(
      item: _sideItems[i],
      selected: currentIndex == i,
      onTap: () => onTap(i),
    );
    return Container(
      height: AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border(top: BorderSide(color: colors.outline)),
        boxShadow: AppElevation.floating(colors),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 4 regular tabs — two on each side of centre
          Row(
            children: [
              tab(0),
              tab(1),
              // Centre spacer for the diamond
              const Expanded(child: SizedBox()),
              tab(3),
              tab(4),
            ],
          ),
          // Diamond Notes button — floats above the bar centre
          Positioned(
            top: -20,
            left: 0,
            right: 0,
            child: Center(
              child: _DiamondNotesButton(
                selected: currentIndex == 2,
                onTap: () => onTap(2),
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
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = resolvedDuration(context, AppDurations.base);
    final fg = selected ? colors.brandText : colors.textMuted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: SizedBox(
            height: AppSizes.navBarHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: d,
                  curve: AppCurves.emphasized,
                  width: selected ? 52 : 36,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.brandSubtle
                        : colors.brandSubtle.withValues(alpha: 0),
                    borderRadius: AppRadius.brPill,
                  ),
                  child: AnimatedSwitcher(
                    duration: d,
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      key: ValueKey(selected),
                      color: fg,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                AnimatedDefaultTextStyle(
                  duration: d,
                  style: context.text.labelMedium!.copyWith(
                    fontSize: 11,
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(item.label, maxLines: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiamondNotesButton extends StatelessWidget {
  const _DiamondNotesButton({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Notes',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        scale: 0.92,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: selected ? 1 : 0),
          duration: resolvedDuration(context, AppDurations.slow),
          curve: AppCurves.emphasized,
          builder: (context, t, _) => SizedBox(
            width: 62,
            height: 62,
            child: CustomPaint(
              painter: _DiamondPainter(
                fillColor: colors.brand,
                // Glow intensifies when Notes is the active branch.
                shadowColor: colors.brand.withValues(alpha: 0.25 + 0.3 * t),
                blur: 6 + 6 * t,
                highlightColor: AppColors.white.withValues(
                  alpha: 0.12 + 0.1 * t,
                ),
              ),
              child: Center(
                child: Transform.scale(
                  scale: 1 + 0.08 * t,
                  child: Icon(
                    selected ? AppIcons.notesActive : AppIcons.notes,
                    color: colors.onBrand,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter({
    required this.fillColor,
    required this.shadowColor,
    required this.blur,
    required this.highlightColor,
  });
  final Color fillColor;
  final Color shadowColor;
  final double blur;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;
    const corner = 7.0;

    // Rounded diamond: quadratic corners instead of sharp points.
    Path diamond(double radius, double c) {
      final top = Offset(cx, cy - radius);
      final right = Offset(cx + radius, cy);
      final bottom = Offset(cx, cy + radius);
      final left = Offset(cx - radius, cy);
      Offset towards(Offset a, Offset b, double d) {
        final v = b - a;
        return a + v / v.distance * d;
      }

      final pts = [top, right, bottom, left];
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final p = pts[i];
        final prev = pts[(i + 3) % 4];
        final next = pts[(i + 1) % 4];
        final a = towards(p, prev, c);
        final b = towards(p, next, c);
        if (i == 0) {
          path.moveTo(a.dx, a.dy);
        } else {
          path.lineTo(a.dx, a.dy);
        }
        path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
      }
      return path..close();
    }

    final path = diamond(r, corner);

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );

    // Fill
    canvas.drawPath(path, Paint()..color = fillColor);

    // Subtle inner highlight
    canvas.drawPath(
      diamond(r - 6, corner - 2),
      Paint()
        ..color = highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.fillColor != fillColor ||
      old.shadowColor != shadowColor ||
      old.blur != blur ||
      old.highlightColor != highlightColor;
}

// ── Medium (tablet rail) ───────────────────────────────────────────────────────

List<NavigationRailDestination> _railDestinations() => _sideItems
    .map(
      (n) => NavigationRailDestination(
        icon: Icon(n.icon),
        selectedIcon: Icon(n.activeIcon),
        label: Text(n.label),
      ),
    )
    .toList();

class _MediumShell extends ConsumerWidget {
  const _MediumShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) => _goBranch(ref, shell, i),
            labelType: NavigationRailLabelType.all,
            groupAlignment: -0.85,
            leading: const Padding(
              padding: EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.lg),
              child: _BrandMark(size: 36),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.lg),
                  child: IconButton(
                    icon: Icon(AppIcons.settings, color: colors.textMuted),
                    tooltip: 'Settings',
                    onPressed: () => context.push(AppRoutes.settings),
                  ),
                ),
              ),
            ),
            destinations: _railDestinations(),
          ),
          VerticalDivider(width: 1, color: colors.outline),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

// ── Expanded (desktop) ────────────────────────────────────────────────────────

class _ExpandedShell extends ConsumerWidget {
  const _ExpandedShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: AppSizes.railWidthExpanded,
            child: NavigationRail(
              extended: true,
              minExtendedWidth: AppSizes.railWidthExpanded,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => _goBranch(ref, shell, i),
              groupAlignment: -0.9,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.xl,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BrandMark(size: 32),
                    const SizedBox(width: AppSpace.md),
                    Text(Brand.appName, style: context.text.titleMedium),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      0,
                      AppSpace.md,
                      AppSpace.lg,
                    ),
                    child: SizedBox(
                      width: AppSizes.railWidthExpanded - AppSpace.xl,
                      child: ListTile(
                        leading: Icon(
                          AppIcons.settings,
                          color: colors.textMuted,
                        ),
                        title: Text(
                          'Settings',
                          style: context.text.labelLarge!.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                    ),
                  ),
                ),
              ),
              destinations: _railDestinations(),
            ),
          ),
          VerticalDivider(width: 1, color: colors.outline),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

/// App icon in a rounded tile, used at the top of the navigation rails.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'assets/icon.png',
        width: size,
        height: size,
        semanticLabel: Brand.appName,
      ),
    );
  }
}
