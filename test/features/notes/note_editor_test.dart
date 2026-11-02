// test/features/notes/note_editor_test.dart
// Unit tests for Track 3C: editor controller bridge, autosave, templates.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_editor/super_editor.dart';

import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';
import 'package:streakin/features/notes/editor/note_autosave_service.dart';
import 'package:streakin/features/notes/editor/note_editor_controller.dart';
import 'package:streakin/features/notes/editor/note_templates.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockNoteRepository extends Mock implements NoteRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Note _note({String body = '[]', String title = 'Test'}) => Note(
  id: 'note-1',
  title: title,
  body: body,
  createdAt: DateTime(2026, 10, 6),
  updatedAt: DateTime(2026, 10, 6),
  hlc: '1728230400000-0-test',
);

void main() {
  // ── NoteEditorController bridge ─────────────────────────────────────────────

  group('NoteEditorController — NoteDocument ↔ super_editor bridge', () {
    test(
      'Empty NoteDocument creates single empty paragraph in super_editor',
      () {
        final ctrl = NoteEditorController(initialDocument: NoteDocument([]));
        expect(ctrl.document.nodeCount, 1);
        expect(ctrl.document.first, isA<ParagraphNode>());
        ctrl.dispose();
      },
    );

    test('Heading1 block maps to ParagraphNode with header1Attribution', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'h1',
          kind: NoteBlockKind.heading1,
          text: 'My Title',
        ),
      ]);
      final ctrl = NoteEditorController(initialDocument: doc);
      final node = ctrl.document.getNodeById('h1') as ParagraphNode;
      expect(node.text.toPlainText(), 'My Title');
      expect(node.getMetadataValue('blockType'), header1Attribution);
      ctrl.dispose();
    });

    test('TaskNode maps correctly with isComplete=true', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 't1',
          kind: NoteBlockKind.task,
          text: 'Done',
          isComplete: true,
        ),
      ]);
      final ctrl = NoteEditorController(initialDocument: doc);
      final node = ctrl.document.getNodeById('t1') as TaskNode;
      expect(node.isComplete, true);
      expect(node.text.toPlainText(), 'Done');
      ctrl.dispose();
    });

    test('Bullet and ordered list items map to ListItemNode', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.bulletItem,
          text: 'Bullet',
        ),
        const NoteBlock(
          id: 'o1',
          kind: NoteBlockKind.orderedItem,
          text: 'Ordered',
        ),
      ]);
      final ctrl = NoteEditorController(initialDocument: doc);
      final bullet = ctrl.document.getNodeById('b1') as ListItemNode;
      final ordered = ctrl.document.getNodeById('o1') as ListItemNode;
      expect(bullet.type, ListItemType.unordered);
      expect(ordered.type, ListItemType.ordered);
      ctrl.dispose();
    });

    test('HorizontalRuleNode maps to divider block', () {
      final doc = NoteDocument([
        const NoteBlock(id: 'hr1', kind: NoteBlockKind.divider),
      ]);
      final ctrl = NoteEditorController(initialDocument: doc);
      expect(ctrl.document.getNodeById('hr1'), isA<HorizontalRuleNode>());
      ctrl.dispose();
    });

    test('Blockquote maps to ParagraphNode with blockquoteAttribution', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'bq1',
          kind: NoteBlockKind.blockquote,
          text: 'Quote',
        ),
      ]);
      final ctrl = NoteEditorController(initialDocument: doc);
      final node = ctrl.document.getNodeById('bq1') as ParagraphNode;
      expect(node.getMetadataValue('blockType'), blockquoteAttribution);
      ctrl.dispose();
    });

    test('toDomain() round-trips heading through super_editor', () {
      final original = NoteDocument([
        const NoteBlock(id: 'h1', kind: NoteBlockKind.heading1, text: 'Hello'),
        const NoteBlock(id: 'p1', kind: NoteBlockKind.paragraph, text: 'World'),
      ]);
      final ctrl = NoteEditorController(initialDocument: original);
      final restored = ctrl.toDomain();
      expect(restored.blocks.length, 2);
      expect(restored.blocks[0].kind, NoteBlockKind.heading1);
      expect(restored.blocks[0].text, 'Hello');
      expect(restored.blocks[1].kind, NoteBlockKind.paragraph);
      expect(restored.blocks[1].text, 'World');
      ctrl.dispose();
    });

    test('Change listener is called when document changes', () {
      final doc = NoteDocument([
        const NoteBlock(id: 'p1', kind: NoteBlockKind.paragraph, text: 'Hi'),
      ]);
      final ctrl = NoteEditorController(initialDocument: doc);
      var callCount = 0;
      ctrl.addChangeListener(() => callCount++);

      // Insert a new node via the Editor (goes through the reaction pipeline
      // and triggers the MutableDocument listener).
      ctrl.editor.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: 'p1',
          newNode: ParagraphNode(id: 'p2', text: AttributedText('New')),
        ),
      ]);

      expect(callCount, greaterThan(0));
      ctrl.dispose();
    });
  });

  // ── NoteAutosaveService ─────────────────────────────────────────────────────

  group('NoteAutosaveService', () {
    late MockNoteRepository mockRepo;

    setUp(() {
      mockRepo = MockNoteRepository();
      registerFallbackValue(_note());
      when(() => mockRepo.getById(any())).thenAnswer((_) async => _note());
      when(() => mockRepo.saveNote(any())).thenAnswer((_) async {});
    });

    test('state starts as idle', () {
      final svc = NoteAutosaveService(repository: mockRepo, noteId: 'note-1');
      expect(svc.state, AutosaveState.idle);
      svc.dispose();
    });

    test('onContentChanged moves state to pending', () {
      final svc = NoteAutosaveService(
        repository: mockRepo,
        noteId: 'note-1',
        debounce: const Duration(seconds: 10),
      );
      svc.onContentChanged(NoteDocument([]), 'Title');
      expect(svc.state, AutosaveState.pending);
      svc.dispose();
    });

    test('debounce: save fires after 2s, not immediately', () {
      fakeAsync((async) {
        final svc = NoteAutosaveService(repository: mockRepo, noteId: 'note-1');

        svc.onContentChanged(
          NoteDocument([
            const NoteBlock(
              id: 'p1',
              kind: NoteBlockKind.paragraph,
              text: 'Hello',
            ),
          ]),
          'My Note',
        );

        // Before debounce completes — should not have saved yet.
        async.elapse(const Duration(milliseconds: 500));
        verifyNever(() => mockRepo.saveNote(any()));

        // After debounce — should have saved.
        async.elapse(const Duration(seconds: 2));
        verify(() => mockRepo.saveNote(any())).called(1);

        svc.dispose();
      });
    });

    test(
      'saveNow() flushes immediately without waiting for debounce',
      () async {
        final svc = NoteAutosaveService(
          repository: mockRepo,
          noteId: 'note-1',
          debounce: const Duration(seconds: 30), // Long debounce
        );

        svc.onContentChanged(NoteDocument([]), 'Title');
        await svc.saveNow();

        verify(() => mockRepo.saveNote(any())).called(1);
        svc.dispose();
      },
    );

    test('rapid changes only trigger one save (debounce resets)', () {
      fakeAsync((async) {
        final svc = NoteAutosaveService(repository: mockRepo, noteId: 'note-1');

        // Rapid-fire 5 changes within 1 second.
        for (int i = 0; i < 5; i++) {
          svc.onContentChanged(NoteDocument([]), 'Title $i');
          async.elapse(const Duration(milliseconds: 200));
        }

        // Wait for debounce to settle.
        async.elapse(const Duration(seconds: 3));

        // Only one save should have been called.
        verify(() => mockRepo.saveNote(any())).called(1);
        svc.dispose();
      });
    });

    test('state transitions: pending → saving → saved', () async {
      final states = <AutosaveState>[];
      final svc = NoteAutosaveService(
        repository: mockRepo,
        noteId: 'note-1',
        debounce: Duration.zero,
      );
      svc.addListener(() => states.add(svc.state));
      svc.onContentChanged(NoteDocument([]), 'Title');
      await svc.saveNow();

      expect(
        states,
        containsAllInOrder([
          AutosaveState.pending,
          AutosaveState.saving,
          AutosaveState.saved,
        ]),
      );
      svc.dispose();
    });

    test('state is error when repository throws', () async {
      when(() => mockRepo.saveNote(any())).thenThrow(Exception('DB error'));

      final svc = NoteAutosaveService(
        repository: mockRepo,
        noteId: 'note-1',
        debounce: Duration.zero,
      );
      svc.onContentChanged(NoteDocument([]), 'Title');
      await svc.saveNow();

      expect(svc.state, AutosaveState.error);
      svc.dispose();
    });
  });

  // ── NoteTemplates ───────────────────────────────────────────────────────────

  group('NoteTemplates', () {
    test('All 6 template kinds are covered in kAllTemplates', () {
      final kinds = kAllTemplates.map((t) => t.kind).toSet();
      for (final kind in NoteTemplateKind.values) {
        expect(
          kinds,
          contains(kind),
          reason: '$kind missing from kAllTemplates',
        );
      }
    });

    test('blank template produces a single empty paragraph', () {
      final doc = buildTemplate(NoteTemplateKind.blank);
      expect(doc.blocks.length, 1);
      expect(doc.blocks.first.kind, NoteBlockKind.paragraph);
      expect(doc.blocks.first.text, '');
    });

    test('whatHappenedToday template starts with heading2', () {
      final doc = buildTemplate(NoteTemplateKind.whatHappenedToday);
      expect(doc.blocks.first.kind, NoteBlockKind.heading2);
      expect(doc.blocks.first.text, contains('today'));
    });

    test('summaryOfTheDay template contains task blocks', () {
      final doc = buildTemplate(NoteTemplateKind.summaryOfTheDay);
      final tasks = doc.blocks.where((b) => b.kind == NoteBlockKind.task);
      expect(tasks.length, greaterThanOrEqualTo(3));
    });

    test('whereDidYouFallBack template contains a task block', () {
      final doc = buildTemplate(NoteTemplateKind.whereDidYouFallBack);
      final tasks = doc.blocks.where((b) => b.kind == NoteBlockKind.task);
      expect(tasks.isNotEmpty, isTrue);
    });

    test('brainstorm template contains bullet items', () {
      final doc = buildTemplate(NoteTemplateKind.brainstorm);
      final bullets = doc.blocks.where(
        (b) => b.kind == NoteBlockKind.bulletItem,
      );
      expect(bullets.isNotEmpty, isTrue);
    });

    test('All templates produce valid NoteDocument JSON round-trips', () {
      for (final kind in NoteTemplateKind.values) {
        final doc = buildTemplate(kind);
        final json = doc.toJson();
        final restored = NoteDocument.fromJson(json);
        expect(
          restored.blocks.length,
          doc.blocks.length,
          reason: 'Round-trip failed for $kind',
        );
      }
    });

    test('templateTitle returns non-empty string for all non-blank kinds', () {
      for (final kind in NoteTemplateKind.values) {
        if (kind == NoteTemplateKind.blank) continue;
        expect(
          templateTitle(kind).isNotEmpty,
          isTrue,
          reason: 'Empty title for $kind',
        );
      }
    });
  });
}
