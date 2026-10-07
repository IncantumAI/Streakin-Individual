// test/core/validation/attachment_validator_test.dart
// Spec §15.1 validation corpus tests for AttachmentValidator.
// Pure Dart — no Flutter, no isolate required.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/validation/attachment_validator.dart';
import 'package:streakin/features/notes/domain/attachment.dart';

// ── Byte builders ─────────────────────────────────────────────────────────────

const _v = AttachmentValidator();

Uint8List _png({int w = 100, int h = 100}) {
  final b = Uint8List(33);
  b.setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // signature
  b.setAll(8,  [0x00, 0x00, 0x00, 0x0D]);                          // IHDR length
  b.setAll(12, [0x49, 0x48, 0x44, 0x52]);                          // IHDR type
  b[16] = (w >> 24) & 0xFF; b[17] = (w >> 16) & 0xFF;
  b[18] = (w >>  8) & 0xFF; b[19] =  w        & 0xFF;
  b[20] = (h >> 24) & 0xFF; b[21] = (h >> 16) & 0xFF;
  b[22] = (h >>  8) & 0xFF; b[23] =  h        & 0xFF;
  return b;
}

Uint8List _jpeg() => Uint8List.fromList(
    [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, ...List.filled(20, 0)]);

Uint8List _pdf([String extra = '']) =>
    Uint8List.fromList(utf8.encode('%PDF-1.4\n%Test PDF.\n%%EOF\n$extra'));

Uint8List _zip({bool withVba = false, bool withTraversal = false,
    int entries = 3}) {
  final buf = BytesBuilder();
  for (int i = 0; i < entries; i++) {
    buf.add([0x50, 0x4B, 0x03, 0x04]);
    buf.add(List.filled(26, 0));
  }
  if (withVba)        buf.add(utf8.encode('vbaProject.bin'));
  if (withTraversal)  buf.add(utf8.encode('../evil.xml'));
  return buf.toBytes();
}

Uint8List _svg({bool withScript = false, bool withDoctype = false,
    bool withEventHandler = false, bool withJsUri = false}) {
  if (withDoctype) {
    return Uint8List.fromList(
        utf8.encode('<!DOCTYPE svg [<!ENTITY x "y">]><svg></svg>'));
  }
  final parts = ['<svg xmlns="http://www.w3.org/2000/svg">'];
  if (withScript)       parts.add('<script>alert(1)</script>');
  if (withEventHandler) parts.add('<rect onload="evil()"/>');
  if (withJsUri)        parts.add('<a href="javascript:evil()">x</a>');
  parts.add('</svg>');
  return Uint8List.fromList(utf8.encode(parts.join()));
}

Uint8List _csv(String content) => Uint8List.fromList(utf8.encode(content));
Uint8List _txt(String content)  => Uint8List.fromList(utf8.encode(content));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── PNG ───────────────────────────────────────────────────────────────────

  group('PNG', () {
    test('valid PNG accepted', () {
      final r = _v.validate(_png(), 'photo.png');
      expect(r.kind, AttachmentKind.png);
    });

    test('PNG > 50 megapixels rejected', () {
      expect(() => _v.validate(_png(w: 10000, h: 5001), 'big.png'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PNG absurd aspect ratio (200:1) rejected', () {
      expect(() => _v.validate(_png(w: 10000, h: 50), 'wide.png'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PNG bytes with .jpg extension rejected (triple-agreement)', () {
      expect(() => _v.validate(_png(), 'photo.jpg'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── JPEG ──────────────────────────────────────────────────────────────────

  group('JPEG', () {
    test('valid JPEG accepted', () {
      final r = _v.validate(_jpeg(), 'photo.jpg');
      expect(r.kind, AttachmentKind.jpeg);
    });

    test('JPEG bytes with .png extension rejected', () {
      expect(() => _v.validate(_jpeg(), 'photo.png'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── SVG ───────────────────────────────────────────────────────────────────

  group('SVG', () {
    test('valid SVG accepted', () {
      final r = _v.validate(_svg(), 'image.svg');
      expect(r.kind, AttachmentKind.svg);
    });

    test('SVG with DOCTYPE rejected', () {
      expect(() => _v.validate(_svg(withDoctype: true), 'image.svg'),
          throwsA(isA<ValidationFailure>()));
    });

    test('SVG with <script> rejected', () {
      expect(() => _v.validate(_svg(withScript: true), 'image.svg'),
          throwsA(isA<ValidationFailure>()));
    });

    test('SVG with event handler (onload) rejected', () {
      expect(() => _v.validate(_svg(withEventHandler: true), 'image.svg'),
          throwsA(isA<ValidationFailure>()));
    });

    test('SVG with javascript: URI rejected', () {
      expect(() => _v.validate(_svg(withJsUri: true), 'image.svg'),
          throwsA(isA<ValidationFailure>()));
    });

    test('SVG sanitised output contains no <script> (validation-level check)', () {
      // Validator throws — no sanitised output reaches the app.
      expect(() => _v.validate(_svg(withScript: true), 'image.svg'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── PDF ───────────────────────────────────────────────────────────────────

  group('PDF', () {
    test('valid PDF accepted', () {
      final r = _v.validate(_pdf(), 'doc.pdf');
      expect(r.kind, AttachmentKind.pdf);
    });

    test('PDF with /JavaScript rejected', () {
      expect(() => _v.validate(_pdf('/JavaScript << >>'), 'doc.pdf'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PDF with /Launch rejected', () {
      expect(() => _v.validate(_pdf('/Launch << >>'), 'doc.pdf'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PDF with /OpenAction rejected', () {
      expect(() => _v.validate(_pdf('/OpenAction << >>'), 'doc.pdf'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PDF with /EmbeddedFile rejected', () {
      expect(() => _v.validate(_pdf('/EmbeddedFile'), 'doc.pdf'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PDF with /AA rejected', () {
      expect(() => _v.validate(_pdf('/AA << >>'), 'doc.pdf'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PDF missing %%EOF rejected', () {
      final bytes = Uint8List.fromList(utf8.encode('%PDF-1.4\nno eof'));
      expect(() => _v.validate(bytes, 'doc.pdf'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── DOCX / PPTX ──────────────────────────────────────────────────────────

  group('DOCX / PPTX', () {
    test('valid DOCX accepted', () {
      final r = _v.validate(_zip(), 'doc.docx');
      expect(r.kind, AttachmentKind.docx);
    });

    test('valid PPTX accepted', () {
      final r = _v.validate(_zip(), 'slides.pptx');
      expect(r.kind, AttachmentKind.pptx);
    });

    test('DOCX with vbaProject.bin rejected', () {
      expect(() => _v.validate(_zip(withVba: true), 'macro.docx'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PPTX with path traversal entry rejected', () {
      expect(() => _v.validate(_zip(withTraversal: true), 'slides.pptx'),
          throwsA(isA<ValidationFailure>()));
    });

    test('ZIP bomb (> 5000 entries) rejected', () {
      final buf = BytesBuilder();
      for (int i = 0; i < 5001; i++) {
        buf.add([0x50, 0x4B, 0x03, 0x04]);
        buf.add(List.filled(4, 0));
      }
      expect(() => _v.validate(buf.toBytes(), 'bomb.docx'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── CSV ───────────────────────────────────────────────────────────────────

  group('CSV', () {
    test('valid CSV accepted', () {
      final r = _v.validate(_csv('name,age\nAlice,30'), 'data.csv');
      expect(r.kind, AttachmentKind.csv);
    });

    test('empty CSV rejected', () {
      expect(() => _v.validate(_csv(''), 'empty.csv'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── TXT ───────────────────────────────────────────────────────────────────

  group('TXT', () {
    test('valid TXT accepted', () {
      final r = _v.validate(_txt('Hello world.'), 'note.txt');
      expect(r.kind, AttachmentKind.txt);
    });

    test('binary blob with .txt extension rejected', () {
      // 200 bytes: 20 null bytes followed by incrementing values = 10% nulls
      final binary = Uint8List.fromList(
          [...List.filled(20, 0x00), ...List.generate(180, (i) => i + 1)]);
      expect(() => _v.validate(binary, 'fake.txt'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── Size cap ──────────────────────────────────────────────────────────────

  group('Size cap', () {
    test('SVG over 1 MB rejected', () {
      final oversized = Uint8List(1 * 1024 * 1024 + 1);
      oversized.setAll(0, utf8.encode('<svg xmlns="http://www.w3.org/2000/svg">'));
      expect(() => _v.validate(oversized, 'big.svg'),
          throwsA(isA<ValidationFailure>()));
    });

    test('TXT at exactly 0 bytes rejected (empty)', () {
      expect(() => _v.validate(Uint8List(0), 'empty.txt'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── Filename sanitisation ─────────────────────────────────────────────────

  group('Filename sanitisation', () {
    test('Path separators stripped', () {
      final r = _v.validate(_png(), '../../../photo.png');
      expect(r.originalFilename.contains('/'), isFalse);
      expect(r.originalFilename.contains('..'), isFalse);
    });

    test('Control characters removed', () {
      final r = _v.validate(_png(), 'file\x00name.png');
      expect(r.originalFilename.contains('\x00'), isFalse);
    });

    test('Double extension collapsed', () {
      final r = _v.validate(_png(), 'shell.php.png');
      expect(r.originalFilename, 'shell.png');
    });

    test('Unsupported extension rejected', () {
      expect(() => _v.validate(_png(), 'virus.exe'),
          throwsA(isA<ValidationFailure>()));
    });

    test('No extension rejected', () {
      expect(() => _v.validate(_png(), 'noextension'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ── SHA-256 ───────────────────────────────────────────────────────────────

  group('SHA-256', () {
    test('SHA-256 is 64 lowercase hex chars', () {
      final r = _v.validate(_pdf(), 'doc.pdf');
      expect(r.sha256, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(r.sha256), isTrue);
    });

    test('Same bytes → same SHA-256', () {
      final bytes = _pdf();
      expect(_v.validate(bytes, 'a.pdf').sha256,
          _v.validate(bytes, 'a.pdf').sha256);
    });

    test('Different bytes → different SHA-256', () {
      expect(_v.validate(_pdf('A'), 'a.pdf').sha256,
          isNot(_v.validate(_pdf('B'), 'b.pdf').sha256));
    });
  });

  // ── Magic / extension mismatch ────────────────────────────────────────────

  group('Triple-agreement', () {
    test('JPEG bytes with .pdf extension rejected', () {
      expect(() => _v.validate(_jpeg(), 'photo.pdf'),
          throwsA(isA<ValidationFailure>()));
    });

    test('PDF bytes with .docx extension rejected', () {
      expect(() => _v.validate(_pdf(), 'doc.docx'),
          throwsA(isA<ValidationFailure>()));
    });

    test('ZIP bytes with .pdf extension rejected', () {
      expect(() => _v.validate(_zip(), 'doc.pdf'),
          throwsA(isA<ValidationFailure>()));
    });
  });
}
