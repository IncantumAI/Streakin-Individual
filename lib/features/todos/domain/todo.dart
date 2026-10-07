// lib/features/todos/domain/todo.dart
// Spec §4.3: Todo entity and related value types.

import 'package:flutter/foundation.dart';
import 'package:streakin/core/time/local_date.dart';

// ── Priority ──────────────────────────────────────────────────────────────

enum TodoPriority {
  none,
  medium,
  high;

  static TodoPriority fromInt(int v) => switch (v) {
        1 => medium,
        2 => high,
        _ => none,
      };

  int toInt() => switch (this) {
        none => 0,
        medium => 1,
        high => 2,
      };
}

// ── Status ────────────────────────────────────────────────────────────────

enum TodoStatus {
  pending,
  done;

  static TodoStatus fromString(String s) =>
      s == 'done' ? done : pending;

  String toLabel() => name;
}

// ── Todo entity ───────────────────────────────────────────────────────────

@immutable
class Todo {
  const Todo({
    required this.id,
    required this.title,
    this.dueDate,
    this.dueTime,
    required this.priority,
    required this.status,
    this.completedAt,
    required this.countsForLockin,
    this.sourceNoteId,
    this.sourceBlockId,
    this.reminderAt,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String title;

  /// ISO date string "yyyy-MM-dd", null = no due date.
  final String? dueDate;

  /// "HH:mm" local time, null = no specific time (all-day or unspecified).
  final String? dueTime;

  final TodoPriority priority;
  final TodoStatus status;

  /// UTC ISO-8601 instant when task was completed.
  final String? completedAt;

  /// Whether this task counts toward lock-in (only relevant when global
  /// setting `countTodosForLockIn` is on).
  final bool countsForLockin;

  /// Set when task was promoted from a note checkbox.
  final String? sourceNoteId;
  final String? sourceBlockId;

  /// UTC ISO-8601 instant when reminder fires.
  final String? reminderAt;

  final String hlc;
  final String? deletedAt;

  // ── Computed ─────────────────────────────────────────────────────────────

  bool get isDeleted => deletedAt != null;
  bool get isDone => status == TodoStatus.done && !isDeleted;
  bool get isPending => status == TodoStatus.pending && !isDeleted;
  bool get hasDueDate => dueDate != null;
  bool get hasSourceNote => sourceNoteId != null && sourceBlockId != null;

  /// True when this task is due on [date] (regardless of time).
  bool isDueOn(LocalDate date) =>
      dueDate != null && dueDate == date.toIso();

  /// True when this task is overdue relative to [today].
  bool isOverdue(LocalDate today) {
    if (dueDate == null || isDone) return false;
    return LocalDate.parse(dueDate!) < today;
  }

  Todo copyWith({
    String? title,
    String? Function()? dueDate,
    String? Function()? dueTime,
    TodoPriority? priority,
    TodoStatus? status,
    String? Function()? completedAt,
    bool? countsForLockin,
    String? Function()? sourceNoteId,
    String? Function()? sourceBlockId,
    String? Function()? reminderAt,
    String? hlc,
    String? Function()? deletedAt,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      dueDate: dueDate != null ? dueDate() : this.dueDate,
      dueTime: dueTime != null ? dueTime() : this.dueTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      completedAt:
          completedAt != null ? completedAt() : this.completedAt,
      countsForLockin: countsForLockin ?? this.countsForLockin,
      sourceNoteId:
          sourceNoteId != null ? sourceNoteId() : this.sourceNoteId,
      sourceBlockId:
          sourceBlockId != null ? sourceBlockId() : this.sourceBlockId,
      reminderAt:
          reminderAt != null ? reminderAt() : this.reminderAt,
      hlc: hlc ?? this.hlc,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Todo && id == other.id && hlc == other.hlc;

  @override
  int get hashCode => Object.hash(id, hlc);

  @override
  String toString() => 'Todo($id, $title, $status, due=$dueDate)';
}
