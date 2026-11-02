// lib/features/habits/domain/habit.dart
// Spec §4.2: Habit entity + ScheduleMask value type.

import 'package:flutter/foundation.dart';
import 'package:streakin/core/time/local_date.dart';

/// Weekday bitmask: bit 0 = Monday, bit 6 = Sunday (ISO order).
/// All 7 bits set (127) = every day.
@immutable
class ScheduleMask {
  const ScheduleMask(this.value) : assert(value >= 0 && value <= 127);
  final int value;

  static const ScheduleMask every = ScheduleMask(127);
  static const ScheduleMask weekdays = ScheduleMask(31); // Mon–Fri bits 0-4

  /// bit position for weekday (1=Mon … 7=Sun → indices 0–6).
  static int _bit(int isoWeekday) => isoWeekday - 1;

  bool isScheduled(LocalDate date) {
    final bit = _bit(date.weekday);
    return (value >> bit) & 1 == 1;
  }

  /// Create from list of ISO weekdays (1=Mon … 7=Sun).
  factory ScheduleMask.fromWeekdays(List<int> weekdays) {
    int mask = 0;
    for (final d in weekdays) {
      mask |= 1 << _bit(d);
    }
    return ScheduleMask(mask);
  }

  /// Number of scheduled days per week.
  int get scheduledDaysCount {
    int n = 0;
    for (int i = 0; i < 7; i++) {
      if ((value >> i) & 1 == 1) n++;
    }
    return n;
  }

  /// Maximum rest tokens allowed = floor(scheduledDaysCount / 2).
  /// Spec §2.4 answer 2.
  int get maxRestTokens => scheduledDaysCount ~/ 2;

  @override
  bool operator ==(Object other) =>
      other is ScheduleMask && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'ScheduleMask($value)';
}

@immutable
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.iconIndex,
    required this.accentIndex,
    required this.scheduleMask,
    this.reminderTime,
    required this.startDate,
    this.archivedAt,
    required this.sortOrder,
    required this.restTokensPerWeek,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String name;
  final int iconIndex; // index into AppIcons.habitIcons
  final int accentIndex; // index into AppColors.habitAccents (0–7)
  final ScheduleMask scheduleMask;
  final String? reminderTime; // "HH:mm" or null
  final LocalDate startDate;
  final LocalDate? archivedAt;
  final int sortOrder;
  final int restTokensPerWeek;
  final String hlc;
  final LocalDate? deletedAt;

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;

  Habit copyWith({
    String? name,
    int? iconIndex,
    int? accentIndex,
    ScheduleMask? scheduleMask,
    String? reminderTime,
    LocalDate? startDate,
    LocalDate? archivedAt,
    int? sortOrder,
    int? restTokensPerWeek,
    String? hlc,
    LocalDate? deletedAt,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      iconIndex: iconIndex ?? this.iconIndex,
      accentIndex: accentIndex ?? this.accentIndex,
      scheduleMask: scheduleMask ?? this.scheduleMask,
      reminderTime: reminderTime ?? this.reminderTime,
      startDate: startDate ?? this.startDate,
      archivedAt: archivedAt ?? this.archivedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      restTokensPerWeek: restTokensPerWeek ?? this.restTokensPerWeek,
      hlc: hlc ?? this.hlc,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Habit && id == other.id && hlc == other.hlc;
  @override
  int get hashCode => Object.hash(id, hlc);
}

// ── HabitLog ──────────────────────────────────────────────────────────────────

enum HabitLogStatus { done, skipped, rest }

@immutable
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.localDate,
    required this.status,
    this.note,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String habitId;
  final LocalDate localDate;
  final HabitLogStatus status;
  final String? note;
  final String hlc;
  final LocalDate? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isDone => status == HabitLogStatus.done && !isDeleted;
  bool get isRest => status == HabitLogStatus.rest && !isDeleted;

  @override
  bool operator ==(Object other) => other is HabitLog && id == other.id;
  @override
  int get hashCode => id.hashCode;
}

// ── DayLock ───────────────────────────────────────────────────────────────────

@immutable
class DayLock {
  const DayLock({required this.localDate, required this.lockedAt});
  final LocalDate localDate;
  final DateTime lockedAt;
}
