// test/features/notes/note_document_test.dart
// Unit tests for NoteDocument — serialisation, link/tag/date extraction.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/domain/note_document.dart';

void main() {
  group('NoteDocument — serialisation round-trip', () {
    test('Empty body deserialises to empty document', () {
      expect(NoteDocument.fromJson('').isEmpty, isTrue);
      expect(NoteDocument.fromJson('{}').isEmpty, isTrue);
    });

    test('Blocks serialise and deserialise correctly', () {
      final doc = NoteDocument([
        const NoteBlock(id: 'b1', kind: NoteBlockKind.heading1, text: 'Hello'),
        const NoteBlock(id: 'b2', kind: NoteBlockKind.paragraph, text: 'World'),
        const NoteBlock(
          id: 'b3',
          kind: NoteBlockKind.task,
          text: 'Do it',
          isComplete: true,
        ),
        const NoteBlock(id: 'b4', kind: NoteBlockKind.divider),
      ]);
      final json = doc.toJson();
      final restored = NoteDocument.fromJson(json);

      expect(restored.blocks.length, 4);
      expect(restored.blocks[0].kind, NoteBlockKind.heading1);
      expect(restored.blocks[0].text, 'Hello');
      expect(restored.blocks[1].kind, NoteBlockKind.paragraph);
      expect(restored.blocks[2].isComplete, isTrue);
      expect(restored.blocks[3].kind, NoteBlockKind.divider);
    });

    test('Unknown block kind falls back to paragraph', () {
      const json = '[{"id":"x","kind":"unknown_future_block","text":"hi"}]';
      final doc = NoteDocument.fromJson(json);
      expect(doc.blocks.first.kind, NoteBlockKind.paragraph);
    });

    test('Legacy map-with-blocks-key is parsed', () {
      const json = '{"blocks":[{"id":"b1","kind":"paragraph","text":"A"}]}';
      final doc = NoteDocument.fromJson(json);
      expect(doc.blocks.length, 1);
      expect(doc.blocks.first.text, 'A');
    });
  });

  group('NoteDocument — toPlainText', () {
    test('Includes text from all text blocks', () {
      final doc = NoteDocument([
        const NoteBlock(id: 'b1', kind: NoteBlockKind.heading1, text: 'Title'),
        const NoteBlock(
          id: 'b2',
          kind: NoteBlockKind.paragraph,
          text: 'Body text',
        ),
        const NoteBlock(id: 'b3', kind: NoteBlockKind.divider),
      ]);
      final pt = doc.toPlainText();
      expect(pt.contains('Title'), isTrue);
      expect(pt.contains('Body text'), isTrue);
    });

    test('Dividers and empty blocks are excluded from plaintext', () {
      final doc = NoteDocument([
        const NoteBlock(id: 'b1', kind: NoteBlockKind.divider),
        const NoteBlock(id: 'b2', kind: NoteBlockKind.paragraph),
      ]);
      expect(doc.toPlainText(), isEmpty);
    });
  });

  group('NoteDocument — extractLinks', () {
    test('Extracts [[wiki link]] targets', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'See [[Project Alpha]] and [[Daily Review]]',
        ),
      ]);
      final links = doc.extractLinks();
      expect(links.length, 2);
      expect(
        links.map((l) => l.targetTitle).toList(),
        containsAll(['Project Alpha', 'Daily Review']),
      );
      expect(links.every((l) => l.blockId == 'b1'), isTrue);
    });

    test('No links returns empty list', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'No links here',
        ),
      ]);
      expect(doc.extractLinks(), isEmpty);
    });

    test('Multiple links in same block all captured', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: '[[A]] and [[B]] and [[C]]',
        ),
      ]);
      expect(doc.extractLinks().length, 3);
    });
  });

  group('NoteDocument — extractTags', () {
    test('Extracts #hashtags from text', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'Tagged #work and #learning',
        ),
        const NoteBlock(
          id: 'b2',
          kind: NoteBlockKind.paragraph,
          text: 'Also #health',
        ),
      ]);
      final tags = doc.extractTags();
      expect(tags, containsAll(['work', 'learning', 'health']));
    });

    test('Tags are lowercased', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: '#Work #LEARNING',
        ),
      ]);
      final tags = doc.extractTags();
      expect(tags, containsAll(['work', 'learning']));
    });

    test('Duplicate tags deduplicated', () {
      final doc = NoteDocument([
        const NoteBlock(id: 'b1', kind: NoteBlockKind.paragraph, text: '#work'),
        const NoteBlock(id: 'b2', kind: NoteBlockKind.paragraph, text: '#work'),
      ]);
      expect(doc.extractTags().length, 1);
    });

    test('No tags returns empty set', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'No hashtags here',
        ),
      ]);
      expect(doc.extractTags(), isEmpty);
    });
  });

  group('NoteDocument — extractDateMentions', () {
    test('Extracts @YYYY-MM-DD date mentions', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'Meeting @2026-10-05 and deadline @2026-12-31',
        ),
      ]);
      final mentions = doc.extractDateMentions();
      expect(mentions.length, 2);
      expect(
        mentions.map((m) => m.isoDate).toList(),
        containsAll(['2026-10-05', '2026-12-31']),
      );
      expect(mentions.every((m) => m.blockId == 'b1'), isTrue);
    });

    test('No date mentions returns empty list', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'No dates here',
        ),
      ]);
      expect(doc.extractDateMentions(), isEmpty);
    });
  });

  group('NoteDocument — NoteBlock.copyWith', () {
    test('copyWith returns new block with updated fields', () {
      const block = NoteBlock(id: 'b1', kind: NoteBlockKind.task, text: 'Task');
      final updated = block.copyWith(isComplete: true, text: 'Done task');
      expect(updated.isComplete, isTrue);
      expect(updated.text, 'Done task');
      expect(updated.id, 'b1'); // unchanged
      expect(updated.kind, NoteBlockKind.task); // unchanged
    });
  });
}
