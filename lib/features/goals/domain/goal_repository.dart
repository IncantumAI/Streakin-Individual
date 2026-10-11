import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal.dart';

// ── HabitLinkWindow ───────────────────────────────────────────────────────────

class HabitLinkWindow {
  const HabitLinkWindow({
    required this.habitId,
    required this.from,
    this.to,
  });
  final String habitId;
  final LocalDate from;
  final LocalDate? to;
}

// ── HabitRef ──────────────────────────────────────────────────────────────────

class HabitRef {
  const HabitRef({required this.id, required this.name});
  final String id;
  final String name;
}

// ── AlignmentStats ────────────────────────────────────────────────────────────

class AlignmentStats {
  const AlignmentStats({
    required this.scheduled,
    required this.done,
    required this.perfectDays,
    required this.perHabit,
    required this.bestStreak,
  });

  final int scheduled;
  final int done;
  final int perfectDays;
  final Map<String, PerHabitStats> perHabit; // habitId → stats
  final int bestStreak;

  int? get alignmentPct =>
      scheduled == 0 ? null : (100 * done / scheduled).round();
}

class PerHabitStats {
  const PerHabitStats({required this.scheduled, required this.done});
  final int scheduled;
  final int done;
  int? get pct => scheduled == 0 ? null : (100 * done / scheduled).round();
}

// ── HabitCompletionPort ───────────────────────────────────────────────────────

abstract interface class HabitCompletionPort {
  Future<AlignmentStats> closedDayStats({
    required List<HabitLinkWindow> windows,
    required LocalDate through,
    required int goalRestTokenPool,
  });

  Stream<List<HabitRef>> watchHabits(Set<String> habitIds);

  /// Today's live done/scheduled count for linked habits.
  Future<({int done, int scheduled})> todayLiveStats({
    required List<String> habitIds,
    required LocalDate today,
  });
}

// ── GoalRepository ────────────────────────────────────────────────────────────

abstract interface class GoalRepository {
  Stream<Goal?> watchActive();
  Future<Goal?> getActive();
  Future<Goal?> getById(String id);
  Future<List<Goal>> getArchived({int limit, int offset});
  Future<void> saveGoal(Goal goal);
  Future<void> saveGoalHabitLink(GoalHabitLink link);
  Future<List<GoalHabitLink>> getLinksForGoal(String goalId);
  Future<void> saveGoalSummary(GoalSummary summary);
  Future<GoalSummary?> getSummary(String goalId);
  Future<GoalLocalState?> getLocalState(String goalId);
  Future<void> saveLocalState(GoalLocalState state);
  Future<void> setHeroPromptDismissed(LocalDate until);
  Future<LocalDate?> getHeroPromptDismissedUntil();
}
