import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/application/goal_lifecycle_service.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';

// ── Repository state provider ─────────────────────────────────────────────────

class _GoalRepoNotifier extends Notifier<GoalRepository?> {
  @override
  GoalRepository? build() => null;
  void set(GoalRepository r) => state = r;
  void clear() => state = null;
}

final goalRepositoryStateProvider =
    NotifierProvider<_GoalRepoNotifier, GoalRepository?>(_GoalRepoNotifier.new);

// ── HabitCompletionPort state provider ───────────────────────────────────────

class _HabitPortNotifier extends Notifier<HabitCompletionPort?> {
  @override
  HabitCompletionPort? build() => null;
  void set(HabitCompletionPort p) => state = p;
  void clear() => state = null;
}

final habitCompletionPortStateProvider =
    NotifierProvider<_HabitPortNotifier, HabitCompletionPort?>(
        _HabitPortNotifier.new);

// ── Lifecycle service provider ────────────────────────────────────────────────

class _LifecycleNotifier extends Notifier<GoalLifecycleService?> {
  @override
  GoalLifecycleService? build() => null;
  void set(GoalLifecycleService s) => state = s;
  void clear() => state = null;
}

final goalLifecycleServiceProvider =
    NotifierProvider<_LifecycleNotifier, GoalLifecycleService?>(
        _LifecycleNotifier.new);

// ── Active goal stream ────────────────────────────────────────────────────────

final activeGoalProvider = StreamProvider<Goal?>((ref) {
  final repo = ref.watch(goalRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo
      .watchActive()
      .handleError((_) => null, test: (_) => true);
});

// ── Day ticker ────────────────────────────────────────────────────────────────

final dayTickerProvider = StreamProvider<LocalDate>((ref) {
  final controller = StreamController<LocalDate>();
  controller.add(LocalDate.today());

  Timer? timer;

  void arm() {
    timer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final until = tomorrow.difference(now);
    timer = Timer(until, () {
      controller.add(LocalDate.today());
      arm();
    });
  }

  arm();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

// ── GoalClock ─────────────────────────────────────────────────────────────────

final goalClockProvider = Provider<GoalClockState?>((ref) {
  final goalAsync = ref.watch(activeGoalProvider);
  final todayAsync = ref.watch(dayTickerProvider);
  final goal = goalAsync.value;
  final today = todayAsync.value ?? LocalDate.today();
  if (goal == null) return null;
  return GoalClock.compute(goal, today);
});

// ── Goal links ────────────────────────────────────────────────────────────────

final activeGoalLinksProvider =
    FutureProvider<List<GoalHabitLink>>((ref) async {
  final repo = ref.watch(goalRepositoryStateProvider);
  final goal = ref.watch(activeGoalProvider).value;
  if (repo == null || goal == null) return [];
  return repo.getLinksForGoal(goal.id);
});

// ── Alignment ─────────────────────────────────────────────────────────────────

final goalAlignmentProvider = FutureProvider<AlignmentStats?>((ref) async {
  final port = ref.watch(habitCompletionPortStateProvider);
  final goal = ref.watch(activeGoalProvider).value;
  final today = ref.watch(dayTickerProvider).value ?? LocalDate.today();
  if (port == null || goal == null) return null;

  final repo = ref.watch(goalRepositoryStateProvider);
  if (repo == null) return null;
  final links = await repo.getLinksForGoal(goal.id);
  if (links.isEmpty) return null;

  final yesterday = today.subtractDays(1);
  if (yesterday < goal.startDate) return null;

  final windows = links
      .map((l) => HabitLinkWindow(
            habitId: l.habitId,
            from: l.linkedFrom,
            to: l.linkedTo,
          ))
      .toList();

  return port.closedDayStats(
    windows: windows,
    through: yesterday,
    goalRestTokenPool: goal.restTokenPool,
  );
});

// ── Today live stats ──────────────────────────────────────────────────────────

final goalTodayLiveProvider =
    FutureProvider<({int done, int scheduled})>((ref) async {
  final port = ref.watch(habitCompletionPortStateProvider);
  final links = await ref.watch(activeGoalLinksProvider.future);
  final today = ref.watch(dayTickerProvider).value ?? LocalDate.today();
  if (port == null || links.isEmpty) return (done: 0, scheduled: 0);
  final habitIds = links
      .where((l) => l.isOpen)
      .map((l) => l.habitId)
      .toList();
  return port.todayLiveStats(habitIds: habitIds, today: today);
});

// ── Goal history ──────────────────────────────────────────────────────────────

final goalHistoryProvider = FutureProvider<List<Goal>>((ref) async {
  final repo = ref.watch(goalRepositoryStateProvider);
  if (repo == null) return [];
  return repo.getArchived();
});

// ── Hero prompt dismissed ─────────────────────────────────────────────────────

final heroPromptDismissedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(goalRepositoryStateProvider);
  if (repo == null) return false;
  final until = await repo.getHeroPromptDismissedUntil();
  if (until == null) return false;
  return LocalDate.today() <= until;
});
