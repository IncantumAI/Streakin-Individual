// lib/features/notes/application/notes_calendar_source.dart
// NotesCalendarSource — date mention entries for the calendar.
// Spec §4.5: Calendar is a read-only projection over data from each feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/calendar/domain/calendar_source.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

// ── NotesCalendarSource ───────────────────────────────────────────────────────

class NotesCalendarSource implements CalendarSource {
  NotesCalendarSource(this._repo);
  final NoteRepository _repo;

  @override
  Stream<List<CalendarEntry>> watch(DateRange range) async* {
    final startIso = range.start.toIso();
    final endIso = range.end.toIso();

    // Watch folders; any change causes re-scan.
    await for (final folders in _repo.watchFolders()) {
      final entries = <CalendarEntry>[];

      // Root inbox + all sub-folders.
      final folderIds = <String?>[null, ...folders.map((f) => f.id)];
      for (final folderId in folderIds) {
        final notes = await _repo.watchFolder(folderId).first;
        for (final note in notes) {
          if (note.vaultId != null || note.isDeleted) continue;
          final doc = NoteDocument.fromJson(note.body);
          for (final mention in doc.extractDateMentions()) {
            if (mention.isoDate.compareTo(startIso) >= 0 &&
                mention.isoDate.compareTo(endIso) <= 0) {
              entries.add(CalendarEntry(
                date: LocalDate.parse(mention.isoDate),
                title: note.title.isEmpty ? 'Note date' : note.title,
                kind: CalendarEntryKind.note,
                sourceId: note.id,
              ));
            }
          }
        }
      }
      yield entries;
    }
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

/// Stream of note CalendarEntry items for a given month range.
/// Returns empty stream when not yet unlocked.
final notesCalendarEntriesProvider =
    StreamProvider.family<List<CalendarEntry>, DateRange>((ref, range) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return NotesCalendarSource(repo).watch(range);
});

/// Convenience: map of ISO-date → list of note IDs for dot markers.
final notesDateMentionsByDateProvider =
    StreamProvider.family<Map<String, List<String>>, DateRange>(
        (ref, range) async* {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) { yield {}; return; }
  await for (final entries in NotesCalendarSource(repo).watch(range)) {
    final map = <String, List<String>>{};
    for (final e in entries) {
      map.putIfAbsent(e.date.toIso(), () => []).add(e.sourceId ?? '');
    }
    yield map;
  }
});
