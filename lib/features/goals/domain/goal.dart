import 'package:flutter/foundation.dart';
import 'package:streakin/core/time/local_date.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

enum GoalKind { dated, open }

enum GoalStatus { active, archived }

enum GoalArchiveReason { completed, completedEarly, replaced, abandoned }

enum GoalPhase { upcoming, active, finalDay, ended }

// ── Milestone definitions ─────────────────────────────────────────────────────

const kDatedMilestonePcts = [25, 50, 75]; // % milestones for dated goals
const kOpenMilestoneDays = [
  7,
  30,
  50,
  100,
  200,
  365,
]; // day milestones for open-ended

List<int> openMilestonesUpTo(int day) {
  final fixed = kOpenMilestoneDays.where((m) => m <= day).toList();
  int next = 365;
  while (next <= day) {
    next += 100;
    fixed.add(next - 100);
  }
  return fixed;
}

int nextOpenMilestone(int currentDay) {
  for (final m in kOpenMilestoneDays) {
    if (m > currentDay) return m;
  }
  // Beyond 365: every 100
  int m = 365;
  while (m <= currentDay) {
    m += 100;
  }
  return m;
}

int prevOpenMilestone(int currentDay) {
  final all = [...kOpenMilestoneDays];
  int base = 365;
  while (base < currentDay) {
    all.add(base);
    base += 100;
  }
  int prev = 0;
  for (final m in all) {
    if (m < currentDay) prev = m;
  }
  return prev;
}

// ── Goal entity ───────────────────────────────────────────────────────────────

@immutable
class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.why,
    required this.kind,
    required this.startDate,
    this.endDate,
    required this.status,
    this.archiveReason,
    this.archivedAt,
    required this.activatedHlc,
    required this.accentIndex,
    required this.restTokenPool,
    required this.createdAt,
    required this.updatedAt,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String? why;
  final GoalKind kind;
  final LocalDate startDate;
  final LocalDate? endDate;
  final GoalStatus status;
  final GoalArchiveReason? archiveReason;
  final DateTime? archivedAt;
  final String activatedHlc;
  final int accentIndex;
  final int restTokenPool;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String hlc;
  final DateTime? deletedAt;

  bool get isActive => status == GoalStatus.active && deletedAt == null;
  bool get isArchived => status == GoalStatus.archived;

  Goal copyWith({
    String? title,
    String? Function()? why,
    GoalKind? kind,
    LocalDate? startDate,
    LocalDate? Function()? endDate,
    GoalStatus? status,
    GoalArchiveReason? Function()? archiveReason,
    DateTime? Function()? archivedAt,
    int? accentIndex,
    int? restTokenPool,
    DateTime? updatedAt,
    String? hlc,
    DateTime? Function()? deletedAt,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      why: why != null ? why() : this.why,
      kind: kind ?? this.kind,
      startDate: startDate ?? this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      status: status ?? this.status,
      archiveReason: archiveReason != null
          ? archiveReason()
          : this.archiveReason,
      archivedAt: archivedAt != null ? archivedAt() : this.archivedAt,
      activatedHlc: activatedHlc,
      accentIndex: accentIndex ?? this.accentIndex,
      restTokenPool: restTokenPool ?? this.restTokenPool,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: hlc ?? this.hlc,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Goal && id == other.id && hlc == other.hlc;
  @override
  int get hashCode => Object.hash(id, hlc);
}

// ── GoalHabitLink entity ──────────────────────────────────────────────────────

@immutable
class GoalHabitLink {
  const GoalHabitLink({
    required this.id,
    required this.goalId,
    required this.habitId,
    required this.linkedFrom,
    this.linkedTo,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String goalId;
  final String habitId;
  final LocalDate linkedFrom;
  final LocalDate? linkedTo;
  final String hlc;
  final DateTime? deletedAt;

  bool get isOpen => linkedTo == null && deletedAt == null;

  @override
  bool operator ==(Object other) =>
      other is GoalHabitLink && id == other.id && hlc == other.hlc;
  @override
  int get hashCode => Object.hash(id, hlc);
}

// ── GoalSummary entity ────────────────────────────────────────────────────────

@immutable
class GoalSummary {
  const GoalSummary({
    required this.goalId,
    required this.computedThrough,
    required this.totalDays,
    required this.elapsedDays,
    this.alignmentPct,
    required this.perfectDays,
    required this.bestStreak,
    required this.perHabit,
    required this.milestones,
    required this.hlc,
  });

  final String goalId;
  final LocalDate computedThrough;
  final int totalDays;
  final int elapsedDays;
  final int? alignmentPct;
  final int perfectDays;
  final int bestStreak;
  final Map<String, int> perHabit; // habitId → completion%
  final List<String> milestones; // milestone identifiers reached
  final String hlc;
}

// ── GoalLocalState entity ─────────────────────────────────────────────────────

@immutable
class GoalLocalState {
  const GoalLocalState({
    required this.goalId,
    required this.celebrationPending,
    required this.milestonesShown,
    this.heroPromptDismissedUntil,
  });

  final String goalId;
  final bool celebrationPending;
  final List<String> milestonesShown;
  final LocalDate? heroPromptDismissedUntil;
}
