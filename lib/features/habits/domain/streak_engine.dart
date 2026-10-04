// lib/features/habits/domain/streak_engine.dart
//
// Pure Dart streak engine — NO Flutter imports.
// Spec §4.2: exact reference algorithm implemented here.
// Spec §2.4 answer 2: rest tokens = floor(trackingDays / 2).

import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';

class StreakEngine {
  const StreakEngine();

  // ── Current streak ─────────────────────────────────────────────────────────
  //
  // Reference algorithm (spec §4.2):
  //   currentStreak(habit, today):
  //     d = today
  //     if !done(habit, d): d = d - 1   // pending today never breaks
  //     n = 0
  //     while d >= habit.startDate:
  //       if !isScheduled(habit, d): d = d-1; continue
  //       if done(habit, d) or restTokenUsed(habit, d): n++; d = d-1
  //       else break
  //     return n

  int currentStreak(Habit habit, List<HabitLog> logs, LocalDate today) {
    final logMap = _toMap(logs);

    LocalDate d = today;
    // Pending today never breaks streak — walk back one day if today not done.
    if (!_isDone(logMap, habit.id, d)) {
      d = d.subtractDays(1);
    }

    int n = 0;
    while (d >= habit.startDate) {
      if (!habit.scheduleMask.isScheduled(d)) {
        // Non-scheduled day: neutral — skip without breaking or extending.
        d = d.subtractDays(1);
        continue;
      }
      if (_isDone(logMap, habit.id, d) || _isRest(logMap, habit.id, d)) {
        n++;
        d = d.subtractDays(1);
      } else {
        break; // Missed scheduled day — streak ends here.
      }
    }
    return n;
  }

  // ── Best streak (all-time max) ─────────────────────────────────────────────

  int bestStreak(Habit habit, List<HabitLog> logs) {
    if (logs.isEmpty) return 0;
    final logMap = _toMap(logs);

    // Find the date range from habit.startDate to max log date.
    final dates = logs
        .where((l) => !l.isDeleted)
        .map((l) => l.localDate)
        .toList()
      ..sort();
    if (dates.isEmpty) return 0;

    final end = dates.last;
    int best = 0;
    int current = 0;
    LocalDate d = habit.startDate;

    while (d <= end) {
      if (!habit.scheduleMask.isScheduled(d)) {
        d = d.addDays(1);
        continue;
      }
      if (_isDone(logMap, habit.id, d) || _isRest(logMap, habit.id, d)) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
      d = d.addDays(1);
    }
    return best;
  }

  // ── Lock-in streak ─────────────────────────────────────────────────────────
  //
  // Consecutive days where ALL scheduled habits were completed.
  // Days with nothing scheduled are neutral.

  int lockInStreak(
    List<Habit> habits,
    Map<String, List<HabitLog>> logsByHabit,
    List<DayLock> dayLocks,
    LocalDate today,
  ) {
    final activeHabits = habits.where((h) => h.isActive).toList();
    if (activeHabits.isEmpty) return 0;

    final lockDates = dayLocks.map((l) => l.localDate).toSet();

    LocalDate d = today;
    // If today not locked in yet, start from yesterday.
    if (!lockDates.contains(d)) {
      d = d.subtractDays(1);
    }

    int n = 0;
    // Walk back up to 365 days for safety.
    for (int i = 0; i < 365; i++) {
      final scheduled = activeHabits
          .where((h) => d >= h.startDate && h.scheduleMask.isScheduled(d))
          .toList();

      if (scheduled.isEmpty) {
        // Neutral day.
        d = d.subtractDays(1);
        continue;
      }

      if (lockDates.contains(d)) {
        n++;
        d = d.subtractDays(1);
      } else {
        break;
      }
    }
    return n;
  }

  // ── Is locked in today ─────────────────────────────────────────────────────

  bool isLockedIn(
    List<Habit> habits,
    List<HabitLog> logsForToday,
    LocalDate today,
  ) {
    final activeScheduled = habits
        .where((h) => h.isActive && h.scheduleMask.isScheduled(today))
        .toList();
    if (activeScheduled.isEmpty) return false;

    final logMap = _toMap(logsForToday);
    return activeScheduled.every(
      (h) => _isDone(logMap, h.id, today) || _isRest(logMap, h.id, today),
    );
  }

  // ── Rest token validation ──────────────────────────────────────────────────

  /// Returns how many rest tokens have been used in the rolling 7-day window
  /// ending on [today] for [habit].
  int restTokensUsedThisWeek(
      Habit habit, List<HabitLog> logs, LocalDate today) {
    final weekStart = today.subtractDays(6);
    final range = DateRange(start: weekStart, end: today);
    return logs
        .where((l) =>
            l.habitId == habit.id &&
            l.status == HabitLogStatus.rest &&
            !l.isDeleted &&
            range.contains(l.localDate))
        .length;
  }

  bool canUseRestToken(Habit habit, List<HabitLog> logs, LocalDate today) {
    final used = restTokensUsedThisWeek(habit, logs, today);
    return used < habit.restTokensPerWeek;
  }

  // ── Milestone check ────────────────────────────────────────────────────────

  static const List<int> milestones = [7, 14, 30, 60, 100, 200, 365];

  /// Returns the milestone value if [streak] just hit one, null otherwise.
  int? hitMilestone(int streak) {
    if (milestones.contains(streak)) return streak;
    return null;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Map<String, HabitLog> _toMap(List<HabitLog> logs) {
    // Key: "habitId|yyyy-MM-dd"
    final map = <String, HabitLog>{};
    for (final log in logs) {
      if (!log.isDeleted) {
        map['${log.habitId}|${log.localDate}'] = log;
      }
    }
    return map;
  }

  bool _isDone(Map<String, HabitLog> map, String habitId, LocalDate date) {
    final log = map['$habitId|$date'];
    return log != null && log.status == HabitLogStatus.done;
  }

  bool _isRest(Map<String, HabitLog> map, String habitId, LocalDate date) {
    final log = map['$habitId|$date'];
    return log != null && log.status == HabitLogStatus.rest;
  }
}
