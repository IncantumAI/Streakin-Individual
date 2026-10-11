import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Draft for creating/editing a goal.
class GoalDraft {
  const GoalDraft({
    required this.title,
    this.why,
    required this.kind,
    required this.startDate,
    this.endDate,
    required this.accentIndex,
  });

  final String title;
  final String? why;
  final GoalKind kind;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int accentIndex;
}

class GoalLifecycleService {
  GoalLifecycleService({
    required GoalRepository goalRepo,
    required HabitCompletionPort habitPort,
  })  : _goalRepo = goalRepo,
        _habitPort = habitPort;

  final GoalRepository _goalRepo;
  final HabitCompletionPort _habitPort;

  /// Set (or replace) the primary goal. Returns the archived old goal if any.
  Future<Goal?> setPrimaryGoal(
    GoalDraft draft, {
    List<String> habitIds = const [],
    bool countFromStart = true,
  }) async {
    final today = LocalDate.today();
    final now = DateTime.now();
    final hlc = Hlc.now().toIso();

    // Compute rest token pool: 1 per week of duration, min 4
    final durationWeeks = draft.kind == GoalKind.dated && draft.endDate != null
        ? (_daysBetween(draft.startDate, draft.endDate!) / 7).ceil()
        : 52;
    final restPool = (durationWeeks * 1).clamp(4, 365);

    Goal? archived;

    // Archive the current active goal if any
    final existing = await _goalRepo.getActive();
    if (existing != null) {
      archived = await _archiveGoal(
        existing,
        reason: GoalArchiveReason.replaced,
        through: today,
      );
    }

    // Create new goal
    final goal = Goal(
      id: _uuid.v4(),
      title: draft.title,
      why: draft.why,
      kind: draft.kind,
      startDate: draft.startDate,
      endDate: draft.endDate,
      status: GoalStatus.active,
      activatedHlc: hlc,
      accentIndex: draft.accentIndex,
      restTokenPool: restPool,
      createdAt: now,
      updatedAt: now,
      hlc: hlc,
    );
    await _goalRepo.saveGoal(goal);

    // Create local state row
    await _goalRepo.saveLocalState(GoalLocalState(
      goalId: goal.id,
      celebrationPending: false,
      milestonesShown: [],
    ));

    // Link habits
    final linkFrom = countFromStart ? draft.startDate : today;
    for (final habitId in habitIds) {
      await _goalRepo.saveGoalHabitLink(GoalHabitLink(
        id: _uuid.v4(),
        goalId: goal.id,
        habitId: habitId,
        linkedFrom: linkFrom,
        hlc: Hlc.now().toIso(),
      ));
    }

    return archived;
  }

  Future<void> editGoal(Goal goal, GoalDraft draft) async {
    final updated = goal.copyWith(
      title: draft.title,
      why: () => draft.why,
      kind: draft.kind,
      startDate: draft.startDate,
      endDate: () => draft.endDate,
      accentIndex: draft.accentIndex,
      updatedAt: DateTime.now(),
      hlc: Hlc.now().toIso(),
    );
    await _goalRepo.saveGoal(updated);
  }

  Future<void> completeEarly(Goal goal) async {
    await _archiveGoal(goal,
        reason: GoalArchiveReason.completedEarly,
        through: LocalDate.today());
  }

  Future<void> abandon(Goal goal) async {
    await _archiveGoal(goal,
        reason: GoalArchiveReason.abandoned, through: LocalDate.today());
  }

  Future<void> linkHabit(
    Goal goal,
    String habitId, {
    bool countFromStart = true,
  }) async {
    final today = LocalDate.today();
    final from = countFromStart ? goal.startDate : today;
    await _goalRepo.saveGoalHabitLink(GoalHabitLink(
      id: _uuid.v4(),
      goalId: goal.id,
      habitId: habitId,
      linkedFrom: from,
      hlc: Hlc.now().toIso(),
    ));
  }

  Future<void> unlinkHabit(Goal goal, String habitId) async {
    final links = await _goalRepo.getLinksForGoal(goal.id);
    final open = links.where((l) => l.habitId == habitId && l.isOpen).toList();
    final today = LocalDate.today();
    for (final link in open) {
      final closed = GoalHabitLink(
        id: link.id,
        goalId: link.goalId,
        habitId: link.habitId,
        linkedFrom: link.linkedFrom,
        linkedTo: today,
        hlc: Hlc.now().toIso(),
        deletedAt: link.deletedAt,
      );
      await _goalRepo.saveGoalHabitLink(closed);
    }
  }

  /// Runs on launch / resume / day rollover. Auto-archives expired goals.
  Future<void> reconcile(LocalDate today) async {
    final active = await _goalRepo.getActive();
    if (active == null) return;

    // Auto-archive if dated goal has passed its end date
    if (active.kind == GoalKind.dated &&
        active.endDate != null &&
        today > active.endDate!) {
      await _archiveGoal(active,
          reason: GoalArchiveReason.completed, through: active.endDate!);
    }
  }

  Future<void> dismissCelebration(String goalId) async {
    final state = await _goalRepo.getLocalState(goalId);
    if (state == null) return;
    await _goalRepo.saveLocalState(GoalLocalState(
      goalId: goalId,
      celebrationPending: false,
      milestonesShown: state.milestonesShown,
      heroPromptDismissedUntil: state.heroPromptDismissedUntil,
    ));
  }

  Future<void> markMilestoneShown(String goalId, String milestone) async {
    final state = await _goalRepo.getLocalState(goalId) ??
        GoalLocalState(
            goalId: goalId,
            celebrationPending: false,
            milestonesShown: []);
    final updated = [...state.milestonesShown, milestone];
    await _goalRepo.saveLocalState(GoalLocalState(
      goalId: goalId,
      celebrationPending: state.celebrationPending,
      milestonesShown: updated,
      heroPromptDismissedUntil: state.heroPromptDismissedUntil,
    ));
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<Goal> _archiveGoal(
    Goal goal, {
    required GoalArchiveReason reason,
    required LocalDate through,
  }) async {
    final summary = await _computeSummary(goal, through: through);
    await _goalRepo.saveGoalSummary(summary);

    final archived = goal.copyWith(
      status: GoalStatus.archived,
      archiveReason: () => reason,
      archivedAt: () => DateTime.now(),
      updatedAt: DateTime.now(),
      hlc: Hlc.now().toIso(),
    );
    await _goalRepo.saveGoal(archived);

    // Set celebration pending for completed goals
    if (reason == GoalArchiveReason.completed ||
        reason == GoalArchiveReason.completedEarly) {
      final state = await _goalRepo.getLocalState(goal.id) ??
          GoalLocalState(
              goalId: goal.id,
              celebrationPending: false,
              milestonesShown: []);
      await _goalRepo.saveLocalState(GoalLocalState(
        goalId: goal.id,
        celebrationPending: true,
        milestonesShown: state.milestonesShown,
        heroPromptDismissedUntil: state.heroPromptDismissedUntil,
      ));
    }

    return archived;
  }

  Future<GoalSummary> _computeSummary(Goal goal,
      {required LocalDate through}) async {
    final clock = GoalClock.compute(goal, through);
    final links = await _goalRepo.getLinksForGoal(goal.id);
    final windows = links
        .map((l) => HabitLinkWindow(
              habitId: l.habitId,
              from: l.linkedFrom,
              to: l.linkedTo,
            ))
        .toList();

    final stats = await _habitPort.closedDayStats(
      windows: windows,
      through: through,
      goalRestTokenPool: goal.restTokenPool,
    );

    final perHabitPct = <String, int>{};
    for (final e in stats.perHabit.entries) {
      perHabitPct[e.key] = e.value.pct ?? 0;
    }

    final milestonesReached = _milestonesReached(goal, clock);

    return GoalSummary(
      goalId: goal.id,
      computedThrough: through,
      totalDays: clock.totalDays ?? clock.dayNumber,
      elapsedDays: clock.dayNumber,
      alignmentPct: stats.alignmentPct,
      perfectDays: stats.perfectDays,
      bestStreak: stats.bestStreak,
      perHabit: perHabitPct,
      milestones: milestonesReached,
      hlc: Hlc.now().toIso(),
    );
  }

  List<String> _milestonesReached(Goal goal, GoalClockState clock) {
    final result = <String>[];
    if (goal.kind == GoalKind.dated && clock.totalDays != null) {
      for (final pct in kDatedMilestonePcts) {
        final mDay = (clock.totalDays! * pct / 100).round();
        if (clock.dayNumber >= mDay) result.add('${pct}pct');
      }
    } else {
      for (final m in kOpenMilestoneDays) {
        if (clock.dayNumber >= m) result.add('day$m');
      }
    }
    return result;
  }

  static int _daysBetween(LocalDate from, LocalDate to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays.abs();
  }
}
