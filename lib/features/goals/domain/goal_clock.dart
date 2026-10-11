import 'package:flutter/foundation.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal.dart';

// ── GoalClockState ────────────────────────────────────────────────────────────

@immutable
class GoalClockState {
  const GoalClockState({
    required this.goal,
    required this.today,
    required this.phase,
    required this.dayNumber,
    required this.totalDays,
    this.daysLeft,
    this.daysUntilStart,
    this.progress,
    this.nextMilestone,
    this.daysToNextMilestone,
    this.progressToNextMilestone,
  });

  final Goal goal;
  final LocalDate today;
  final GoalPhase phase;

  // Dated + open
  final int dayNumber; // 0 when upcoming
  final int? totalDays; // null for open-ended

  // Dated only
  final int? daysLeft;
  final int? daysUntilStart; // upcoming only

  // Progress ring value 0.0–1.0
  final double? progress;

  // Open-ended only
  final int? nextMilestone;
  final int? daysToNextMilestone;
  final double? progressToNextMilestone;

  String get displayDay => phase == GoalPhase.upcoming ? '0' : '$dayNumber';

  String get caption {
    switch (phase) {
      case GoalPhase.upcoming:
        return 'Starts in ${daysUntilStart ?? 0} day${(daysUntilStart ?? 0) == 1 ? '' : 's'}';
      case GoalPhase.finalDay:
        return 'Last day';
      case GoalPhase.ended:
        return 'Goal complete';
      case GoalPhase.active:
        if (goal.kind == GoalKind.dated) {
          return 'Day $dayNumber of $totalDays';
        } else {
          return nextMilestone != null
              ? '$daysToNextMilestone days to $nextMilestone'
              : 'Day $dayNumber';
        }
    }
  }

  bool get isFinalStretch =>
      goal.kind == GoalKind.dated &&
      daysLeft != null &&
      daysLeft! <= 7 &&
      phase == GoalPhase.active;
}

// ── GoalClock (pure function) ─────────────────────────────────────────────────

class GoalClock {
  GoalClock._();

  static GoalClockState compute(Goal goal, LocalDate today) {
    final start = goal.startDate;

    if (goal.kind == GoalKind.open) {
      return _computeOpen(goal, today, start);
    } else {
      return _computeDated(goal, today, start, goal.endDate!);
    }
  }

  static GoalClockState _computeDated(
      Goal goal, LocalDate today, LocalDate start, LocalDate end) {
    final total = _daysBetween(start, end) + 1; // inclusive

    if (today < start) {
      final daysUntil = _daysBetween(today, start);
      return GoalClockState(
        goal: goal,
        today: today,
        phase: GoalPhase.upcoming,
        dayNumber: 0,
        totalDays: total,
        daysLeft: total,
        daysUntilStart: daysUntil,
        progress: 0.0,
      );
    }

    if (today > end) {
      return GoalClockState(
        goal: goal,
        today: today,
        phase: GoalPhase.ended,
        dayNumber: total,
        totalDays: total,
        daysLeft: 0,
        progress: 1.0,
      );
    }

    final dayNumber = _daysBetween(start, today) + 1;
    final daysLeft = total - dayNumber;
    final progress = dayNumber / total;
    final phase = today == end ? GoalPhase.finalDay : GoalPhase.active;

    return GoalClockState(
      goal: goal,
      today: today,
      phase: phase,
      dayNumber: dayNumber,
      totalDays: total,
      daysLeft: daysLeft,
      progress: progress.clamp(0.0, 1.0),
    );
  }

  static GoalClockState _computeOpen(
      Goal goal, LocalDate today, LocalDate start) {
    if (today < start) {
      final daysUntil = _daysBetween(today, start);
      return GoalClockState(
        goal: goal,
        today: today,
        phase: GoalPhase.upcoming,
        dayNumber: 0,
        totalDays: null,
        daysUntilStart: daysUntil,
        progress: 0.0,
        nextMilestone: nextOpenMilestone(0),
        daysToNextMilestone: nextOpenMilestone(0),
        progressToNextMilestone: 0.0,
      );
    }

    final dayNumber = _daysBetween(start, today) + 1;
    final next = nextOpenMilestone(dayNumber);
    final prev = prevOpenMilestone(dayNumber);
    final span = next - prev;
    final progressToNext = span == 0 ? 0.0 : (dayNumber - prev) / span;

    return GoalClockState(
      goal: goal,
      today: today,
      phase: GoalPhase.active,
      dayNumber: dayNumber,
      totalDays: null,
      daysLeft: null,
      progress: progressToNext.clamp(0.0, 1.0),
      nextMilestone: next,
      daysToNextMilestone: next - dayNumber,
      progressToNextMilestone: progressToNext.clamp(0.0, 1.0),
    );
  }

  static int _daysBetween(LocalDate from, LocalDate to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
