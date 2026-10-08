// test/features/notes/notes_3h_test.dart
// Unit tests for Track 3H: NotesCalendarSource and NotesDashboardProvider.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/calendar/domain/calendar_source.dart';
import 'package:streakin/features/notes/application/notes_calendar_source.dart';
import 'package:streakin/features/notes/application/notes_dashboard_provider.dart';
import 'package:streakin/features/notes/domain/folder.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockNoteRepository extends Mock implements NoteRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Note _note({
  String id = 'n1',
  String title = 'Test Note',
  String body = '[]',
  bool isPinned = false,
  String? vaultId,
  DateTime? updatedAt,
}) =>
    Note(
      id: id,
      title: title,
      body: body,
      isPinned: isPinned,
      vaultId: vaultId,
      createdAt: DateTime(2026, 10),
      updatedAt: updatedAt ?? DateTime(2026, 10),
      hlc: '0-0-test',
    );

String _bodyWithDate(String isoDate) {
  final doc = NoteDocument([
    NoteBlock(
        id: 'b1',
        kind: NoteBlockKind.paragraph,
        text: 'Meeting @$isoDate today'),
  ]);
  return doc.toJson();
}

void main() {
  group('NotesCalendarSource', () {
    late MockNoteRepository repo;

    setUp(() {
      repo = MockNoteRepository();
      registerFallbackValue(const DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      ));
    });

    test('Returns CalendarEntry for note with @date mention in range', () async {
      final note = _note(
        title: 'Planning',
        body: _bodyWithDate('2026-10-05'),
      );

      when(() => repo.watchFolders())
          .thenAnswer((_) => Stream.value([]));
      when(() => repo.watchFolder(null))
          .thenAnswer((_) => Stream.value([note]));

      final source = NotesCalendarSource(repo);
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );

      final entries = await source.watch(range).first;

      expect(entries.length, 1);
      expect(entries.first.date, const LocalDate(2026, 10, 5));
      expect(entries.first.title, 'Planning');
      expect(entries.first.kind, CalendarEntryKind.note);
      expect(entries.first.sourceId, 'n1');
    });

    test('Returns empty list when note has no @date mentions', () async {
      final note = _note();

      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));
      when(() => repo.watchFolder(null)).thenAnswer((_) => Stream.value([note]));

      final source = NotesCalendarSource(repo);
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );

      final entries = await source.watch(range).first;
      expect(entries, isEmpty);
    });

    test('Excludes @date mentions outside the range', () async {
      final note = _note(body: _bodyWithDate('2026-11-15'));

      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));
      when(() => repo.watchFolder(null)).thenAnswer((_) => Stream.value([note]));

      final source = NotesCalendarSource(repo);
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );

      final entries = await source.watch(range).first;
      expect(entries, isEmpty);
    });

    test('Excludes deleted notes', () async {
      final note = Note(
        id: 'n1',
        title: 'Deleted',
        body: _bodyWithDate('2026-10-05'),
        createdAt: DateTime(2026, 10),
        updatedAt: DateTime(2026, 10),
        hlc: '0-0-test',
        deletedAt: DateTime(2026, 10, 2),
      );

      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));
      when(() => repo.watchFolder(null)).thenAnswer((_) => Stream.value([note]));

      final source = NotesCalendarSource(repo);
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );

      final entries = await source.watch(range).first;
      expect(entries, isEmpty);
    });

    test('Excludes vault notes', () async {
      final note = _note(body: _bodyWithDate('2026-10-05'), vaultId: 'vault1');

      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));
      when(() => repo.watchFolder(null)).thenAnswer((_) => Stream.value([note]));

      final source = NotesCalendarSource(repo);
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );

      final entries = await source.watch(range).first;
      expect(entries, isEmpty);
    });

    test('Scans notes in sub-folders too', () async {
      const folder = Folder(id: 'f1', name: 'Work', hlc: '0-0-test');
      final note = _note(
          id: 'n2', title: 'In folder', body: _bodyWithDate('2026-10-10'));

      when(() => repo.watchFolders())
          .thenAnswer((_) => Stream.value([folder]));
      when(() => repo.watchFolder(null))
          .thenAnswer((_) => Stream.value([]));
      when(() => repo.watchFolder('f1'))
          .thenAnswer((_) => Stream.value([note]));

      final source = NotesCalendarSource(repo);
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );

      final entries = await source.watch(range).first;
      expect(entries.length, 1);
      expect(entries.first.sourceId, 'n2');
    });

    test('Multiple @date mentions in one note each produce an entry', () async {
      final doc = NoteDocument([
        const NoteBlock(
            id: 'b1',
            kind: NoteBlockKind.paragraph,
            text: 'Meet @2026-10-05 and followup @2026-10-12'),
      ]);
      final note = _note(body: doc.toJson());

      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));
      when(() => repo.watchFolder(null)).thenAnswer((_) => Stream.value([note]));

      final source = NotesCalendarSource(repo);
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );

      final entries = await source.watch(range).first;
      expect(entries.length, 2);
    });
  });

  group('NotesDashboardProvider', () {
    late MockNoteRepository repo;

    setUp(() {
      repo = MockNoteRepository();
    });

    test('watchRecentNotes returns 5 most recently updated non-vault notes',
        () async {
      final notes = List.generate(
        7,
        (i) => _note(
          id: 'n$i',
          title: 'Note $i',
          updatedAt: DateTime(2026, 10, i + 1),
        ),
      );

      when(() => repo.watchFolder(null))
          .thenAnswer((_) => Stream.value(notes));
      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));

      final provider = NotesDashboardProvider(repo);
      final recent = await provider.watchRecentNotes(5).first;

      expect(recent.length, 5);
      // Should be sorted newest first.
      expect(recent.first.id, 'n6');
    });

    test('watchRecentNotes excludes vault notes', () async {
      final notes = [
        _note(updatedAt: DateTime(2026, 10, 3)),
        _note(id: 'n2', vaultId: 'v1', updatedAt: DateTime(2026, 10, 5)),
      ];

      when(() => repo.watchFolder(null))
          .thenAnswer((_) => Stream.value(notes));
      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));

      final provider = NotesDashboardProvider(repo);
      final recent = await provider.watchRecentNotes(5).first;

      expect(recent.length, 1);
      expect(recent.first.id, 'n1');
    });

    test('watchPinnedNotes returns only pinned non-vault notes', () async {
      final notes = [
        _note(isPinned: true),
        _note(id: 'n2'),
        _note(id: 'n3', isPinned: true, vaultId: 'v1'),
      ];

      when(() => repo.watchFolder(null))
          .thenAnswer((_) => Stream.value(notes));
      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));

      final provider = NotesDashboardProvider(repo);
      final pinned = await provider.watchPinnedNotes().first;

      expect(pinned.length, 1);
      expect(pinned.first.id, 'n1');
    });

    test('RecentNoteItem has correct title and updatedAt', () async {
      final note = _note(
          title: 'My Note',
          updatedAt: DateTime(2026, 10, 5, 14, 30));

      when(() => repo.watchFolder(null))
          .thenAnswer((_) => Stream.value([note]));
      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));

      final provider = NotesDashboardProvider(repo);
      final recent = await provider.watchRecentNotes(5).first;

      expect(recent.first.title, 'My Note');
      expect(recent.first.updatedAt, DateTime(2026, 10, 5, 14, 30));
    });

    test('Empty title becomes Untitled in RecentNoteItem', () async {
      final note = _note(title: '');

      when(() => repo.watchFolder(null))
          .thenAnswer((_) => Stream.value([note]));
      when(() => repo.watchFolders()).thenAnswer((_) => Stream.value([]));

      final provider = NotesDashboardProvider(repo);
      final recent = await provider.watchRecentNotes(5).first;

      expect(recent.first.title, 'Untitled');
    });
  });
}
