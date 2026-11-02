// lib/features/habits/presentation/today_view.dart
// Spec §4.2 FR-HAB-2: Today view with one-tap check, long-press context menu,
// drag-to-reorder, soft-delete with undo, lock-in animation trigger.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/presentation/widgets/habit_check_button.dart';
import 'package:streakin/features/habits/presentation/widgets/lock_in_banner.dart';
import 'package:streakin/shared/widgets/widgets.dart';

class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsForAllTodayProvider);
    final logsAsync = ref.watch(todayLogsProvider);
    final lockedInAsync = ref.watch(lockedInTodayProvider);
    return habitsAsync.when(
      loading: () => const SkeletonList(count: 4),
      error: (e, st) => ErrorState(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(habitsForAllTodayProvider),
      ),
      data: (habits) {
        if (habits.isEmpty) {
          return _EmptyState();
        }
        final logs = logsAsync.value ?? const {};
        final done = habits.where((h) => logs[h.id]?.isDone ?? false).length;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _TodayProgressHeader(done: done, total: habits.length),
            ),
            // Lock-in banner
            SliverToBoxAdapter(
              child: lockedInAsync.maybeWhen(
                data: (locked) =>
                    locked ? const LockInBanner() : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            // Reorderable habit list
            SliverReorderableList(
              itemCount: habits.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _onReorder(ref, habits, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final habit = habits[index];
                final log = logsAsync.value?[habit.id];
                return ReorderableDragStartListener(
                  key: ValueKey(habit.id),
                  index: index,
                  child: StaggeredEntrance(
                    index: index,
                    child: _HabitTile(habit: habit, log: log),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        );
      },
    );
  }

  Future<void> _onReorder(
    WidgetRef ref,
    List<Habit> habits,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem already compensates newIndex for the removed item.
    final useCases = ref.read(habitUseCasesProvider);
    // Update sort orders
    final reordered = [...habits];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    for (int i = 0; i < reordered.length; i++) {
      await useCases.saveHabit(reordered[i].copyWith(sortOrder: i));
    }
  }
}

class _HabitTile extends ConsumerStatefulWidget {
  const _HabitTile({required this.habit, required this.log});
  final Habit habit;
  final HabitLog? log;

  @override
  ConsumerState<_HabitTile> createState() => _HabitTileState();
}

class _HabitTileState extends ConsumerState<_HabitTile> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDone = widget.log?.isDone ?? false;
    final isRest = widget.log?.isRest ?? false;
    final accent = AppColors.habitAccents[widget.habit.accentIndex % 8];
    final active = isDone || isRest;
    final d = resolvedDuration(context, AppDurations.base);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.xs + 1,
      ),
      child: Dismissible(
        key: ValueKey('dismiss_${widget.habit.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpace.xl),
          decoration: BoxDecoration(
            color: colors.dangerSubtle,
            borderRadius: AppRadius.brLg,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete',
                style: context.text.labelLarge!.copyWith(color: colors.danger),
              ),
              const SizedBox(width: AppSpace.sm),
              Icon(AppIcons.delete, color: colors.danger),
            ],
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => _onDelete(),
        child: GestureDetector(
          onLongPress: () => _showContextMenu(context),
          onSecondaryTap: () => _showContextMenu(context),
          child: AnimatedContainer(
            duration: d,
            curve: AppCurves.standard,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.xs,
              AppSpace.sm,
            ),
            decoration: BoxDecoration(
              color: active
                  ? Color.alphaBlend(
                      accent.withValues(alpha: 0.07),
                      colors.surface,
                    )
                  : colors.surface,
              borderRadius: AppRadius.brLg,
              border: Border.all(
                color: active ? accent.withValues(alpha: 0.45) : colors.outline,
              ),
            ),
            child: Row(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                  child: Icon(
                    AppIcons.drag,
                    size: AppSizes.iconMd,
                    color: colors.textMuted.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                // Habit icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(
                    AppIcons.habitIcons[widget.habit.iconIndex %
                        AppIcons.habitIcons.length],
                    size: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: d,
                        style: context.text.titleMedium!.copyWith(
                          color: isDone ? colors.textMuted : colors.text,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: colors.textMuted,
                        ),
                        child: Text(
                          widget.habit.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRest)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.xxs),
                          child: Text(
                            'Rest token used',
                            style: context.text.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                // Check button
                HabitCheckButton(
                  isDone: isDone,
                  isRest: isRest,
                  accentColor: accent,
                  onTap: _onCheck,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onCheck() async {
    final useCases = ref.read(habitUseCasesProvider);
    final isDone = widget.log?.isDone ?? false;
    // Haptic feedback is emitted by HabitCheckButton.
    if (isDone) {
      await useCases.uncheckHabit(widget.habit.id);
    } else {
      await useCases.checkHabit(widget.habit.id);
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    // Show snackbar with undo instead of a dialog.
    return true;
  }

  void _onDelete() {
    final useCases = ref.read(habitUseCasesProvider);
    final habitName = widget.habit.name;
    final habitId = widget.habit.id;

    // 10-second undo window (spec FR-HAB-1).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$habitName deleted'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final habit = await ref
                .read(habitRepositoryStateProvider)
                ?.getById(habitId);
            if (habit != null) {
              await ref.read(habitUseCasesProvider).saveHabit(habit.copyWith());
            }
          },
        ),
      ),
    );
    useCases.deleteHabit(habitId);
  }

  void _showContextMenu(BuildContext context) {
    showAppBottomSheet<void>(
      context,
      title: widget.habit.name,
      isScrollControlled: false,
      builder: (_) => _HabitContextMenu(habit: widget.habit, log: widget.log),
    );
  }
}

class _HabitContextMenu extends ConsumerWidget {
  const _HabitContextMenu({required this.habit, required this.log});
  final Habit habit;
  final HabitLog? log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          0,
          AppSpace.sm,
          AppSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.skip),
              title: const Text('Skip today'),
              onTap: () {
                Navigator.pop(context);
                ref.read(habitUseCasesProvider).skipHabit(habit.id);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.restToken),
              title: const Text('Use rest token'),
              onTap: () {
                Navigator.pop(context);
                ref.read(habitUseCasesProvider).useRestToken(habit.id);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.backfill),
              title: const Text('Backfill past date'),
              onTap: () {
                Navigator.pop(context);
                // TODO: open date picker for backfill
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: AppIcons.emptyHabits,
      title: 'No habits yet',
      message: 'Small daily wins add up. Tap + to add your first habit and start a streak.',
    );
  }
}

/// "3 of 5 done" header with a progress ring and a short encouragement.
class _TodayProgressHeader extends StatelessWidget {
  const _TodayProgressHeader({required this.done, required this.total});
  final int done;
  final int total;

  String get _message {
    if (total == 0) return '';
    if (done == total) return 'Everything done. Enjoy the rest of your day.';
    if (done == 0) return 'Start with the easiest one.';
    final left = total - done;
    return '$left to go. Keep the momentum.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          ProgressRing(
            value: progress,
            size: 52,
            stroke: 5,
            color: done == total ? colors.success : colors.brand,
            semanticsLabel: 'Today progress',
            center: Text(
              '${(progress * 100).round()}%',
              style: AppTypography.numeric.copyWith(
                fontSize: 13,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedCounter(
                      value: done,
                      style: context.text.titleLarge,
                    ),
                    Text(' of $total done', style: context.text.titleLarge),
                  ],
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(_message, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
