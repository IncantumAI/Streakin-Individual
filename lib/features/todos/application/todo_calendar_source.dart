// lib/features/todos/application/todo_calendar_source.dart
// Implements CalendarSource for tasks that have a due date.
// Calendar screen consumes this via the CalendarSource interface.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/calendar/domain/calendar_source.dart';
import 'package:streakin/features/todos/application/todo_providers.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';

class TodoCalendarSource implements CalendarSource {
  const TodoCalendarSource(this._repo);
  final TodoRepository _repo;

  @override
  Stream<List<CalendarEntry>> watch(DateRange range) async* {
    // Re-emit whenever the today stream updates (covers overdue + today tasks).
    // We also pull upcoming + done snapshots so the calendar shows all tasks
    // with due dates in the range regardless of status.
    await for (final today in _repo.watchToday()) {
      final upcoming = await _repo.watchUpcoming().first;
      final done = await _repo.watchDone().first;
      final all = [...today, ...upcoming, ...done];
      yield all
          .where((t) =>
              t.dueDate != null &&
              range.contains(LocalDate.parse(t.dueDate!)))
          .map(_toEntry)
          .toList();
    }
  }

  static CalendarEntry _toEntry(Todo t) {
    return CalendarEntry(
      date: LocalDate.parse(t.dueDate!),
      title: t.title,
      kind: CalendarEntryKind.todo,
      color: _priorityColor(t.priority),
      time: t.dueTime,
      sourceId: t.id,
    );
  }

  static Color _priorityColor(TodoPriority p) => switch (p) {
        TodoPriority.high => const Color(0xFFE5484D),   // danger
        TodoPriority.medium => const Color(0xFFF5A524), // warning
        TodoPriority.none => const Color(0xFF6B6B78),   // muted
      };
}

// ── Riverpod provider ─────────────────────────────────────────────────────

/// Stream of todo CalendarEntry items for a given date range.
/// Emits empty stream when repository is not yet available.
final todoCalendarEntriesProvider =
    StreamProvider.family<List<CalendarEntry>, DateRange>((ref, range) {
  final repo = ref.watch(todoRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return TodoCalendarSource(repo).watch(range);
});
