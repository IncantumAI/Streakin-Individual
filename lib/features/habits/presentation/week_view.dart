// lib/features/habits/presentation/week_view.dart
// Spec §4.2 FR-HAB-3: 7-column grid, completion dots, weekly %.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';
import 'package:streakin/shared/widgets/widgets.dart';

class WeekView extends ConsumerWidget {
  const WeekView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(allHabitsProvider);
    final today = ref.watch(todayProvider);
    final weekStart = ref.watch(weekStartProvider);

    return habitsAsync.when(
      loading: () => const SkeletonList(count: 4, showLeading: false),
      error: (e, st) => ErrorState(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(allHabitsProvider),
      ),
      data: (habits) {
        final active = habits.where((h) => h.isActive).toList();
        if (active.isEmpty) {
          return const EmptyState(
            icon: AppIcons.emptyHabits,
            title: 'No habits yet',
            message: 'Your week at a glance appears here once you add one.',
          );
        }
        final weekDays = _weekDays(today, weekStart);
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
            96,
          ),
          children: [
            _WeekHeader(days: weekDays),
            const SizedBox(height: AppSpace.sm),
            for (var i = 0; i < active.length; i++)
              StaggeredEntrance(
                index: i,
                child: _HabitWeekRow(
                  habit: active[i],
                  days: weekDays,
                  ref: ref,
                ),
              ),
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
        const SizedBox(width: 120 + AppSpace.sm + AppSpace.md),
        ...days.map((d) {
          final isToday = d == today;
          return Expanded(
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: isToday
                    ? BoxDecoration(color: colors.brand, shape: BoxShape.circle)
                    : null,
                child: Center(
                  child: Text(
                    _labels[(d.weekday - 1) % 7],
                    style: context.text.labelMedium!.copyWith(
                      fontWeight: FontWeight.w700,
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
  const _HabitWeekRow({
    required this.habit,
    required this.days,
    required this.ref,
  });
  final Habit habit;
  final List<LocalDate> days;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.watch(habitRepositoryStateProvider);
    if (repo == null) return const SizedBox.shrink();
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

        final accent = AppColors.habitAccents[habit.accentIndex % 8];
        return AppCard(
          margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.md,
          ),
          child: Row(
            children: [
              // Habit name
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        habit.name,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              // Day dots
              ...days.map((d) {
                final log = logs[d.toIso()];
                final scheduled = habit.scheduleMask.isScheduled(d);
                final isDone = log?.isDone == true;
                final isRest = log?.isRest == true;
                Color fill;
                Color? border;
                if (!scheduled) {
                  fill = AppColors.transparent;
                } else if (isDone) {
                  fill = accent;
                } else if (isRest) {
                  fill = accent.withValues(alpha: 0.25);
                } else {
                  fill = AppColors.transparent;
                  border = colors.outlineStrong.withValues(alpha: 0.5);
                }
                return Expanded(
                  child: Center(
                    child: Container(
                      width: scheduled ? 20 : 6,
                      height: scheduled ? 20 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheduled ? fill : colors.outline,
                        border: border == null
                            ? null
                            : Border.all(color: border, width: 1.5),
                      ),
                      child: isDone
                          ? Icon(
                              AppIcons.check,
                              size: 13,
                              color: colors.onBrand,
                            )
                          : null,
                    ),
                  ),
                );
              }),
              // Weekly %
              SizedBox(
                width: 36,
                child: Text(
                  '${(pct * 100).round()}%',
                  style: context.text.labelMedium!.copyWith(
                    fontFeatures: AppTypography.tabular,
                    fontWeight: FontWeight.w600,
                    color: pct == 1.0 ? colors.success : colors.textMuted,
                  ),
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
