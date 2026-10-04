// lib/features/calendar/domain/calendar_source.dart
// Spec §4.5: CalendarSource interface — features never import each other directly.

import 'package:streakin/core/time/local_date.dart';

/// A single event entry on the calendar.
class CalendarEntry {
  const CalendarEntry({
    required this.date,
    required this.title,
    required this.kind,
    this.color,
    this.time,
    this.sourceId,
  });

  final LocalDate date;
  final String title;
  final CalendarEntryKind kind;
  final Object? color;    // Color — typed as Object to keep domain layer Flutter-free
  final String? time;     // "HH:mm" display string
  final String? sourceId; // habit/todo/note id for navigation
}

enum CalendarEntryKind { habit, todo, note }

/// Interface implemented by each feature that contributes to the calendar.
abstract interface class CalendarSource {
  Stream<List<CalendarEntry>> watch(DateRange range);
}
