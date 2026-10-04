// test/features/habits/streak_engine_test.dart
// Spec §15.1: property-based + table tests for the streak engine.
// Covers every scenario from streakin_app_spec.md §4.2.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/streak_engine.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ── Helpers ──────────────────────────────────────────────────────────────────

Habit _habit({
  ScheduleMask schedule = ScheduleMask.every,
  LocalDate? startDate,
  int restTokensPerWeek = 0,
}) {
  return Habit(
    id: _uuid.v4(),
    name: 'Test',
    iconIndex: 0,
    accentIndex: 0,
    scheduleMask: schedule,
    startDate: startDate ?? const LocalDate(2026, 1, 1),
    sortOrder: 0,
    restTokensPerWeek: restTokensPerWeek,
    hlc: '0',
  );
}

HabitLog _log(String habitId, LocalDate date,
    {HabitLogStatus status = HabitLogStatus.done}) {
  return HabitLog(
    id: _uuid.v4(),
    habitId: habitId,
    localDate: date,
    status: status,
    hlc: '0',
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const engine = StreakEngine();
  const today = LocalDate(2026, 10, 4); // Sunday

  group('ScheduleMask', () {
    test('every day schedule — all 7 days scheduled', () {
      const mask = ScheduleMask.every;
      for (int i = 1; i <= 7; i++) {
        expect(mask.isScheduled(today.subtractDays(today.weekday - i)), isTrue);
      }
    });

    test('weekday mask — Mon-Fri only', () {
      const mask = ScheduleMask.weekdays;
      // Monday=1 … Friday=5 are scheduled
      expect(mask.scheduledDaysCount, 5);
      expect(mask.maxRestTokens, 2); // floor(5/2)
    });

    test('fromWeekdays round-trips', () {
      final mask = ScheduleMask.fromWeekdays([1, 3, 5]); // Mon, Wed, Fri
      expect(mask.scheduledDaysCount, 3);
      expect(mask.maxRestTokens, 1); // floor(3/2)
    });

    test('maxRestTokens: 5 days → 2, 6 days → 3, 7 days → 3', () {
      expect(ScheduleMask.fromWeekdays([1, 2, 3, 4, 5]).maxRestTokens, 2);
      expect(ScheduleMask.fromWeekdays([1, 2, 3, 4, 5, 6]).maxRestTokens, 3);
      expect(ScheduleMask.every.maxRestTokens, 3);
    });
  });

  group('currentStreak', () {
    test('7 consecutive completions → streak = 7', () {
      final h = _habit();
      final logs = List.generate(
          7, (i) => _log(h.id, today.subtractDays(i)));
      expect(engine.currentStreak(h, logs, today), 7);
    });

    test('pending today never breaks streak', () {
      final h = _habit();
      // Completed yesterday and 5 days before, but not today (pending)
      final logs = List.generate(
          6, (i) => _log(h.id, today.subtractDays(i + 1)));
      expect(engine.currentStreak(h, logs, today), 6);
    });

    test('missed yesterday breaks streak', () {
      final h = _habit();
      // Completed today and 5 days before, but missed yesterday
      final logs = [
        _log(h.id, today),
        ...List.generate(5, (i) => _log(h.id, today.subtractDays(i + 2))),
      ];
      // today done, but yesterday missed → streak from today = 1, then break
      expect(engine.currentStreak(h, logs, today), 1);
    });

    test('non-scheduled days are neutral — do not break streak', () {
      // Mon-Fri only schedule
      final mask = ScheduleMask.fromWeekdays([1, 2, 3, 4, 5]);
      // today = Sunday 2026-10-04; let's use a Monday
      const monday = LocalDate(2026, 10, 5);
      final h = _habit(schedule: mask, startDate: const LocalDate(2026, 9, 1));
      // Completed Mon through Fri last week, nothing on weekend
      final logs = [
        _log(h.id, const LocalDate(2026, 9, 28)), // Mon
        _log(h.id, const LocalDate(2026, 9, 29)), // Tue
        _log(h.id, const LocalDate(2026, 9, 30)), // Wed
        _log(h.id, const LocalDate(2026, 10, 1)), // Thu
        _log(h.id, const LocalDate(2026, 10, 2)), // Fri
        // Sat/Sun not scheduled — neutral
        _log(h.id, const LocalDate(2026, 10, 5)), // Mon (today)
      ];
      expect(engine.currentStreak(h, logs, monday), 6);
    });

    test('rest token used preserves streak', () {
      final h = _habit(restTokensPerWeek: 1);
      final logs = [
        _log(h.id, today),
        _log(h.id, today.subtractDays(1), status: HabitLogStatus.rest),
        _log(h.id, today.subtractDays(2)),
        _log(h.id, today.subtractDays(3)),
      ];
      expect(engine.currentStreak(h, logs, today), 4);
    });

    test('skipped log breaks streak', () {
      final h = _habit();
      final logs = [
        _log(h.id, today),
        _log(h.id, today.subtractDays(1), status: HabitLogStatus.skipped),
        _log(h.id, today.subtractDays(2)),
      ];
      // today done, yesterday skipped → streak = 1
      expect(engine.currentStreak(h, logs, today), 1);
    });

    test('soft-deleted log treated as not done', () {
      final h = _habit();
      final deletedLog = HabitLog(
        id: _uuid.v4(),
        habitId: h.id,
        localDate: today.subtractDays(1),
        status: HabitLogStatus.done,
        hlc: '0',
        deletedAt: today, // soft-deleted
      );
      final logs = [_log(h.id, today), deletedLog];
      // Yesterday's log is deleted → treated as missed → streak = 1
      expect(engine.currentStreak(h, logs, today), 1);
    });

    test('habit not started yet → streak = 0', () {
      final h = _habit(startDate: today.addDays(5));
      expect(engine.currentStreak(h, [], today), 0);
    });

    test('empty logs → streak = 0', () {
      final h = _habit();
      expect(engine.currentStreak(h, [], today), 0);
    });

    test('day boundary: completion date keyed to LocalDate not UTC', () {
      // Spec: completions keyed (habitId, localDate) — no UTC shifting
      final h = _habit();
      final log = HabitLog(
        id: _uuid.v4(),
        habitId: h.id,
        localDate: today, // local date key — unaffected by timezone
        status: HabitLogStatus.done,
        hlc: '0',
      );
      expect(engine.currentStreak(h, [log], today), 1);
    });
  });

  group('bestStreak', () {
    test('returns maximum streak over all time', () {
      final h = _habit();
      // 10 consecutive then gap then 5 consecutive
      final logs = [
        ...List.generate(10, (i) => _log(h.id, const LocalDate(2026, 1, 10).subtractDays(i))),
        // gap Jan 11-15
        ...List.generate(5, (i) => _log(h.id, const LocalDate(2026, 1, 20).subtractDays(i))),
      ];
      expect(engine.bestStreak(h, logs), 10);
    });

    test('empty logs → 0', () {
      expect(engine.bestStreak(_habit(), []), 0);
    });

    test('single completion → 1', () {
      final h = _habit();
      expect(engine.bestStreak(h, [_log(h.id, today)]), 1);
    });
  });

  group('lockInStreak', () {
    test('all habits done each day → lock-in streak', () {
      final h1 = _habit();
      final h2 = _habit();
      final dayLocks = List.generate(
          5, (i) => DayLock(localDate: today.subtractDays(i), lockedAt: DateTime.now()));
      final logsByHabit = {
        h1.id: List.generate(5, (i) => _log(h1.id, today.subtractDays(i))),
        h2.id: List.generate(5, (i) => _log(h2.id, today.subtractDays(i))),
      };
      expect(engine.lockInStreak([h1, h2], logsByHabit, dayLocks, today), 5);
    });

    test('today not locked in → starts from yesterday', () {
      final h = _habit();
      final dayLocks = [
        DayLock(localDate: today.subtractDays(1), lockedAt: DateTime.now()),
        DayLock(localDate: today.subtractDays(2), lockedAt: DateTime.now()),
        DayLock(localDate: today.subtractDays(3), lockedAt: DateTime.now()),
      ];
      expect(engine.lockInStreak([h], {h.id: []}, dayLocks, today), 3);
    });

    test('no habits → 0', () {
      expect(engine.lockInStreak([], {}, [], today), 0);
    });

    test('neutral days (nothing scheduled) do not break lock-in streak', () {
      final h = _habit(schedule: ScheduleMask.fromWeekdays([1, 2, 3, 4, 5]));
      // Mon-Fri only. Sat/Sun are neutral.
      // Build 5 DayLocks for Mon-Fri of last week
      const friday = LocalDate(2026, 10, 2);
      const monday = LocalDate(2026, 9, 28);
      final dayLocks = const DateRange(start: monday, end: friday)
          .dates
          .map((d) => DayLock(localDate: d, lockedAt: DateTime.now()))
          .toList();
      // today = Sunday Oct 4; last DayLock = Friday Oct 2 → streak = 5
      expect(engine.lockInStreak([h], {h.id: []}, dayLocks, today), 5);
    });
  });

  group('isLockedIn', () {
    test('all habits done → locked in', () {
      final h1 = _habit();
      final h2 = _habit();
      final logs = [_log(h1.id, today), _log(h2.id, today)];
      expect(engine.isLockedIn([h1, h2], logs, today), isTrue);
    });

    test('one habit not done → not locked in', () {
      final h1 = _habit();
      final h2 = _habit();
      final logs = [_log(h1.id, today)]; // h2 not done
      expect(engine.isLockedIn([h1, h2], logs, today), isFalse);
    });

    test('no habits scheduled today → false', () {
      final mask = ScheduleMask.fromWeekdays([1]); // Monday only
      final h = _habit(schedule: mask); // today is Sunday
      expect(engine.isLockedIn([h], [], today), isFalse);
    });

    test('rest token counts as done for lock-in', () {
      final h = _habit(restTokensPerWeek: 1);
      final logs = [_log(h.id, today, status: HabitLogStatus.rest)];
      expect(engine.isLockedIn([h], logs, today), isTrue);
    });
  });

  group('restTokenValidation', () {
    test('canUseRestToken false when weekly cap reached', () {
      final h = _habit(restTokensPerWeek: 2);
      final logs = [
        _log(h.id, today.subtractDays(1), status: HabitLogStatus.rest),
        _log(h.id, today.subtractDays(2), status: HabitLogStatus.rest),
      ];
      expect(engine.canUseRestToken(h, logs, today), isFalse);
    });

    test('canUseRestToken true when cap not reached', () {
      final h = _habit(restTokensPerWeek: 2);
      final logs = [
        _log(h.id, today.subtractDays(1), status: HabitLogStatus.rest),
      ];
      expect(engine.canUseRestToken(h, logs, today), isTrue);
    });

    test('restTokensUsedThisWeek counts rolling 7-day window only', () {
      final h = _habit(restTokensPerWeek: 3);
      final logs = [
        _log(h.id, today.subtractDays(8), status: HabitLogStatus.rest), // outside window
        _log(h.id, today.subtractDays(3), status: HabitLogStatus.rest),
        _log(h.id, today.subtractDays(1), status: HabitLogStatus.rest),
      ];
      expect(engine.restTokensUsedThisWeek(h, logs, today), 2);
    });
  });

  group('milestones', () {
    test('hitMilestone returns value at milestone days', () {
      for (final m in [7, 14, 30, 60, 100, 200, 365]) {
        expect(engine.hitMilestone(m), m);
      }
    });

    test('hitMilestone returns null for non-milestone', () {
      expect(engine.hitMilestone(8), isNull);
      expect(engine.hitMilestone(0), isNull);
      expect(engine.hitMilestone(99), isNull);
    });
  });
}
