// lib/features/habits/application/habit_calendar_source.dart
// Provides CalendarEntry stream for the calendar feature — habit layer.

import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/calendar/domain/calendar_source.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';

class HabitCalendarSource implements CalendarSource {
  HabitCalendarSource(this._repo);
  final HabitRepository _repo;

  @override
  Stream<List<CalendarEntry>> watch(DateRange range) async* {
    await for (final habits in _repo.watchAll()) {
      final active = habits.where((h) => h.isActive).toList();
      final entries = <CalendarEntry>[];

      for (final habit in active) {
        for (final date in range.dates) {
          if (!habit.scheduleMask.isScheduled(date)) continue;
          entries.add(CalendarEntry(
            date: date,
            title: habit.name,
            kind: CalendarEntryKind.habit,
            sourceId: habit.id,
          ));
        }
      }
      yield entries;
    }
  }
}
