// Track 4C: date chip text round-trip + extraction of mentions with time.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/domain/date_mention_parser.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/editor/date_mention_picker.dart';

void main() {
  test('dateChipText formats all-day and timed mentions', () {
    expect(
      dateChipText(
        ParsedMention(startsAt: DateTime(2026, 10, 15), allDay: true),
      ),
      '@2026-10-15',
    );
    expect(
      dateChipText(
        ParsedMention(startsAt: DateTime(2026, 10, 15, 17, 5), allDay: false),
      ),
      '@2026-10-15 17:05',
    );
  });

  test('extractDateMentions reads date and optional time', () {
    final doc = NoteDocument([
      const NoteBlock(
        id: 'b1',
        kind: NoteBlockKind.paragraph,
        text: 'Call @2026-10-15 17:05 and @2026-10-20',
      ),
    ]);
    final m = doc.extractDateMentions();
    expect(m.length, 2);
    expect(m[0].isoDate, '2026-10-15');
    expect(m[0].time, '17:05');
    expect(m[1].isoDate, '2026-10-20');
    expect(m[1].time, isNull);
  });

  test('extractQuery finds an @token before the cursor', () {
    expect(DateMentionPickerController.extractQuery('see @tom', 8), 'tom');
    expect(DateMentionPickerController.extractQuery('mail a@b', 8), isNull);
    expect(DateMentionPickerController.extractQuery('plain', 5), isNull);
  });
}
