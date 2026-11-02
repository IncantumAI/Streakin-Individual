// Track 4A: flagged to-dos gate the day lock-in (setting countTodosForLockIn).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';

class _MockRepo extends Mock implements HabitRepository {}

void main() {
  late _MockRepo repo;
  late ProviderContainer container;
  final today = LocalDate.today();
  final habit = Habit(
    id: 'h1',
    name: 'Read',
    iconIndex: 0,
    accentIndex: 0,
    scheduleMask: ScheduleMask.every,
    startDate: today.subtractDays(30),
    sortOrder: 0,
    restTokensPerWeek: 1,
    hlc: 'h',
  );

  setUpAll(() {
    registerFallbackValue(today);
    registerFallbackValue(DateRange(start: today, end: today));
    registerFallbackValue(DayLock(localDate: today, lockedAt: DateTime(2026)));
    registerFallbackValue(
      HabitLog(
        id: 'x',
        habitId: 'h1',
        localDate: today,
        status: HabitLogStatus.done,
        hlc: 'h',
      ),
    );
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.saveLog(any())).thenAnswer((_) async {});
    when(() => repo.saveDayLock(any())).thenAnswer((_) async {});
    when(() => repo.watchActiveForDate(any()))
        .thenAnswer((_) => Stream.value([habit]));
    when(() => repo.watchDayLock(any())).thenAnswer((_) => Stream.value(null));
    when(() => repo.fetchLogsForHabits(any(), any())).thenAnswer(
      (_) async => {
        'h1': [
          HabitLog(
            id: 'l1',
            habitId: 'h1',
            localDate: today,
            status: HabitLogStatus.done,
            hlc: 'h',
          ),
        ],
      },
    );
    container = ProviderContainer();
    container.read(habitRepositoryStateProvider.notifier).set(repo);
  });

  tearDown(() => container.dispose());

  test('no gate (setting off) → locks in when all habits done', () async {
    await container.read(habitUseCasesProvider).checkHabit('h1');
    verify(() => repo.saveDayLock(any())).called(1);
  });

  test('gate blocks lock-in while a flagged to-do is undone', () async {
    container.read(lockInGateStateProvider.notifier).set((_) async => false);
    await container.read(habitUseCasesProvider).checkHabit('h1');
    verifyNever(() => repo.saveDayLock(any()));
  });

  test('gate open (all flagged to-dos done) → locks in', () async {
    container.read(lockInGateStateProvider.notifier).set((_) async => true);
    await container.read(habitUseCasesProvider).checkHabit('h1');
    verify(() => repo.saveDayLock(any())).called(1);
  });

  test('reevaluateLockIn locks in once the gate opens', () async {
    var open = false;
    container.read(lockInGateStateProvider.notifier).set((_) async => open);
    await container.read(habitUseCasesProvider).checkHabit('h1');
    verifyNever(() => repo.saveDayLock(any()));
    open = true;
    await container.read(habitUseCasesProvider).reevaluateLockIn();
    verify(() => repo.saveDayLock(any())).called(1);
  });
}
