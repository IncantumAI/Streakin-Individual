// test/features/todos/todo_bridge_test.dart
// Unit tests for Track 4B: TodoBridgeImpl — promote / demote / watchCheckboxState.
//
// Uses in-memory Drift DBs for both NoteRepository and TodoRepository.
// FTS indexing is stubbed — the bridge only reads/writes note body JSON,
// not the FTS5 virtual table (which requires SQLCipher to be linked).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/storage/app_database.dart' show AppDatabase;
import 'package:streakin/features/notes/application/todo_bridge_impl.dart';
import 'package:streakin/features/notes/data/drift_note_repository.dart';
import 'package:streakin/features/notes/data/note_dao.dart';
import 'package:streakin/features/notes/domain/folder.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';
import 'package:streakin/features/todos/data/drift_todo_repository.dart';
import 'package:streakin/features/todos/data/todo_dao.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:uuid/uuid.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

AppDatabase _openInMemory() => AppDatabase(NativeDatabase.memory());

const _uuid = Uuid();

Note _note({String? id, String body = '[]', String title = 'Test note'}) =>
    Note(
      id: id ?? _uuid.v4(),
      title: title,
      body: body,
      createdAt: DateTime(2026, 10, 7),
      updatedAt: DateTime(2026, 10, 7),
      hlc: '2026-10-07T00:00:00.000Z-0000-test',
    );

(Note, String) _noteWithTask({String? noteId, String taskText = 'Buy milk'}) {
  final blockId = _uuid.v4();
  final doc = NoteDocument([
    NoteBlock(id: blockId, kind: NoteBlockKind.task, text: taskText),
  ]);
  return (_note(id: noteId, body: doc.toJson()), blockId);
}

// ── Stub NoteRepository ────────────────────────────────────────────────────
// Skips FTS indexing so tests don't need the FTS5 virtual table.
// Delegates read/write to DriftNoteRepository, which has its own mapper
// extensions for domain.Note ↔ Drift row conversions.

class _StubNoteRepository implements NoteRepository {
  _StubNoteRepository(AppDatabase db)
    : _real = DriftNoteRepository(NoteDao(db), _NoOpFts());

  final DriftNoteRepository _real;

  @override
  Stream<Note?> watchNote(String id) => _real.watchNote(id);

  @override
  Future<void> saveNote(Note note) => _real.saveNote(note);

  @override
  Future<void> softDeleteNote(String id) => _real.softDeleteNote(id);

  // ── Unused by bridge ──────────────────────────────────────────────────────
  @override
  Stream<List<Note>> watchFolder(String? folderId) => const Stream.empty();
  @override
  Stream<List<Folder>> watchFolders() => const Stream.empty();
  @override
  Future<void> saveFolder(Folder folder) async {}
  @override
  Future<void> moveNote(String noteId, String? targetFolderId) async {}
  @override
  Future<void> moveFolder(String folderId, String? targetParentId) async {}
  @override
  Future<void> softDeleteFolder(String id) async {}
  @override
  Stream<List<Note>> watchBacklinks(String noteId) => const Stream.empty();
  @override
  Stream<List<Note>> watchOutgoingLinks(String noteId) => const Stream.empty();
  @override
  Stream<List<String>> watchTags() => const Stream.empty();
  @override
  Stream<List<Note>> watchNotesByTag(String tag) => const Stream.empty();
  @override
  Future<Note?> getById(String id) => _real.getById(id);
  @override
  Future<List<Note>> searchByTitle(String query) async => [];
}

/// FTS stub that does nothing — avoids FTS5 virtual table errors in-memory.
class _NoOpFts extends NoteFtsDao {
  _NoOpFts() : super(_nullDb);
  static final _nullDb = AppDatabase(NativeDatabase.memory());

  @override
  Future<void> index(String noteId, String title, String plainText) async {}

  @override
  Future<void> remove(String noteId) async {}
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late _StubNoteRepository noteRepo;
  late DriftTodoRepository todoRepo;
  late TodoBridgeImpl bridge;

  setUp(() {
    db = _openInMemory();
    noteRepo = _StubNoteRepository(db);
    todoRepo = DriftTodoRepository(TodoDao(db));
    bridge = TodoBridgeImpl(noteRepo: noteRepo, todoRepo: todoRepo);
  });

  tearDown(() => db.close());

  // ── promoteCheckbox ──────────────────────────────────────────────────────

  group('promoteCheckbox', () {
    test('creates Todo with correct sourceNoteId and sourceBlockId', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      expect(todo, isNotNull);
      expect(todo!.title, 'Buy milk');
      expect(todo.sourceNoteId, note.id);
      expect(todo.sourceBlockId, blockId);
      expect(todo.status, TodoStatus.pending);
    });

    test('stores linkedTodoId in NoteBlock attrs', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');

      final updatedNote = await noteRepo.watchNote(note.id).first;
      final doc = NoteDocument.fromJson(updatedNote!.body);
      final block = doc.blocks.firstWhere((b) => b.id == blockId);
      expect(block.attrs['linkedTodoId'], isNotNull);
      expect(block.attrs['linkedTodoId'], isA<String>());
    });

    test('linkedTodoId in block matches created Todo id', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      final updatedNote = await noteRepo.watchNote(note.id).first;
      final doc = NoteDocument.fromJson(updatedNote!.body);
      final block = doc.blocks.firstWhere((b) => b.id == blockId);
      expect(block.attrs['linkedTodoId'], todo!.id);
    });

    test('is idempotent — second promote does nothing', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      expect(todo, isNotNull);
    });

    test('promoted task appears in watchAnytime stream', () async {
      final (note, blockId) = _noteWithTask(taskText: 'Walk dog');
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Walk dog');

      final anytime = await todoRepo.watchAnytime().first;
      expect(anytime.any((t) => t.title == 'Walk dog'), isTrue);
    });
  });

  // ── demoteCheckbox ───────────────────────────────────────────────────────

  group('demoteCheckbox', () {
    test('soft-deletes the linked Todo', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');
      await bridge.demoteCheckbox(note.id, blockId);

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      expect(todo, isNull);
    });

    test('removes linkedTodoId from block attrs', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');
      await bridge.demoteCheckbox(note.id, blockId);

      final updatedNote = await noteRepo.watchNote(note.id).first;
      final doc = NoteDocument.fromJson(updatedNote!.body);
      final block = doc.blocks.firstWhere((b) => b.id == blockId);
      expect(block.attrs['linkedTodoId'], isNull);
    });

    test('demote on plain checkbox is a no-op', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.demoteCheckbox(note.id, blockId);

      final anytime = await todoRepo.watchAnytime().first;
      expect(anytime, isEmpty);
    });

    test('demoted task no longer appears in any stream', () async {
      final (note, blockId) = _noteWithTask(taskText: 'Feed cat');
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Feed cat');
      await bridge.demoteCheckbox(note.id, blockId);

      final anytime = await todoRepo.watchAnytime().first;
      final done = await todoRepo.watchDone().first;
      expect(anytime.any((t) => t.title == 'Feed cat'), isFalse);
      expect(done.any((t) => t.title == 'Feed cat'), isFalse);
    });
  });

  // ── watchCheckboxState ───────────────────────────────────────────────────

  group('watchCheckboxState', () {
    test('emits false when no linked task', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      expect(await bridge.watchCheckboxState(note.id, blockId).first, isFalse);
    });

    test('emits false when linked task is pending', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');
      expect(await bridge.watchCheckboxState(note.id, blockId).first, isFalse);
    });

    test('emits true when linked task is completed', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      await todoRepo.complete(todo!.id);

      expect(await bridge.watchCheckboxState(note.id, blockId).first, isTrue);
    });

    test('emits false after uncomplete', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      await todoRepo.complete(todo!.id);
      await todoRepo.uncomplete(todo.id);

      expect(await bridge.watchCheckboxState(note.id, blockId).first, isFalse);
    });

    test('emits false after demotion', () async {
      final (note, blockId) = _noteWithTask();
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');
      await bridge.demoteCheckbox(note.id, blockId);

      expect(await bridge.watchCheckboxState(note.id, blockId).first, isFalse);
    });
  });

  // ── Integration ──────────────────────────────────────────────────────────

  group('Integration', () {
    test('complete from todo list → watchCheckboxState → true', () async {
      final (note, blockId) = _noteWithTask(taskText: 'Meditate');
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Meditate');

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      await todoRepo.complete(todo!.id);

      expect(await bridge.watchCheckboxState(note.id, blockId).first, isTrue);
    });

    test('source note soft-deleted → task persists', () async {
      final (note, blockId) = _noteWithTask(taskText: 'Exercise');
      await noteRepo.saveNote(note);
      await bridge.promoteCheckbox(note.id, blockId, 'Exercise');
      await noteRepo.softDeleteNote(note.id);

      final todo = await todoRepo.watchBySourceBlock(note.id, blockId).first;
      expect(todo, isNotNull);
      expect(todo!.title, 'Exercise');
    });

    test('plain checkboxes never appear in todo list', () async {
      final (note, _) = _noteWithTask(taskText: 'Unpromoted');
      await noteRepo.saveNote(note);
      expect(await todoRepo.watchAnytime().first, isEmpty);
      expect(await todoRepo.watchDone().first, isEmpty);
    });

    test('multiple checkboxes in same note promote independently', () async {
      final blockId1 = _uuid.v4();
      final blockId2 = _uuid.v4();
      final doc = NoteDocument([
        NoteBlock(id: blockId1, kind: NoteBlockKind.task, text: 'Task A'),
        NoteBlock(id: blockId2, kind: NoteBlockKind.task, text: 'Task B'),
      ]);
      final note = _note(body: doc.toJson());
      await noteRepo.saveNote(note);

      await bridge.promoteCheckbox(note.id, blockId1, 'Task A');
      await bridge.promoteCheckbox(note.id, blockId2, 'Task B');

      final todoA = await todoRepo.watchBySourceBlock(note.id, blockId1).first;
      final todoB = await todoRepo.watchBySourceBlock(note.id, blockId2).first;
      expect(todoA?.title, 'Task A');
      expect(todoB?.title, 'Task B');
      expect(todoA?.id, isNot(todoB?.id));
    });

    test('demoting one checkbox does not affect its sibling', () async {
      final blockId1 = _uuid.v4();
      final blockId2 = _uuid.v4();
      final doc = NoteDocument([
        NoteBlock(id: blockId1, kind: NoteBlockKind.task, text: 'Task A'),
        NoteBlock(id: blockId2, kind: NoteBlockKind.task, text: 'Task B'),
      ]);
      final note = _note(body: doc.toJson());
      await noteRepo.saveNote(note);

      await bridge.promoteCheckbox(note.id, blockId1, 'Task A');
      await bridge.promoteCheckbox(note.id, blockId2, 'Task B');
      await bridge.demoteCheckbox(note.id, blockId1);

      expect(
        await todoRepo.watchBySourceBlock(note.id, blockId1).first,
        isNull,
      );
      expect(
        (await todoRepo.watchBySourceBlock(note.id, blockId2).first)?.title,
        'Task B',
      );
    });
  });
}
