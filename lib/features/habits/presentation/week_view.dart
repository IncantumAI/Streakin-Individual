// lib/features/habits/presentation/week_view.dart
// Spec §4.2 FR-HAB-3: 7-column grid, completion dots, weekly %.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';

class WeekView extends ConsumerWidget {
  const WeekView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(allHabitsProvider);
    final today = ref.watch(todayProvider);
    final weekStart = ref.watch(weekStartProvider);

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (habits) {
        final active = habits.where((h) => h.isActive).toList();
        if (active.isEmpty) {
          return const Center(child: Text('No habits yet'));
        }
        final weekDays = _weekDays(today, weekStart);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeekHeader(days: weekDays),
            const SizedBox(height: 8),
            ...active.map((h) => _HabitWeekRow(habit: h, days: weekDays, ref: ref)),
          ],
        );
      },
    );
  }

  List<LocalDate> _weekDays(LocalDate today, int weekStart) {
    // Find the start of this week.
    int offset = (today.weekday - weekStart + 7) % 7;
    final start = today.subtractDays(offset);
    return List.generate(7, start.addDays);
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.days});
  final List<LocalDate> days;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = LocalDate.today();
    return Row(
      children: [
        const SizedBox(width: 140),
        ...days.map((d) {
          final isToday = d == today;
          return Expanded(
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: isToday
                    ? BoxDecoration(
                        color: colors.brand,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Center(
                  child: Text(
                    _labels[(d.weekday - 1) % 7],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToday ? colors.onBrand : colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _HabitWeekRow extends ConsumerWidget {
  const _HabitWeekRow({required this.habit, required this.days, required this.ref});
  final Habit habit;
  final List<LocalDate> days;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.watch(habitRepositoryProvider);
    final range = DateRange(start: days.first, end: days.last);

    return FutureBuilder<Map<String, List<HabitLog>>>(
      future: repo.fetchLogsForHabits([habit.id], range),
      builder: (context, snap) {
        final logMap = snap.data?[habit.id] ?? [];
        final logs = {for (final l in logMap) l.localDate.toIso(): l};

        // Weekly completion %
        final scheduled = days.where(habit.scheduleMask.isScheduled).length;
        final done = days.where((d) {
          final l = logs[d.toIso()];
          return l != null && (l.isDone || l.isRest);
        }).length;
        final pct = scheduled == 0 ? 0.0 : done / scheduled;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline),
          ),
          child: Row(
            children: [
              // Habit name
              SizedBox(
                width: 120,
                child: Text(habit.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              // Day dots
              ...days.map((d) {
                final log = logs[d.toIso()];
                final scheduled = habit.scheduleMask.isScheduled(d);
                final accent = AppColors.habitAccents[habit.accentIndex % 8];
                Color dotColor;
                if (!scheduled) {
                  dotColor = Colors.transparent;
                } else if (log?.isDone == true) {
                  dotColor = accent;
                } else if (log?.isRest == true) {
                  dotColor = accent.withValues(alpha: 0.4);
                } else {
                  dotColor = colors.outline;
                }
                return Expanded(
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        border: scheduled && log == null
                            ? Border.all(color: colors.outline, width: 1.5)
                            : null,
                      ),
                    ),
                  ),
                );
              }),
              // Weekly %
              SizedBox(
                width: 36,
                child: Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(
                      fontSize: 12,
                      color: pct == 1.0 ? colors.success : colors.textMuted),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
