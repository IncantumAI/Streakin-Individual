// lib/features/habits/presentation/habit_heatmap.dart
// Heatmap grid (GitHub style) plus the "all habits" page with one per habit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';

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
            ? Colors.transparent
            : v == 0
            ? colors.outline.withValues(alpha: 0.5)
            : color.withValues(alpha: 0.25 + 0.75 * v),
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
      appBar: AppBar(title: const Text('Habit Heatmaps')),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load habits')),
        data: (all) {
          final habits = all.where((h) => h.isActive).toList();
          if (habits.isEmpty) {
            return Center(
              child: Text(
                'No habits yet.',
                style: TextStyle(color: colors.textMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: habits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _HabitHeatmapCard(habit: habits[i]),
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
    final colors = context.colors;
    final accent = AppColors.habitAccents[habit.accentIndex % 8];
    final data = ref.watch(habitHeatmapProvider([habit.id]));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habit.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 12),
          data.when(
            loading: () => const SizedBox(height: 120),
            error: (_, _) => const SizedBox(height: 120),
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
