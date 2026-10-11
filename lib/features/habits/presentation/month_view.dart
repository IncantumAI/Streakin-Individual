// lib/features/habits/presentation/month_view.dart
// Spec §4.2 FR-HAB-3: heat-grid per habit, monthly %, best streak in month.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';

class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key});
  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(allHabitsProvider);
    final colors = context.colors;

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (habits) {
        final active = habits.where((h) => h.isActive).toList();
        return ListView(
          children: [
            // Month navigator
            TableCalendar<Object?>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              headerStyle: const HeaderStyle(formatButtonVisible: false),
              onPageChanged: (day) => setState(() => _focusedDay = day),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: colors.brand,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Divider(height: 1),
            // Per-habit heat strip
            ...active.map((h) => _HabitMonthCard(
                  habit: h,
                  focusedMonth: _focusedDay,
                )),
          ],
        );
      },
    );
  }
}

class _HabitMonthCard extends ConsumerWidget {
  const _HabitMonthCard({required this.habit, required this.focusedMonth});
  final Habit habit;
  final DateTime focusedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.watch(habitRepositoryStateProvider);
    if (repo == null) return const SizedBox.shrink();
    final engine = ref.watch(streakEngineProvider);

    final firstDay = LocalDate(focusedMonth.year, focusedMonth.month, 1);
    final lastDay = LocalDate(focusedMonth.year, focusedMonth.month,
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month));
    final range = DateRange(start: firstDay, end: lastDay);

    return FutureBuilder<Map<String, List<HabitLog>>>(
      future: repo.fetchLogsForHabits([habit.id], range),
      builder: (context, snap) {
        final logs = snap.data?[habit.id] ?? [];
        final logMap = {for (final l in logs) l.localDate.toIso(): l};

        // Monthly %
        final scheduledDays =
            range.dates.where(habit.scheduleMask.isScheduled).length;
        final doneDays = logs.where((l) => l.isDone || l.isRest).length;
        final pct = scheduledDays == 0 ? 0.0 : doneDays / scheduledDays;

        // Best streak in month
        final bestInMonth = engine.bestStreak(habit, logs);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(habit.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${(pct * 100).round()}%',
                      style: TextStyle(fontSize: 13, color: colors.textMuted)),
                  const SizedBox(width: 12),
                  Text('Best: $bestInMonth',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.streakLight)),
                ],
              ),
              const SizedBox(height: 10),
              // Heat grid — days of month
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: range.dates.map((d) {
                  final log = logMap[d.toIso()];
                  final scheduled = habit.scheduleMask.isScheduled(d);
                  final accent = AppColors.habitAccents[habit.accentIndex % 8];
                  Color cellColor;
                  if (!scheduled) {
                    cellColor = colors.surfaceAlt;
                  } else if (log?.isDone == true) {
                    cellColor = accent;
                  } else if (log?.isRest == true) {
                    cellColor = accent.withValues(alpha: 0.4);
                  } else if (d <= LocalDate.today()) {
                    cellColor = colors.danger.withValues(alpha: 0.2);
                  } else {
                    cellColor = colors.outline;
                  }
                  return Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 10,
                          color: log?.isDone == true
                              ? Colors.white
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
