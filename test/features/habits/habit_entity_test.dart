// test/features/habits/habit_entity_test.dart
// Tests for Habit entity, ScheduleMask, HabitLog domain objects.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';

void main() {
  group('Habit entity', () {
    const today = LocalDate(2026, 10, 4);
    const habit = Habit(
      id: 'h1',
      name: 'Exercise',
      iconIndex: 0,
      accentIndex: 2,
      scheduleMask: ScheduleMask.every,
      startDate: LocalDate(2026, 1, 1),
      sortOrder: 0,
      restTokensPerWeek: 0,
      hlc: '0',
    );

    test('isActive when not archived or deleted', () {
      expect(habit.isActive, isTrue);
    });

    test('isArchived when archivedAt is set', () {
      final archived = habit.copyWith(archivedAt: today);
      expect(archived.isArchived, isTrue);
      expect(archived.isActive, isFalse);
    });

    test('isDeleted when deletedAt is set', () {
      final deleted = habit.copyWith(deletedAt: today);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.isActive, isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      final copy = habit.copyWith(name: 'Run');
      expect(copy.id, habit.id);
      expect(copy.accentIndex, habit.accentIndex);
      expect(copy.name, 'Run');
    });

    test('equality is based on id + hlc', () {
      final a = habit.copyWith(hlc: '1');
      final b = habit.copyWith(hlc: '1');
      expect(a, b);
      final c = habit.copyWith(hlc: '2');
      expect(a, isNot(c));
    });
  });

  group('HabitLog', () {
    const log = HabitLog(
      id: 'l1',
      habitId: 'h1',
      localDate: LocalDate(2026, 10, 4),
      status: HabitLogStatus.done,
      hlc: '0',
    );

    test('isDone true for done status', () {
      expect(log.isDone, isTrue);
    });

    test('isDone false for rest status', () {
      final rest = HabitLog(
        id: 'l2',
        habitId: 'h1',
        localDate: log.localDate,
        status: HabitLogStatus.rest,
        hlc: '0',
      );
      expect(rest.isDone, isFalse);
      expect(rest.isRest, isTrue);
    });

    test('isDone false when soft-deleted', () {
      final deleted = HabitLog(
        id: 'l3',
        habitId: 'h1',
        localDate: log.localDate,
        status: HabitLogStatus.done,
        hlc: '0',
        deletedAt: const LocalDate(2026, 10, 5),
      );
      expect(deleted.isDone, isFalse);
      expect(deleted.isDeleted, isTrue);
    });
  });
}
