import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';

Goal _goal({
  GoalKind kind = GoalKind.dated,
  required String start,
  String? end,
  int accent = 0,
}) {
  final now = DateTime.now();
  return Goal(
    id: 'g1',
    title: 'Test goal',
    kind: kind,
    startDate: LocalDate.parse(start),
    endDate: end != null ? LocalDate.parse(end) : null,
    status: GoalStatus.active,
    activatedHlc: '0-0000-0000',
    accentIndex: accent,
    restTokenPool: 4,
    createdAt: now,
    updatedAt: now,
    hlc: '0-0000-0000',
  );
}

void main() {
  group('GoalClock — dated', () {
    test('upcoming: today < start', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-06-05'));
      expect(clock.phase, GoalPhase.upcoming);
      expect(clock.daysUntilStart, 5);
      expect(clock.dayNumber, 0);
      expect(clock.progress, 0.0);
    });

    test('day 1: today == start', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-06-10'));
      expect(clock.phase, GoalPhase.active);
      expect(clock.dayNumber, 1);
      expect(clock.totalDays, 100);
      expect(clock.daysLeft, 99);
      expect(clock.progress, closeTo(0.01, 0.001));
    });

    test('mid: day 42 of 100', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-07-21'));
      expect(clock.phase, GoalPhase.active);
      expect(clock.dayNumber, 42);
      expect(clock.daysLeft, 58);
      expect(clock.progress, closeTo(0.42, 0.001));
    });

    test('final day', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-09-17'));
      expect(clock.phase, GoalPhase.finalDay);
      expect(clock.daysLeft, 0);
      expect(clock.progress, 1.0);
    });

    test('ended: today > end', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-09-20'));
      expect(clock.phase, GoalPhase.ended);
      expect(clock.progress, 1.0);
    });

    test('same-day goal (start == end)', () {
      final g = _goal(start: '2030-06-10', end: '2030-06-10');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-06-10'));
      expect(clock.phase, GoalPhase.finalDay);
      expect(clock.totalDays, 1);
      expect(clock.daysLeft, 0);
    });

    test('final stretch: daysLeft <= 7', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-09-11'));
      expect(clock.isFinalStretch, isTrue);
      expect(clock.daysLeft, 6);
    });

    test('not final stretch when > 7 days left', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-09-09'));
      expect(clock.isFinalStretch, isFalse);
      expect(clock.daysLeft, 8);
    });

    test('leap day included correctly', () {
      final g = _goal(start: '2028-02-28', end: '2028-03-01');
      final clock = GoalClock.compute(g, LocalDate.parse('2028-02-29'));
      expect(clock.dayNumber, 2);
      expect(clock.totalDays, 3);
    });
  });

  group('GoalClock — open-ended', () {
    test('upcoming: today < start', () {
      final g = _goal(kind: GoalKind.open, start: '2030-06-10');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-06-08'));
      expect(clock.phase, GoalPhase.upcoming);
      expect(clock.daysUntilStart, 2);
    });

    test('day 1', () {
      final g = _goal(kind: GoalKind.open, start: '2030-06-10');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-06-10'));
      expect(clock.phase, GoalPhase.active);
      expect(clock.dayNumber, 1);
      expect(clock.nextMilestone, 7);
    });

    test('day 7 — milestone', () {
      final g = _goal(kind: GoalKind.open, start: '2030-06-10');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-06-16'));
      expect(clock.dayNumber, 7);
      expect(clock.nextMilestone, 30);
    });

    test('day 42 — next milestone is 50', () {
      final g = _goal(kind: GoalKind.open, start: '2030-01-01');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-02-11'));
      expect(clock.dayNumber, 42);
      expect(clock.nextMilestone, 50);
      expect(clock.daysToNextMilestone, 8);
    });

    test('day 400 — beyond 365, next milestone > 365', () {
      final g = _goal(kind: GoalKind.open, start: '2029-01-01');
      // 2030-02-05 is day 401 from 2029-01-01
      final clock =
          GoalClock.compute(g, LocalDate.parse('2030-02-05'));
      expect(clock.dayNumber, greaterThan(365));
      expect(clock.nextMilestone!, greaterThan(365));
    });

    test('progress to next milestone in [0,1]', () {
      final g = _goal(kind: GoalKind.open, start: '2030-01-01');
      for (var d = 1; d < 200; d++) {
        final clock = GoalClock.compute(
            g, LocalDate.parse('2030-01-01').addDays(d - 1));
        expect(clock.progressToNextMilestone,
            inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('GoalClock — caption', () {
    test('upcoming caption', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-06-05'));
      expect(clock.caption, contains('5 day'));
    });

    test('active dated caption', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-07-21'));
      expect(clock.caption, 'Day 42 of 100');
    });

    test('final day caption', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-09-17'));
      expect(clock.caption, 'Last day');
    });

    test('ended caption', () {
      final g = _goal(start: '2030-06-10', end: '2030-09-17');
      final clock = GoalClock.compute(g, LocalDate.parse('2030-09-20'));
      expect(clock.caption, 'Goal complete');
    });
  });

  group('GoalClock — milestone helpers', () {
    test('nextOpenMilestone < 7 → 7', () {
      expect(nextOpenMilestone(1), 7);
      expect(nextOpenMilestone(6), 7);
    });

    test('nextOpenMilestone at each fixed milestone', () {
      expect(nextOpenMilestone(7), 30);
      expect(nextOpenMilestone(30), 50);
      expect(nextOpenMilestone(100), 200);
      expect(nextOpenMilestone(365), 465);
      expect(nextOpenMilestone(465), 565);
    });

    test('prevOpenMilestone', () {
      expect(prevOpenMilestone(1), 0);
      expect(prevOpenMilestone(7), 0);
      expect(prevOpenMilestone(8), 7);
      expect(prevOpenMilestone(31), 30);
      expect(prevOpenMilestone(366), 365);
    });
  });
}
