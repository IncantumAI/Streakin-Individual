// lib/features/habits/application/habit_providers.dart
// Riverpod providers for habits feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/habits/domain/streak_engine.dart';

// ── Repository state (set by SessionScope after DB opens) ─────────────────

/// Holds the live HabitRepository. SessionScope sets this after DB open.
/// Notifier-based so it works in Riverpod 3 (StateProvider was removed).
class _HabitRepositoryNotifier extends Notifier<HabitRepository?> {
  @override
  HabitRepository? build() => null;

  void set(HabitRepository repo) => state = repo;
  void clear() => state = null;
}

final habitRepositoryStateProvider =
    NotifierProvider<_HabitRepositoryNotifier, HabitRepository?>(
        _HabitRepositoryNotifier.new);

/// Convenience provider — throws clearly if SessionScope has not yet set it.
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) {
    throw UnimplementedError('habitRepositoryProvider must be overridden in SessionScope');
  }
  return repo;
});

// ── Streak engine (stateless, singleton) ──────────────────────────────────

final streakEngineProvider = Provider((_) => const StreakEngine());

// ── Today's date (with day boundary applied) ──────────────────────────────

final todayProvider = Provider<LocalDate>((ref) => LocalDate.today());

// ── Active habits for today ───────────────────────────────────────────────

final habitsForTodayProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  final today = ref.watch(todayProvider);
  return repo.watchActiveForDate(today);
});

// ── All habits (for management screens) ──────────────────────────────────

final allHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.watchAll();
});

// ── Today's logs for all habits ───────────────────────────────────────────

final todayLogsProvider = FutureProvider<Map<String, HabitLog?>>((ref) async {
  final repo = ref.watch(habitRepositoryProvider);
  final today = ref.watch(todayProvider);
  final habits = await ref.watch(habitsForTodayProvider.future);
  final result = <String, HabitLog?>{};
  for (final h in habits) {
    result[h.id] = await repo.getLog(h.id, today);
  }
  return result;
});

// ── Day lock for today ────────────────────────────────────────────────────

final todayDayLockProvider = StreamProvider<DayLock?>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  final today = ref.watch(todayProvider);
  return repo.watchDayLock(today);
});

// ── Streak for a single habit ─────────────────────────────────────────────

final habitStreakProvider =
    FutureProvider.family<int, String>((ref, habitId) async {
  final repo = ref.watch(habitRepositoryProvider);
  final engine = ref.watch(streakEngineProvider);
  final today = ref.watch(todayProvider);
  final habit = await repo.getById(habitId);
  if (habit == null) return 0;
  final range = DateRange(start: today.subtractDays(365), end: today);
  final logs = await repo.fetchLogsForHabits([habitId], range);
  return engine.currentStreak(habit, logs[habitId] ?? [], today);
});

// ── Lock-in state for today ───────────────────────────────────────────────

final lockedInTodayProvider = Provider<AsyncValue<bool>>((ref) {
  final habitsAsync = ref.watch(habitsForTodayProvider);
  final logsAsync = ref.watch(todayLogsProvider);
  final today = ref.watch(todayProvider);
  final engine = ref.watch(streakEngineProvider);

  return habitsAsync.when(
    data: (habits) => logsAsync.when(
      data: (logMap) {
        final logs = logMap.values.whereType<HabitLog>().toList();
        return AsyncValue.data(engine.isLockedIn(habits, logs, today));
      },
      loading: () => const AsyncValue.loading(),
      error: AsyncValue.error,
    ),
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
  );
});

// ── Habit use-cases ───────────────────────────────────────────────────────

final habitUseCasesProvider = Provider(HabitUseCases.new);

class HabitUseCases {
  HabitUseCases(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();

  Future<void> checkHabit(String habitId) async {
    final repo = _ref.read(habitRepositoryProvider);
    final today = _ref.read(todayProvider);
    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      localDate: today,
      status: HabitLogStatus.done,
      hlc: Hlc.now().toIso(),
    );
    await repo.saveLog(log);
    await _checkLockIn();
  }

  Future<void> uncheckHabit(String habitId) async {
    final repo = _ref.read(habitRepositoryProvider);
    final today = _ref.read(todayProvider);
    await repo.deleteLog(habitId, today);
    await repo.deleteDayLock(today);
  }

  Future<void> skipHabit(String habitId) async {
    final repo = _ref.read(habitRepositoryProvider);
    final today = _ref.read(todayProvider);
    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      localDate: today,
      status: HabitLogStatus.skipped,
      hlc: Hlc.now().toIso(),
    );
    await repo.saveLog(log);
  }

  Future<void> useRestToken(String habitId) async {
    final repo = _ref.read(habitRepositoryProvider);
    final today = _ref.read(todayProvider);
    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      localDate: today,
      status: HabitLogStatus.rest,
      hlc: Hlc.now().toIso(),
    );
    await repo.saveLog(log);
    await _checkLockIn();
  }

  Future<void> saveHabit(Habit habit) async {
    final repo = _ref.read(habitRepositoryProvider);
    await repo.save(habit);
  }

  Future<void> deleteHabit(String habitId) async {
    final repo = _ref.read(habitRepositoryProvider);
    await repo.softDelete(habitId);
  }

  Future<void> archiveHabit(String habitId) async {
    final repo = _ref.read(habitRepositoryProvider);
    await repo.archive(habitId);
  }

  Future<void> _checkLockIn() async {
    final repo = _ref.read(habitRepositoryProvider);
    final engine = _ref.read(streakEngineProvider);
    final today = _ref.read(todayProvider);
    final habits = await repo.watchActiveForDate(today).first;
    final logMap = await repo.fetchLogsForHabits(
      habits.map((h) => h.id).toList(),
      DateRange(start: today, end: today),
    );
    final logs = logMap.values.expand((l) => l).toList();
    final lockedIn = engine.isLockedIn(habits, logs, today);
    final existingLock = await repo.watchDayLock(today).first;
    if (lockedIn && existingLock == null) {
      await repo.saveDayLock(DayLock(localDate: today, lockedAt: DateTime.now()));
    }
  }
}
