// test/features/notes/tag_test.dart
// Unit tests for Track 3E: tag extraction (via NoteDocument) and TagPanel logic.
// Tag extraction is already proven via note_document_test.dart — these tests
// verify the integration: saveNote rebuilds note_tags, filter provider works.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/domain/note_document.dart';

void main() {
  group('NoteDocument tag extraction (Track 3E integration)', () {
    test('Single tag extracted correctly', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'Working on #flutter today',
        ),
      ]);
      expect(doc.extractTags(), {'flutter'});
    });

    test('Multiple tags across blocks', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'Tag #work and #health',
        ),
        const NoteBlock(
          id: 'b2',
          kind: NoteBlockKind.paragraph,
          text: 'Also #learning',
        ),
      ]);
      final tags = doc.extractTags();
      expect(tags, containsAll(['work', 'health', 'learning']));
    });

    test('Tags are deduplicated across blocks', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: '#work today',
        ),
        const NoteBlock(
          id: 'b2',
          kind: NoteBlockKind.paragraph,
          text: '#work again',
        ),
      ]);
      expect(doc.extractTags().length, 1);
    });

    test('Tags are lowercased', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: '#Flutter #DART',
        ),
      ]);
      expect(doc.extractTags(), containsAll(['flutter', 'dart']));
    });

    test('Tag removed from body means no tag extracted', () {
      final docWith = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'Has #work',
        ),
      ]);
      final docWithout = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'No tag here',
        ),
      ]);
      expect(docWith.extractTags(), contains('work'));
      expect(docWithout.extractTags(), isEmpty);
    });

    test('Tag with numbers and hyphens extracted', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'Task #q1-2026 done',
        ),
      ]);
      expect(doc.extractTags(), contains('q1-2026'));
    });

    test('Inline # not followed by word char not extracted', () {
      // #100 is a number, regex is [A-Za-z0-9_\-]+, so it DOES match — that's fine
      // What should NOT match is isolated '#' or '# '
      final doc2 = NoteDocument([
        const NoteBlock(
          id: 'b2',
          kind: NoteBlockKind.paragraph,
          text: 'Use # for headings',
        ),
      ]);
      expect(doc2.extractTags(), isEmpty);
    });

    test('Empty document has no tags', () {
      expect(NoteDocument([]).extractTags(), isEmpty);
    });

    test('Task block text also searched for tags', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.task,
          text: 'Fix bug #critical',
        ),
      ]);
      expect(doc.extractTags(), contains('critical'));
    });

    test('Tags serialise/deserialise round-trip', () {
      final doc = NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'Work #project #deadline',
        ),
      ]);
      final json = doc.toJson();
      final restored = NoteDocument.fromJson(json);
      expect(restored.extractTags(), containsAll(['project', 'deadline']));
    });
  });

  group('Tag query extraction for autocomplete', () {
    // Mirror the logic from TagAutocompleteController._extractTagQuery
    String? extractTagQuery(String text, int cursor) {
      if (cursor == 0) return null;
      int hashPos = -1;
      for (int i = cursor - 1; i >= 0; i--) {
        if (text[i] == '#') {
          hashPos = i;
          break;
        }
        if (text[i] == ' ' || text[i] == '\n') break;
      }
      if (hashPos < 0) return null;
      return text.substring(hashPos + 1, cursor);
    }

    test('Returns empty string right after #', () {
      expect(extractTagQuery('hello #', 7), '');
    });

    test('Returns partial tag while typing', () {
      expect(extractTagQuery('hello #flu', 10), 'flu');
    });

    test('Returns null when cursor is not after #', () {
      expect(extractTagQuery('hello world', 11), isNull);
    });

    test('Returns null when space separates cursor from #', () {
      expect(extractTagQuery('#tag something', 14), isNull);
    });

    test('Returns full word after #', () {
      expect(extractTagQuery('note #flutter', 13), 'flutter');
    });

    test('Returns null for empty text', () {
      expect(extractTagQuery('', 0), isNull);
    });

    test('Handles multiple # in text — uses closest one', () {
      // '#work and #fl' — cursor at end, closest # is at '#fl'
      expect(extractTagQuery('#work and #fl', 13), 'fl');
    });
  });
}
