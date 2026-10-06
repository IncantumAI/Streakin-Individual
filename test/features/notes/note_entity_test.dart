// test/features/notes/note_entity_test.dart
// Unit tests for Note, Folder, and Attachment domain entities.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/domain/attachment.dart';
import 'package:streakin/features/notes/domain/folder.dart';
import 'package:streakin/features/notes/domain/note.dart';

void main() {
  final now = DateTime(2026, 10, 5, 12);

  group('Note entity', () {
    Note note0({String id = 'n1', DateTime? deletedAt}) => Note(
          id: id,
          title: 'Test Note',
          body: '[]',
          createdAt: now,
          updatedAt: now,
          hlc: '1728129600000-0-test',
          deletedAt: deletedAt,
        );

    test('isDeleted is false when deletedAt is null', () {
      expect(note0().isDeleted, isFalse);
    });

    test('isDeleted is true when deletedAt is set', () {
      expect(note0(deletedAt: now).isDeleted, isTrue);
    });

    test('copyWith preserves unmodified fields', () {
      final note = note0();
      final updated = note.copyWith(title: 'Updated');
      expect(updated.title, 'Updated');
      expect(updated.id, note.id);
      expect(updated.body, note.body);
    });

    test('copyWith clearFolderId sets folderId to null', () {
      final note = note0().copyWith(folderId: 'f1');
      final cleared = note.copyWith(clearFolderId: true);
      expect(cleared.folderId, isNull);
    });

    test('equality is id-based', () {
      final a = note0();
      final b = note0();
      final c = note0(id: 'n2');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('default templateKind is blank', () {
      expect(note0().templateKind, NoteTemplateKind.blank);
    });

    test('NoteTemplateKind serialisation round-trip', () {
      for (final kind in NoteTemplateKind.values) {
        final serialized = kind.serialized;
        final restored = NoteTemplateKindExt.fromString(serialized);
        expect(restored, kind, reason: 'Failed for $kind');
      }
    });

    test('Unknown templateKind string falls back to blank', () {
      expect(NoteTemplateKindExt.fromString('unknown_future'), NoteTemplateKind.blank);
    });
  });

  group('Folder entity', () {
    Folder folder({String id = 'f1', String? parentId, DateTime? deletedAt}) =>
        Folder(
          id: id,
          parentId: parentId,
          name: 'Test Folder',
          hlc: '1728129600000-0-test',
          deletedAt: deletedAt,
        );

    test('isDeleted is false when deletedAt is null', () {
      expect(folder().isDeleted, isFalse);
    });

    test('isDeleted is true when deletedAt is set', () {
      expect(folder(deletedAt: now).isDeleted, isTrue);
    });

    test('root folder has null parentId', () {
      expect(folder().parentId, isNull);
    });

    test('copyWith sets parentId', () {
      final updated = folder().copyWith(parentId: 'parent1');
      expect(updated.parentId, 'parent1');
    });

    test('copyWith clearParentId sets parentId to null', () {
      final nested = folder(parentId: 'parent1');
      final moved = nested.copyWith(clearParentId: true);
      expect(moved.parentId, isNull);
    });

    test('equality is id-based', () {
      final a = folder();
      final b = folder();
      final c = folder(id: 'f2');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('Attachment entity', () {
    Attachment attachment({String kind = 'png'}) => Attachment(
          id: 'a1',
          noteId: 'n1',
          kind: AttachmentKindExt.fromString(kind),
          mime: 'image/png',
          size: 1024,
          sha256: 'abc123',
          storageName: 'uuid-file.bin',
          createdAt: now,
        );

    test('AttachmentKind serialisation round-trip', () {
      for (final kind in AttachmentKind.values) {
        final serialized = kind.serialized;
        final restored = AttachmentKindExt.fromString(serialized);
        expect(restored, kind, reason: 'Failed for $kind');
      }
    });

    test('Unknown kind throws ArgumentError', () {
      expect(() => AttachmentKindExt.fromString('xyz'), throwsArgumentError);
    });

    test('maxBytes limits are correct', () {
      expect(AttachmentKind.png.maxBytes, 10 * 1024 * 1024);
      expect(AttachmentKind.svg.maxBytes, 1 * 1024 * 1024);
      expect(AttachmentKind.pdf.maxBytes, 25 * 1024 * 1024);
    });

    test('MIME types are correct', () {
      expect(AttachmentKind.png.mime, 'image/png');
      expect(AttachmentKind.jpeg.mime, 'image/jpeg');
      expect(AttachmentKind.pdf.mime, 'application/pdf');
      expect(AttachmentKind.docx.mime, contains('wordprocessingml'));
      expect(AttachmentKind.pptx.mime, contains('presentationml'));
    });

    test('equality is id-based', () {
      final a = attachment();
      final b = attachment();
      expect(a, equals(b));
    });
  });
}
