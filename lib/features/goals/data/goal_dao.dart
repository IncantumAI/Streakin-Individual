import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal.dart' as domain;

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals, GoalHabits, GoalSummaries, GoalLocalState])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  // ── Goals ─────────────────────────────────────────────────────────────────

  Stream<domain.Goal?> watchActive() {
    return (select(goals)
          ..where((t) => t.status.equals('active') & t.deletedAt.isNull()))
        .watchSingleOrNull()
        .map((r) => r == null ? null : _goalFromRow(r));
  }

  Future<domain.Goal?> getActive() async {
    final row =
        await (select(goals)
              ..where((t) => t.status.equals('active') & t.deletedAt.isNull()))
            .getSingleOrNull();
    return row == null ? null : _goalFromRow(row);
  }

  Future<domain.Goal?> getById(String id) async {
    final row = await (select(
      goals,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _goalFromRow(row);
  }

  Future<List<domain.Goal>> getArchived({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows =
        await (select(goals)
              ..where((t) => t.status.equals('archived') & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.archivedAt)])
              ..limit(limit, offset: offset))
            .get();
    return rows.map(_goalFromRow).toList();
  }

  Future<void> saveGoal(domain.Goal goal) async {
    await into(goals).insertOnConflictUpdate(
      GoalsCompanion(
        id: Value(goal.id),
        title: Value(goal.title),
        why: Value(goal.why),
        kind: Value(goal.kind.name),
        startDate: Value(goal.startDate.toIso()),
        endDate: Value(goal.endDate?.toIso()),
        status: Value(goal.status.name),
        archiveReason: Value(
          goal.archiveReason != null
              ? _reasonToString(goal.archiveReason!)
              : null,
        ),
        archivedAt: Value(goal.archivedAt?.toIso8601String()),
        activatedHlc: Value(goal.activatedHlc),
        accentIndex: Value(goal.accentIndex),
        restTokenPool: Value(goal.restTokenPool),
        createdAt: Value(goal.createdAt.toIso8601String()),
        updatedAt: Value(goal.updatedAt.toIso8601String()),
        hlc: Value(goal.hlc),
        deletedAt: Value(goal.deletedAt?.toIso8601String()),
      ),
    );
  }

  // ── Goal habit links ──────────────────────────────────────────────────────

  Future<void> saveGoalHabitLink(domain.GoalHabitLink link) async {
    await into(goalHabits).insertOnConflictUpdate(
      GoalHabitsCompanion(
        id: Value(link.id),
        goalId: Value(link.goalId),
        habitId: Value(link.habitId),
        linkedFrom: Value(link.linkedFrom.toIso()),
        linkedTo: Value(link.linkedTo?.toIso()),
        hlc: Value(link.hlc),
        deletedAt: Value(link.deletedAt?.toIso8601String()),
      ),
    );
  }

  Future<List<domain.GoalHabitLink>> getLinksForGoal(String goalId) async {
    final rows = await (select(
      goalHabits,
    )..where((t) => t.goalId.equals(goalId) & t.deletedAt.isNull())).get();
    return rows.map(_linkFromRow).toList();
  }

  // ── Goal summaries ────────────────────────────────────────────────────────

  Future<void> saveGoalSummary(domain.GoalSummary summary) async {
    await into(goalSummaries).insertOnConflictUpdate(
      GoalSummariesCompanion(
        goalId: Value(summary.goalId),
        computedThrough: Value(summary.computedThrough.toIso()),
        totalDays: Value(summary.totalDays),
        elapsedDays: Value(summary.elapsedDays),
        alignmentPct: Value(summary.alignmentPct),
        perfectDays: Value(summary.perfectDays),
        bestStreak: Value(summary.bestStreak),
        perHabit: Value(jsonEncode(summary.perHabit)),
        milestones: Value(jsonEncode(summary.milestones)),
        hlc: Value(summary.hlc),
      ),
    );
  }

  Future<domain.GoalSummary?> getSummary(String goalId) async {
    final row = await (select(
      goalSummaries,
    )..where((t) => t.goalId.equals(goalId))).getSingleOrNull();
    return row == null ? null : _summaryFromRow(row);
  }

  // ── Goal local state ──────────────────────────────────────────────────────

  Future<domain.GoalLocalState?> getLocalState(String goalId) async {
    final row = await (select(
      goalLocalState,
    )..where((t) => t.goalId.equals(goalId))).getSingleOrNull();
    return row == null ? null : _localStateFromRow(row);
  }

  Future<void> saveLocalState(domain.GoalLocalState state) async {
    await into(goalLocalState).insertOnConflictUpdate(
      GoalLocalStateCompanion(
        goalId: Value(state.goalId),
        celebrationPending: Value(state.celebrationPending),
        milestonesShown: Value(jsonEncode(state.milestonesShown)),
        heroPromptDismissedUntil: Value(
          state.heroPromptDismissedUntil?.toIso(),
        ),
      ),
    );
  }

  Future<LocalDate?> getHeroPromptDismissedUntil() async {
    final row = await (select(
      goalLocalState,
    )..where((t) => t.goalId.equals('__hero_prompt__'))).getSingleOrNull();
    if (row?.heroPromptDismissedUntil == null) return null;
    return LocalDate.parse(row!.heroPromptDismissedUntil!);
  }

  Future<void> setHeroPromptDismissed(LocalDate until) async {
    await into(goalLocalState).insertOnConflictUpdate(
      GoalLocalStateCompanion(
        goalId: const Value('__hero_prompt__'),
        celebrationPending: const Value(false),
        milestonesShown: const Value('[]'),
        heroPromptDismissedUntil: Value(until.toIso()),
      ),
    );
  }

  // ── Mappers ───────────────────────────────────────────────────────────────

  static domain.Goal _goalFromRow(Goal row) => domain.Goal(
    id: row.id,
    title: row.title,
    why: row.why,
    kind: row.kind == 'open' ? domain.GoalKind.open : domain.GoalKind.dated,
    startDate: LocalDate.parse(row.startDate),
    endDate: row.endDate != null ? LocalDate.parse(row.endDate!) : null,
    status: row.status == 'archived'
        ? domain.GoalStatus.archived
        : domain.GoalStatus.active,
    archiveReason: row.archiveReason != null
        ? _parseReason(row.archiveReason!)
        : null,
    archivedAt: row.archivedAt != null ? DateTime.parse(row.archivedAt!) : null,
    activatedHlc: row.activatedHlc,
    accentIndex: row.accentIndex,
    restTokenPool: row.restTokenPool,
    createdAt: DateTime.parse(row.createdAt),
    updatedAt: DateTime.parse(row.updatedAt),
    hlc: row.hlc,
    deletedAt: row.deletedAt != null ? DateTime.parse(row.deletedAt!) : null,
  );

  static domain.GoalHabitLink _linkFromRow(GoalHabit row) =>
      domain.GoalHabitLink(
        id: row.id,
        goalId: row.goalId,
        habitId: row.habitId,
        linkedFrom: LocalDate.parse(row.linkedFrom),
        linkedTo: row.linkedTo != null ? LocalDate.parse(row.linkedTo!) : null,
        hlc: row.hlc,
        deletedAt: row.deletedAt != null
            ? DateTime.parse(row.deletedAt!)
            : null,
      );

  static domain.GoalSummary _summaryFromRow(GoalSummary row) =>
      domain.GoalSummary(
        goalId: row.goalId,
        computedThrough: LocalDate.parse(row.computedThrough),
        totalDays: row.totalDays,
        elapsedDays: row.elapsedDays,
        alignmentPct: row.alignmentPct,
        perfectDays: row.perfectDays,
        bestStreak: row.bestStreak,
        perHabit: Map<String, int>.from(jsonDecode(row.perHabit) as Map),
        milestones: List<String>.from(jsonDecode(row.milestones) as List),
        hlc: row.hlc,
      );

  static domain.GoalLocalState _localStateFromRow(GoalLocalStateData row) =>
      domain.GoalLocalState(
        goalId: row.goalId,
        celebrationPending: row.celebrationPending,
        milestonesShown: List<String>.from(
          jsonDecode(row.milestonesShown) as List,
        ),
        heroPromptDismissedUntil: row.heroPromptDismissedUntil != null
            ? LocalDate.parse(row.heroPromptDismissedUntil!)
            : null,
      );

  static domain.GoalArchiveReason _parseReason(String s) => switch (s) {
    'completedEarly' => domain.GoalArchiveReason.completedEarly,
    'replaced' => domain.GoalArchiveReason.replaced,
    'abandoned' => domain.GoalArchiveReason.abandoned,
    _ => domain.GoalArchiveReason.completed,
  };

  static String _reasonToString(domain.GoalArchiveReason r) => switch (r) {
    domain.GoalArchiveReason.completedEarly => 'completedEarly',
    domain.GoalArchiveReason.replaced => 'replaced',
    domain.GoalArchiveReason.abandoned => 'abandoned',
    domain.GoalArchiveReason.completed => 'completed',
  };
}
