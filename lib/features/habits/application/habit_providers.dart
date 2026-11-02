// lib/features/habits/application/habit_providers.dart

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/habits/domain/streak_engine.dart';

bool _isSqliteError(dynamic e) => e is SqliteException;

// ── Repository state ──────────────────────────────────────────────────────

class _HabitRepositoryNotifier extends Notifier<HabitRepository?> {
  @override
  HabitRepository? build() => null;
  void set(HabitRepository repo) => state = repo;
  void clear() => state = null;
}

final habitRepositoryStateProvider =
    NotifierProvider<_HabitRepositoryNotifier, HabitRepository?>(
      _HabitRepositoryNotifier.new,
    );

// Kept for use-cases that call it inside user actions (ref.read, never null
// at that point because the UI is only reachable when SessionScope is live).
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) throw StateError('HabitRepository not available');
  return repo;
});

// ── Extra lock-in gate (set by SessionScope; e.g. flagged to-dos) ─────────
//
// Keeps the habits feature free of any to-do imports: the session layer
// supplies a callback that returns true when nothing else blocks lock-in.

typedef LockInGate = Future<bool> Function(LocalDate today);

class _LockInGateNotifier extends Notifier<LockInGate?> {
  @override
  LockInGate? build() => null;
  void set(LockInGate gate) => state = gate;
  void clear() => state = null;
}

final lockInGateStateProvider =
    NotifierProvider<_LockInGateNotifier, LockInGate?>(_LockInGateNotifier.new);

// ── Streak engine ──────────────────────────────────────────────────────────

final streakEngineProvider = Provider((_) => const StreakEngine());

// ── Today ──────────────────────────────────────────────────────────────────

final todayProvider = Provider<LocalDate>((ref) => LocalDate.today());

// ── Stream providers — all null-safe, all with handleError ────────────────

final habitsForTodayProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  final today = ref.watch(todayProvider);
  return repo
      .watchActiveForDate(today)
      .handleError((_) => <Habit>[], test: _isSqliteError);
});

final allHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchAll().handleError((_) => <Habit>[], test: _isSqliteError);
});

final todayDayLockProvider = StreamProvider<DayLock?>((ref) {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  final today = ref.watch(todayProvider);
  return repo
      .watchDayLock(today)
      .handleError((_) => null, test: _isSqliteError);
});

// ── Logs & all habits providers ────────────────────────────────────────────

// All active habits regardless of schedule (shows unscheduled ones too)
final habitsForAllTodayProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo
      .watchAll()
      .map((all) => all.where((h) => h.isActive).toList())
      .handleError((_) => <Habit>[], test: _isSqliteError);
});

// Streams today's logs keyed by habit id, live on every check/uncheck.
final todayLogsProvider = StreamProvider<Map<String, HabitLog?>>((ref) {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  final today = ref.watch(todayProvider);
  return repo
      .watchLogsForDate(today)
      .map((logs) => <String, HabitLog?>{for (final l in logs) l.habitId: l})
      .handleError((_) => <String, HabitLog?>{}, test: _isSqliteError);
});

final habitStreakProvider = FutureProvider.family<int, String>((
  ref,
  habitId,
) async {
  final repo = ref.watch(habitRepositoryStateProvider);
  if (repo == null) return 0;
  final engine = ref.watch(streakEngineProvider);
  final today = ref.watch(todayProvider);
  final habit = await repo.getById(habitId);
  if (habit == null) return 0;
  final range = DateRange(start: today.subtractDays(365), end: today);
  final logs = await repo.fetchLogsForHabits([habitId], range);
  return engine.currentStreak(habit, logs[habitId] ?? [], today);
});

// ── Lock-in derived provider ──────────────────────────────────────────────

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

// ── Use-cases ──────────────────────────────────────────────────────────────

final habitUseCasesProvider = Provider(HabitUseCases.new);

class HabitUseCases {
  HabitUseCases(this._ref);
  final Ref _ref;
  static const _uuid = Uuid();

  HabitRepository? get _repo => _ref.read(habitRepositoryStateProvider);

  Future<void> checkHabit(String habitId) async {
    final repo = _repo;
    if (repo == null) return;
    final today = _ref.read(todayProvider);
    await repo.saveLog(
      HabitLog(
        id: _uuid.v4(),
        habitId: habitId,
        localDate: today,
        status: HabitLogStatus.done,
        hlc: Hlc.now().toIso(),
      ),
    );
    await _checkLockIn(repo);
  }

  Future<void> uncheckHabit(String habitId) async {
    final repo = _repo;
    if (repo == null) return;
    final today = _ref.read(todayProvider);
    await repo.deleteLog(habitId, today);
    await repo.deleteDayLock(today);
  }

  Future<void> skipHabit(String habitId) async {
    final repo = _repo;
    if (repo == null) return;
    final today = _ref.read(todayProvider);
    await repo.saveLog(
      HabitLog(
        id: _uuid.v4(),
        habitId: habitId,
        localDate: today,
        status: HabitLogStatus.skipped,
        hlc: Hlc.now().toIso(),
      ),
    );
  }

  Future<void> useRestToken(String habitId) async {
    final repo = _repo;
    if (repo == null) return;
    final today = _ref.read(todayProvider);
    await repo.saveLog(
      HabitLog(
        id: _uuid.v4(),
        habitId: habitId,
        localDate: today,
        status: HabitLogStatus.rest,
        hlc: Hlc.now().toIso(),
      ),
    );
    await _checkLockIn(repo);
  }

  Future<void> saveHabit(Habit habit) async {
    await _repo?.save(habit);
  }

  Future<void> deleteHabit(String habitId) async {
    await _repo?.softDelete(habitId);
  }

  Future<void> archiveHabit(String habitId) async {
    await _repo?.archive(habitId);
  }

  /// Re-runs the lock-in check (e.g. after a flagged to-do changes state).
  Future<void> reevaluateLockIn() async {
    final repo = _repo;
    if (repo == null) return;
    await _checkLockIn(repo);
  }

  Future<void> _checkLockIn(HabitRepository repo) async {
    final engine = _ref.read(streakEngineProvider);
    final today = _ref.read(todayProvider);
    final habits = await repo.watchActiveForDate(today).first;
    final logMap = await repo.fetchLogsForHabits(
      habits.map((h) => h.id).toList(),
      DateRange(start: today, end: today),
    );
    final logs = logMap.values.expand((l) => l).toList();
    if (engine.isLockedIn(habits, logs, today)) {
      final gate = _ref.read(lockInGateStateProvider);
      if (gate != null && !await gate(today)) return;
      final existing = await repo.watchDayLock(today).first;
      if (existing == null) {
        await repo.saveDayLock(
          DayLock(localDate: today, lockedAt: DateTime.now()),
        );
      }
    }
  }
}
