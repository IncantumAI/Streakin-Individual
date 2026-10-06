// lib/features/notes/domain/note_document.dart
// NoteDocument — abstraction over the editor's block format.
//
// This is the seam that makes the editor replaceable. All persistence,
// FTS indexing, link extraction, and tag extraction go through this class.
// Nothing outside notes/domain/ may depend on super_editor types directly.
//
// Storage format: a JSON string (the `body` column of the `notes` table).
// In-memory: a list of NoteBlock records.

import 'dart:convert';

// ── Block kind ────────────────────────────────────────────────────────────────

enum NoteBlockKind {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletItem,
  orderedItem,
  task,
  blockquote,
  divider,
  codeBlock,
  table,
  image,
  wikiLink,   // inline — stored as a block for serialisation purposes
}

extension NoteBlockKindExt on NoteBlockKind {
  String get key => name;
  static NoteBlockKind fromKey(String k) =>
      NoteBlockKind.values.firstWhere((v) => v.name == k,
          orElse: () => NoteBlockKind.paragraph);
}

// ── Block model ───────────────────────────────────────────────────────────────

/// A single content block in a note.
class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.kind,
    this.text = '',
    this.isComplete = false,
    this.level = 1,
    this.attrs = const {},
  });

  final String id;
  final NoteBlockKind kind;
  /// Plain text content (for headings, paragraphs, list items, tasks, etc.).
  final String text;
  /// For task blocks — whether the checkbox is checked.
  final bool isComplete;
  /// For heading blocks — 1, 2 or 3.
  final int level;
  /// Arbitrary extra attributes (e.g. table data, wiki-link target ID).
  final Map<String, dynamic> attrs;

  NoteBlock copyWith({
    String? id,
    NoteBlockKind? kind,
    String? text,
    bool? isComplete,
    int? level,
    Map<String, dynamic>? attrs,
  }) =>
      NoteBlock(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        text: text ?? this.text,
        isComplete: isComplete ?? this.isComplete,
        level: level ?? this.level,
        attrs: attrs ?? this.attrs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.key,
        'text': text,
        if (isComplete) 'isComplete': isComplete,
        if (level != 1) 'level': level,
        if (attrs.isNotEmpty) 'attrs': attrs,
      };

  factory NoteBlock.fromJson(Map<String, dynamic> j) => NoteBlock(
        id: j['id'] as String,
        kind: NoteBlockKindExt.fromKey(j['kind'] as String? ?? 'paragraph'),
        text: j['text'] as String? ?? '',
        isComplete: j['isComplete'] as bool? ?? false,
        level: j['level'] as int? ?? 1,
        attrs: (j['attrs'] as Map<String, dynamic>?) ?? {},
      );
}

// ── NoteDocument ──────────────────────────────────────────────────────────────

class NoteDocument {
  NoteDocument(this.blocks);

  final List<NoteBlock> blocks;

  /// Deserialise from the `body` JSON string stored in the DB.
  factory NoteDocument.fromJson(String json) {
    if (json.isEmpty || json == '{}') return NoteDocument([]);
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return NoteDocument(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(NoteBlock.fromJson)
              .toList(),
        );
      }
      // Legacy: if the top-level is a map with a 'blocks' key.
      if (decoded is Map<String, dynamic> && decoded['blocks'] is List) {
        return NoteDocument(
          (decoded['blocks'] as List)
              .whereType<Map<String, dynamic>>()
              .map(NoteBlock.fromJson)
              .toList(),
        );
      }
    } catch (_) {}
    return NoteDocument([]);
  }

  /// Serialise to JSON string for DB storage.
  String toJson() => jsonEncode(blocks.map((b) => b.toJson()).toList());

  /// Plain-text representation for FTS indexing.
  /// Omits dividers and image blocks; extracts text from all other blocks.
  String toPlainText() {
    final buf = StringBuffer();
    for (final b in blocks) {
      if (b.kind == NoteBlockKind.divider || b.kind == NoteBlockKind.image) {
        continue;
      }
      if (b.text.isNotEmpty) {
        buf.writeln(b.text);
      }
    }
    return buf.toString().trim();
  }

  /// Extract all `[[target title]]` wiki-link targets (block id + target title).
  /// Returns list of (blockId, targetTitle) tuples.
  List<({String blockId, String targetTitle})> extractLinks() {
    final results = <({String blockId, String targetTitle})>[];
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    for (final block in blocks) {
      for (final match in pattern.allMatches(block.text)) {
        final target = match.group(1)?.trim() ?? '';
        if (target.isNotEmpty) {
          results.add((blockId: block.id, targetTitle: target));
        }
      }
      // Wiki-link blocks also carry a dstNoteId in attrs.
      if (block.kind == NoteBlockKind.wikiLink) {
        final dstId = block.attrs['dstNoteId'] as String?;
        if (dstId != null && dstId.isNotEmpty) {
          results.add((blockId: block.id, targetTitle: dstId));
        }
      }
    }
    return results;
  }

  /// Extract `#tag` patterns from all text blocks.
  Set<String> extractTags() {
    final tags = <String>{};
    final pattern = RegExp(r'#([A-Za-z0-9_\-]+)');
    for (final block in blocks) {
      for (final match in pattern.allMatches(block.text)) {
        final tag = match.group(1);
        if (tag != null && tag.isNotEmpty) tags.add(tag.toLowerCase());
      }
    }
    return tags;
  }

  /// Extract `@date` mentions. Returns ISO-8601 date strings found in text.
  /// Pattern: @YYYY-MM-DD
  List<({String blockId, String isoDate})> extractDateMentions() {
    final results = <({String blockId, String isoDate})>[];
    final pattern = RegExp(r'@(\d{4}-\d{2}-\d{2})');
    for (final block in blocks) {
      for (final match in pattern.allMatches(block.text)) {
        final date = match.group(1);
        if (date != null) results.add((blockId: block.id, isoDate: date));
      }
    }
    return results;
  }

  bool get isEmpty => blocks.isEmpty;
}
