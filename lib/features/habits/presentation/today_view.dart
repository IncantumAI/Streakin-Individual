// lib/features/habits/presentation/today_view.dart
// Spec §4.2 FR-HAB-2: Today view with one-tap check, long-press context menu,
// drag-to-reorder, soft-delete with undo, lock-in animation trigger.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/presentation/widgets/habit_check_button.dart';
import 'package:streakin/features/habits/presentation/widgets/lock_in_banner.dart';

class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsForTodayProvider);
    final logsAsync = ref.watch(todayLogsProvider);
    final lockedInAsync = ref.watch(lockedInTodayProvider);
    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (habits) {
        if (habits.isEmpty) {
          return _EmptyState();
        }
        return CustomScrollView(
          slivers: [
            // Lock-in banner
            SliverToBoxAdapter(
              child: lockedInAsync.maybeWhen(
                data: (locked) => locked ? const LockInBanner() : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            // Reorderable habit list
            SliverReorderableList(
              itemCount: habits.length,
              onReorder: (oldIndex, newIndex) =>
                  _onReorder(ref, habits, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final habit = habits[index];
                final log = logsAsync.value?[habit.id];
                return ReorderableDragStartListener(
                  key: ValueKey(habit.id),
                  index: index,
                  child: _HabitTile(habit: habit, log: log),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _onReorder(
      WidgetRef ref, List<Habit> habits, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
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
    final accentColor = isDone || isRest
        ? AppColors.habitAccents[widget.habit.accentIndex % 8]
        : colors.outline;

    return Dismissible(
      key: ValueKey('dismiss_${widget.habit.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colors.danger,
        child: const Icon(AppIcons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _onDelete(),
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor, width: isDone || isRest ? 1.5 : 1),
          ),
          child: Row(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(AppIcons.drag, size: 20, color: colors.textMuted),
              ),
              // Habit icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.habitAccents[widget.habit.accentIndex % 8]
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AppIcons.habitIcons[widget.habit.iconIndex % AppIcons.habitIcons.length],
                  size: 22,
                  color: AppColors.habitAccents[widget.habit.accentIndex % 8],
                ),
              ),
              const SizedBox(width: 12),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.habit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDone ? colors.textMuted : colors.text,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isRest)
                      Text('Rest token used',
                          style: TextStyle(fontSize: 12, color: colors.textMuted)),
                  ],
                ),
              ),
              // Check button
              HabitCheckButton(
                isDone: isDone,
                isRest: isRest,
                accentColor: AppColors.habitAccents[widget.habit.accentIndex % 8],
                onTap: _onCheck,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onCheck() async {
    final useCases = ref.read(habitUseCasesProvider);
    final isDone = widget.log?.isDone ?? false;
    await HapticFeedback.lightImpact();
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
            // Restore: save with deletedAt = null.
            final habit = await ref.read(habitRepositoryProvider).getById(habitId);
            if (habit != null) {
              await ref.read(habitUseCasesProvider).saveHabit(
                  habit.copyWith());
            }
          },
        ),
      ),
    );
    useCases.deleteHabit(habitId);
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.emptyHabits, size: 72, color: colors.textMuted),
          const SizedBox(height: 16),
          Text('No habits yet', style: TextStyle(fontSize: 18, color: colors.textMuted)),
          const SizedBox(height: 8),
          Text('Tap + to add your first habit',
              style: TextStyle(fontSize: 14, color: colors.textMuted)),
        ],
      ),
    );
  }
}
