// lib/features/habits/presentation/habit_heatmap.dart
// Heatmap grid (GitHub style) plus the "all habits" page with one per habit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/shared/widgets/widgets.dart';

const heatmapWeeks = 16;

/// Intensity (0..1) per day for the last [heatmapWeeks] weeks.
/// [habits] with more than one entry gives the aggregated completion ratio.
/// Work done on an unscheduled (rest) day still counts.
final habitHeatmapProvider =
    FutureProvider.family<Map<LocalDate, double>, List<String>>((
      ref,
      ids,
    ) async {
      final repo = ref.watch(habitRepositoryStateProvider);
      if (repo == null || ids.isEmpty) return {};
      // Re-compute whenever today's logs change.
      ref.watch(todayLogsProvider);
      final habits = (await repo.watchAll().first)
          .where((h) => ids.contains(h.id))
          .toList();
      final today = ref.watch(todayProvider);
      final start = _gridStart(today);
      final logs = await repo.fetchLogsForHabits(
        ids,
        DateRange(start: start, end: today),
      );
      final result = <LocalDate, double>{};
      for (final d in DateRange(start: start, end: today).dates) {
        var scheduled = 0;
        var done = 0;
        for (final h in habits) {
          if (d < h.startDate) continue;
          final isDone =
              logs[h.id]?.any(
                (l) => l.localDate == d && (l.isDone || l.isRest),
              ) ==
              true;
          if (h.scheduleMask.isScheduled(d)) scheduled++;
          if (isDone) done++;
        }
        final denom = scheduled == 0 ? done : scheduled;
        result[d] = denom == 0 ? 0 : (done / denom).clamp(0.0, 1.0);
      }
      return result;
    });

/// Monday of the first column.
LocalDate _gridStart(LocalDate today) {
  final thisMonday = today.subtractDays(today.weekday - 1);
  return thisMonday.subtractDays((heatmapWeeks - 1) * 7);
}

class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({
    super.key,
    required this.values,
    required this.today,
    required this.color,
    this.cell = 14,
  });

  final Map<LocalDate, double> values;
  final LocalDate today;
  final Color color;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final start = _gridStart(today);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (var w = 0; w < heatmapWeeks; w++)
            Column(
              children: [
                for (var d = 0; d < 7; d++)
                  _cell(colors, start.addDays(w * 7 + d)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(AppColorTokens colors, LocalDate date) {
    final future = date > today;
    final v = values[date] ?? 0;
    return Container(
      width: cell,
      height: cell,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: future
            ? AppColors.transparent
            : v == 0
            ? colors.surfaceAlt
            : color.withValues(alpha: 0.25 + 0.75 * v),
        border: date == today
            ? Border.all(color: colors.text.withValues(alpha: 0.5))
            : null,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class HabitHeatmapsScreen extends ConsumerWidget {
  const HabitHeatmapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final habitsAsync = ref.watch(allHabitsProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Habit heatmaps')),
      body: habitsAsync.when(
        loading: () => const SkeletonList(count: 3, showLeading: false),
        error: (e, st) => ErrorState(
          error: e,
          stackTrace: st,
          onRetry: () => ref.invalidate(allHabitsProvider),
        ),
        data: (all) {
          final habits = all.where((h) => h.isActive).toList();
          if (habits.isEmpty) {
            return const EmptyState(
              icon: AppIcons.emptyHabits,
              title: 'No habits yet',
              message: 'Heatmaps fill in as you check in each day.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpace.lg),
            itemCount: habits.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
            itemBuilder: (_, i) => StaggeredEntrance(
              index: i,
              child: _HabitHeatmapCard(habit: habits[i]),
            ),
          );
        },
      ),
    );
  }
}

class _HabitHeatmapCard extends ConsumerWidget {
  const _HabitHeatmapCard({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = AppColors.habitAccents[habit.accentIndex % 8];
    final data = ref.watch(habitHeatmapProvider([habit.id]));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  AppIcons.habitIcons[habit.iconIndex %
                      AppIcons.habitIcons.length],
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(habit.name, style: context.text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          data.when(
            loading: () => const SkeletonCard(),
            error: (e, st) => ErrorState.inline(error: e, stackTrace: st),
            data: (values) => HeatmapGrid(
              values: values,
              today: ref.watch(todayProvider),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
