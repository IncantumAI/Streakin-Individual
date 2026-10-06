// lib/features/notes/application/notes_calendar_source.dart
// NotesCalendarSource — implements CalendarSource for @date mentions in notes.
// Spec §4.5: Calendar is a read-only projection over data from each feature.

import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/calendar/domain/calendar_source.dart';
import 'package:streakin/features/notes/data/note_dao.dart';

class NotesCalendarSource implements CalendarSource {
  NotesCalendarSource(this._dao);
  final NoteDao _dao;

  @override
  Stream<List<CalendarEntry>> watch(DateRange range) async* {
    final startIso = range.start.toIso();
    final endIso = range.end.toIso();

    await for (final mentions
        in _dao.watchDateMentionsInRange(startIso, endIso)) {
      final entries = mentions
          // Skip vault notes while vault is locked (Phase 5 — for now show all).
          .where((m) => m.vaultId == null)
          .map((m) {
        // Parse date from startsAt (ISO-8601 date or datetime string).
        final dateStr = m.startsAt.length >= 10
            ? m.startsAt.substring(0, 10)
            : m.startsAt;
        final date = LocalDate.parse(dateStr);
        return CalendarEntry(
          date: date,
          title: m.genericLabel ?? 'Note date',
          kind: CalendarEntryKind.note,
          sourceId: m.noteId,
        );
      }).toList();
      yield entries;
    }
  }
}
