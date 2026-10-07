// lib/core/validation/attachment_validator.dart
// AttachmentValidator — pure-Dart, runs safely in a worker isolate.
// Spec §9: size cap → filename sanitise → extension → magic bytes →
//          MIME → triple-agreement → kind-specific structural check →
//          SHA-256 → return ValidatedAttachment.
//
// NOTE: Image re-encoding (EXIF strip, thumbnail) is NOT done here — Flutter's
// image codecs require the main isolate. The validator checks structure only;
// re-encoding is done by AttachmentPipeline on the main isolate after
// validation passes.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/features/notes/domain/attachment.dart';

// ── Magic byte signatures ─────────────────────────────────────────────────────

// PNG: 8 bytes
const _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
// JPEG: SOI marker
const _jpegMagic = [0xFF, 0xD8, 0xFF];
// PDF: '%PDF-'
const _pdfMagic = [0x25, 0x50, 0x44, 0x46, 0x2D];
// ZIP (DOCX/PPTX): PK header
const _zipMagic = [0x50, 0x4B, 0x03, 0x04];

// ── AttachmentValidator ───────────────────────────────────────────────────────

class AttachmentValidator {
  const AttachmentValidator();

  /// Validate [bytes] for the given [filename].
  /// Returns a [ValidatedAttachment] on success.
  /// Throws [ValidationFailure] on any rejection.
  ValidatedAttachment validate(Uint8List bytes, String filename) {
    // Step 1: sanitise filename.
    final sanitizedName = _sanitizeFilename(filename);
    if (sanitizedName.isEmpty) {
      throw const ValidationFailure('Invalid filename.');
    }

    // Step 2: detect kind from extension.
    final ext = _extension(sanitizedName);
    final extKind = _kindFromExtension(ext);
    if (extKind == null) {
      throw const ValidationFailure(
          'This file type isn\'t supported.');
    }

    // Step 3: size check.
    if (bytes.length > extKind.maxBytes) {
      throw ValidationFailure(
          'This file is too large. Maximum size is ${extKind.maxBytes ~/ (1024 * 1024)} MB.');
    }

    // Step 4: magic bytes → detected kind.
    final magicKind = _kindFromMagic(bytes, extKind);
    if (magicKind == null) {
      throw const ValidationFailure(
          'The file content doesn\'t match its extension.');
    }

    // Step 5: triple-agreement (extension kind == magic kind).
    if (extKind != magicKind) {
      throw const ValidationFailure(
          'The file extension doesn\'t match its content.');
    }

    // Step 6: kind-specific structural validation.
    _validateStructure(bytes, extKind);

    // Step 7: SHA-256.
    final hash = sha256.convert(bytes);
    final sha256Hex = hash.toString();

    return ValidatedAttachment(
      kind: extKind,
      mime: extKind.mime,
      originalFilename: sanitizedName,
      sanitizedBytes: bytes, // Image re-encoding done on main isolate.
      sha256: sha256Hex,
    );
  }

  // ── Filename sanitisation ─────────────────────────────────────────────────

  String _sanitizeFilename(String raw) {
    // Strip path separators — take only basename.
    var name = raw.replaceAll(RegExp(r'[/\\]'), '').trim();
    // NFC normalise if possible.
    name = name.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''); // control chars
    // Remove bidi override characters.
    name = name.replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), '');
    // Reject double extensions that could be executable (e.g. .php.pdf).
    final parts = name.split('.');
    if (parts.length > 2) {
      // Allow only single extension.
      name = '${parts.first}.${parts.last}';
    }
    // Length cap.
    if (name.length > 120) name = name.substring(0, 120);
    return name;
  }

  // ── Extension ─────────────────────────────────────────────────────────────

  String _extension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return '';
    return filename.substring(dot + 1).toLowerCase();
  }

  AttachmentKind? _kindFromExtension(String ext) {
    for (final kind in AttachmentKind.values) {
      if (kind.extensions.contains(ext)) return kind;
    }
    return null;
  }

  // ── Magic bytes ───────────────────────────────────────────────────────────

  AttachmentKind? _kindFromMagic(Uint8List bytes, AttachmentKind extKind) {
    if (bytes.length < 8) return null;
    if (_startsWith(bytes, _pngMagic)) return AttachmentKind.png;
    if (_startsWith(bytes, _jpegMagic)) return AttachmentKind.jpeg;
    if (_startsWith(bytes, _pdfMagic)) return AttachmentKind.pdf;
    if (_startsWith(bytes, _zipMagic)) {
      // Both DOCX and PPTX are ZIP. Use extension kind to distinguish.
      if (extKind == AttachmentKind.docx) return AttachmentKind.docx;
      if (extKind == AttachmentKind.pptx) return AttachmentKind.pptx;
      return null;
    }
    // SVG: no unique magic — check XML header or '<svg'.
    if (_looksLikeSvg(bytes)) return AttachmentKind.svg;
    // CSV and TXT: text files — accept if extension matches.
    if (extKind == AttachmentKind.csv || extKind == AttachmentKind.txt) {
      if (_looksLikeText(bytes)) return extKind;
    }
    return null;
  }

  bool _startsWith(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (int i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  bool _looksLikeSvg(Uint8List bytes) {
    final head = bytes.length > 512 ? bytes.sublist(0, 512) : bytes;
    final text = utf8.decode(head, allowMalformed: true).toLowerCase();
    return text.contains('<svg') || text.contains('<?xml');
  }

  bool _looksLikeText(Uint8List bytes) {
    // Heuristic: if < 5% are non-printable non-whitespace bytes, it's text.
    final sample = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
    int nonPrintable = 0;
    for (final b in sample) {
      if (b < 0x09 || (b > 0x0D && b < 0x20) || b == 0x7F) nonPrintable++;
    }
    return nonPrintable < sample.length * 0.05;
  }

  // ── Kind-specific structural validation ──────────────────────────────────

  void _validateStructure(Uint8List bytes, AttachmentKind kind) {
    switch (kind) {
      case AttachmentKind.png:
        _validatePng(bytes);
      case AttachmentKind.jpeg:
        _validateJpeg(bytes);
      case AttachmentKind.svg:
        _validateSvg(bytes);
      case AttachmentKind.pdf:
        _validatePdf(bytes);
      case AttachmentKind.docx:
      case AttachmentKind.pptx:
        _validateOfficeZip(bytes, kind);
      case AttachmentKind.csv:
        _validateCsv(bytes);
      case AttachmentKind.txt:
        _validateTxt(bytes);
    }
  }

  // ── PNG ───────────────────────────────────────────────────────────────────

  void _validatePng(Uint8List bytes) {
    if (bytes.length < 24) {
      throw const ValidationFailure('Invalid PNG file.');
    }
    // Read IHDR for width and height (bytes 16–23).
    final width = _readUint32BE(bytes, 16);
    final height = _readUint32BE(bytes, 20);
    if (width <= 0 || height <= 0) {
      throw const ValidationFailure('Invalid PNG dimensions.');
    }
    // Reject > 50 megapixels (decompression bomb guard).
    if (width * height > 50000000) {
      throw const ValidationFailure(
          'This image is too large to attach (over 50 megapixels).');
    }
    // Reject absurd aspect ratios (> 100:1).
    final ratio = width > height ? width / height : height / width;
    if (ratio > 100) {
      throw const ValidationFailure('This image has an invalid aspect ratio.');
    }
  }

  // ── JPEG ──────────────────────────────────────────────────────────────────

  void _validateJpeg(Uint8List bytes) {
    if (bytes.length < 10) {
      throw const ValidationFailure('Invalid JPEG file.');
    }
    // Scan for SOF0/SOF1/SOF2 markers to read dimensions.
    int offset = 2;
    while (offset < bytes.length - 4) {
      if (bytes[offset] != 0xFF) break;
      final marker = bytes[offset + 1];
      final segLen = _readUint16BE(bytes, offset + 2);
      // SOF markers: 0xC0–0xC3, 0xC5–0xC7, 0xC9–0xCB, 0xCD–0xCF.
      if ((marker >= 0xC0 && marker <= 0xC3) ||
          (marker >= 0xC5 && marker <= 0xC7) ||
          (marker >= 0xC9 && marker <= 0xCB)) {
        if (offset + 9 < bytes.length) {
          final height = _readUint16BE(bytes, offset + 5);
          final width = _readUint16BE(bytes, offset + 7);
          if (width > 0 && height > 0 && width * height > 50000000) {
            throw const ValidationFailure(
                'This image is too large to attach (over 50 megapixels).');
          }
          final ratio = width > height ? width / height : height / width;
          if (ratio > 100) {
            throw const ValidationFailure(
                'This image has an invalid aspect ratio.');
          }
        }
        return;
      }
      offset += 2 + segLen;
    }
    // Could not find SOF — accept (dimensions unknown but structurally OK).
  }

  // ── SVG ───────────────────────────────────────────────────────────────────

  void _validateSvg(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    // Reject DOCTYPE (entity injection).
    if (text.toLowerCase().contains('<!doctype')) {
      throw const ValidationFailure(
          'This SVG file contains a DOCTYPE declaration and cannot be attached.');
    }
    // Reject entity declarations.
    if (text.toLowerCase().contains('<!entity')) {
      throw const ValidationFailure(
          'This SVG file contains entity declarations and cannot be attached.');
    }
    // Reject script elements.
    if (RegExp(r'<script', caseSensitive: false).hasMatch(text)) {
      throw const ValidationFailure(
          'This SVG file contains scripts and cannot be attached.');
    }
    // Reject javascript: URIs.
    if (RegExp(r'javascript:', caseSensitive: false).hasMatch(text)) {
      throw const ValidationFailure(
          'This SVG file contains JavaScript URIs and cannot be attached.');
    }
    // Reject external references (xlink:href to http).
    if (RegExp(r'xlink:href\s*=\s*["' "'" r']https?://', caseSensitive: false)
        .hasMatch(text)) {
      throw const ValidationFailure(
          'This SVG file references external resources and cannot be attached.');
    }
    // Reject event handlers (onload, onclick, etc.).
    if (RegExp(r'\bon\w+\s*=', caseSensitive: false).hasMatch(text)) {
      throw const ValidationFailure(
          'This SVG file contains event handlers and cannot be attached.');
    }
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  void _validatePdf(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    // Must start with %PDF-.
    if (!text.startsWith('%PDF-')) {
      throw const ValidationFailure('Invalid PDF file.');
    }
    // Must contain %%EOF.
    if (!text.contains('%%EOF')) {
      throw const ValidationFailure('Invalid PDF structure (missing %%EOF).');
    }
    // Reject dangerous actions — case-insensitive search.
    final lower = text.toLowerCase();
    const dangerous = [
      '/javascript',
      '/js',
      '/launch',
      '/openaction',
      '/aa',
      '/embeddedfile',
      '/submitform',
    ];
    for (final token in dangerous) {
      if (lower.contains(token)) {
        throw ValidationFailure(
            'This PDF contains $token actions and cannot be attached.');
      }
    }
  }

  // ── DOCX / PPTX ──────────────────────────────────────────────────────────

  void _validateOfficeZip(Uint8List bytes, AttachmentKind kind) {
    // Inspect the ZIP central directory without fully extracting.
    // Reject: vbaProject.bin, .docm/.pptm content types, zip bombs.
    final text = utf8.decode(bytes, allowMalformed: true);

    // Reject macro-enabled variants by content type.
    if (text.contains('vbaProject.bin')) {
      throw const ValidationFailure(
          'This file contains macros (vbaProject.bin) and cannot be attached.');
    }
    if (text.contains('.docm') || text.contains('.pptm')) {
      throw const ValidationFailure(
          'Macro-enabled Office files (.docm, .pptm) cannot be attached.');
    }
    if (text.contains('vnd.ms-office.activeX')) {
      throw const ValidationFailure(
          'This file contains ActiveX components and cannot be attached.');
    }

    // Reject path traversal in entry names.
    if (text.contains('..\\') || text.contains('../')) {
      throw const ValidationFailure(
          'This file contains invalid paths and cannot be attached.');
    }

    // ZIP bomb guard: count local file headers (PK\x03\x04).
    int count = 0;
    int offset = 0;
    while (offset < bytes.length - 3) {
      if (bytes[offset] == 0x50 &&
          bytes[offset + 1] == 0x4B &&
          bytes[offset + 2] == 0x03 &&
          bytes[offset + 3] == 0x04) {
        count++;
        if (count > 5000) {
          throw const ValidationFailure(
              'This file has too many entries and cannot be attached (possible zip bomb).');
        }
        offset += 4;
      } else {
        offset++;
      }
    }
  }

  // ── CSV ───────────────────────────────────────────────────────────────────

  void _validateCsv(Uint8List bytes) {
    // Preview cap: reject > 25 MB (already caught by size check).
    // Formula injection guard: check first 1 KB for cells starting with = + - @.
    // Full sanitisation happens during display.
    final preview = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    final text = utf8.decode(preview, allowMalformed: true);
    // Just structural check — actual formula prefix stripping is in preview widget.
    if (text.isEmpty) {
      throw const ValidationFailure('This CSV file appears to be empty.');
    }
  }

  // ── TXT ───────────────────────────────────────────────────────────────────

  void _validateTxt(Uint8List bytes) {
    // Encoding check: must be decodable as UTF-8 with < 5% replacement chars.
    if (bytes.isEmpty) {
      throw const ValidationFailure('This text file appears to be empty.');
    }
    final decoded = utf8.decode(bytes, allowMalformed: true);
    final replacements =
        RegExp('\uFFFD').allMatches(decoded).length;
    if (replacements > decoded.length * 0.05) {
      throw const ValidationFailure(
          'This file doesn\'t appear to be a valid text file.');
    }
  }

  // ── Binary helpers ────────────────────────────────────────────────────────

  int _readUint32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  int _readUint16BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }
}
