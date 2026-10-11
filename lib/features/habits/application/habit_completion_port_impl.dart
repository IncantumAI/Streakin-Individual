import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';

class HabitCompletionPortImpl implements HabitCompletionPort {
  HabitCompletionPortImpl(this._habitRepo);
  final HabitRepository _habitRepo;

  @override
  Future<AlignmentStats> closedDayStats({
    required List<HabitLinkWindow> windows,
    required LocalDate through,
    required int goalRestTokenPool,
  }) async {
    if (windows.isEmpty) {
      return const AlignmentStats(
        scheduled: 0,
        done: 0,
        perfectDays: 0,
        perHabit: {},
        bestStreak: 0,
      );
    }

    // Determine the date range to fetch
    final rangeStart = windows
        .map((w) => w.from)
        .reduce((a, b) => a < b ? a : b);
    final range = DateRange(start: rangeStart, end: through);

    final habitIds = windows.map((w) => w.habitId).toSet().toList();
    final habitsMap = <String, Habit>{};
    for (final id in habitIds) {
      final h = await _habitRepo.getById(id);
      if (h != null) habitsMap[id] = h;
    }

    final logsMap =
        await _habitRepo.fetchLogsForHabits(habitIds, range);

    // Rest token pool tracking (goal-level, non-retroactive)
    int tokensLeft = goalRestTokenPool;
    // We process days in order so token consumption is deterministic
    final allDates = range.dates.toList();

    int totalScheduled = 0;
    int totalDone = 0;
    int perfectDays = 0;
    final perHabit = <String, ({int sched, int done})>{};
    int currentStreak = 0;
    int bestStreak = 0;

    for (final day in allDates) {
      if (day > through) break;

      int dayScheduled = 0;
      int dayDone = 0;

      for (final window in windows) {
        if (day < window.from) continue;
        if (window.to != null && day > window.to!) continue;

        final habit = habitsMap[window.habitId];
        if (habit == null) continue;
        if (!habit.scheduleMask.isScheduled(day)) continue;

        // Find log for this habit+day
        final logs = logsMap[window.habitId] ?? [];
        final log = logs.cast<HabitLog?>().firstWhere(
              (l) => l != null && l.localDate == day && !l.isDeleted,
              orElse: () => null,
            );

        if (log == null) {
          // No log = missed
          dayScheduled++;
        } else if (log.status == HabitLogStatus.done) {
          dayScheduled++;
          dayDone++;
          final ph = perHabit[window.habitId] ?? (sched: 0, done: 0);
          perHabit[window.habitId] =
              (sched: ph.sched + 1, done: ph.done + 1);
        } else if (log.status == HabitLogStatus.rest) {
          if (tokensLeft > 0) {
            tokensLeft--;
            // neutral — don't count in scheduled or done
          } else {
            // token exhausted → counts as missed
            dayScheduled++;
          }
          final ph = perHabit[window.habitId] ?? (sched: 0, done: 0);
          perHabit[window.habitId] = (sched: ph.sched, done: ph.done);
        } else if (log.status == HabitLogStatus.skipped) {
          if (tokensLeft > 0) {
            // skipped neutral only while tokens available (per spec Q1 answer)
            tokensLeft--;
          } else {
            dayScheduled++;
          }
        }
      }

      totalScheduled += dayScheduled;
      totalDone += dayDone;

      if (dayScheduled > 0 && dayDone == dayScheduled) {
        perfectDays++;
        currentStreak++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else if (dayScheduled > 0) {
        currentStreak = 0;
      }
    }

    return AlignmentStats(
      scheduled: totalScheduled,
      done: totalDone,
      perfectDays: perfectDays,
      perHabit: {
        for (final e in perHabit.entries)
          e.key: PerHabitStats(scheduled: e.value.sched, done: e.value.done),
      },
      bestStreak: bestStreak,
    );
  }

  @override
  Stream<List<HabitRef>> watchHabits(Set<String> habitIds) {
    return _habitRepo.watchAll().map((habits) => habits
        .where((h) => habitIds.contains(h.id))
        .map((h) => HabitRef(id: h.id, name: h.name))
        .toList());
  }

  @override
  Future<({int done, int scheduled})> todayLiveStats({
    required List<String> habitIds,
    required LocalDate today,
  }) async {
    int scheduled = 0;
    int done = 0;
    for (final id in habitIds) {
      final habit = await _habitRepo.getById(id);
      if (habit == null || !habit.isActive) continue;
      if (!habit.scheduleMask.isScheduled(today)) continue;
      scheduled++;
      final log = await _habitRepo.getLog(id, today);
      if (log != null && log.isDone) done++;
    }
    return (done: done, scheduled: scheduled);
  }
}
