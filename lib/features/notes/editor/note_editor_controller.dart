// lib/features/notes/editor/note_editor_controller.dart
// Bridge between super_editor's in-memory document model and NoteDocument
// (our storage abstraction). This is the ONLY file that imports super_editor
// types inside the notes feature — everything else uses NoteDocument/NoteBlock.

import 'package:super_editor/super_editor.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/features/notes/domain/note_document.dart'
    as domain;

const _uuid = Uuid();

// ── super_editor → NoteDocument ──────────────────────────────────────────────

/// Convert a super_editor [MutableDocument] to our [domain.NoteDocument].
domain.NoteDocument superEditorToNoteDocument(MutableDocument doc) {
  final blocks = <domain.NoteBlock>[];
  for (final node in doc) {
    final block = _nodeToBlock(node);
    if (block != null) blocks.add(block);
  }
  return domain.NoteDocument(blocks);
}

domain.NoteBlock? _nodeToBlock(DocumentNode node) {
  if (node is ParagraphNode) {
    final blockType =
        node.getMetadataValue('blockType') as Attribution? ??
            paragraphAttribution;
    final kind = _attributionToKind(blockType);
    return domain.NoteBlock(
      id: node.id,
      kind: kind,
      text: node.text.text,
    );
  }
  if (node is ListItemNode) {
    return domain.NoteBlock(
      id: node.id,
      kind: node.type == ListItemType.ordered
          ? domain.NoteBlockKind.orderedItem
          : domain.NoteBlockKind.bulletItem,
      text: node.text.text,
    );
  }
  if (node is TaskNode) {
    return domain.NoteBlock(
      id: node.id,
      kind: domain.NoteBlockKind.task,
      text: node.text.text,
      isComplete: node.isComplete,
    );
  }
  if (node is HorizontalRuleNode) {
    return domain.NoteBlock(
      id: node.id,
      kind: domain.NoteBlockKind.divider,
    );
  }
  // Unknown node types — preserve as paragraph with text if possible.
  if (node is TextNode) {
    return domain.NoteBlock(
      id: node.id,
      kind: domain.NoteBlockKind.paragraph,
      text: node.text.text,
    );
  }
  return null;
}

domain.NoteBlockKind _attributionToKind(Attribution attr) {
  if (attr == header1Attribution) return domain.NoteBlockKind.heading1;
  if (attr == header2Attribution) return domain.NoteBlockKind.heading2;
  if (attr == header3Attribution) return domain.NoteBlockKind.heading3;
  if (attr == blockquoteAttribution) return domain.NoteBlockKind.blockquote;
  return domain.NoteBlockKind.paragraph;
}

// ── NoteDocument → super_editor ──────────────────────────────────────────────

/// Convert our [domain.NoteDocument] to a [MutableDocument] for super_editor.
MutableDocument noteDocumentToSuperEditor(domain.NoteDocument doc) {
  if (doc.isEmpty) {
    return MutableDocument(nodes: [
      ParagraphNode(id: _uuid.v4(), text: AttributedText('')),
    ]);
  }

  final nodes = <DocumentNode>[];
  for (final block in doc.blocks) {
    final node = _blockToNode(block);
    if (node != null) nodes.add(node);
  }

  // super_editor requires at least one node.
  if (nodes.isEmpty) {
    nodes.add(ParagraphNode(id: _uuid.v4(), text: AttributedText('')));
  }

  return MutableDocument(nodes: nodes);
}

DocumentNode? _blockToNode(domain.NoteBlock block) {
  switch (block.kind) {
    case domain.NoteBlockKind.heading1:
      return ParagraphNode(
        id: block.id,
        text: AttributedText(block.text),
        metadata: {'blockType': header1Attribution},
      );
    case domain.NoteBlockKind.heading2:
      return ParagraphNode(
        id: block.id,
        text: AttributedText(block.text),
        metadata: {'blockType': header2Attribution},
      );
    case domain.NoteBlockKind.heading3:
      return ParagraphNode(
        id: block.id,
        text: AttributedText(block.text),
        metadata: {'blockType': header3Attribution},
      );
    case domain.NoteBlockKind.blockquote:
      return ParagraphNode(
        id: block.id,
        text: AttributedText(block.text),
        metadata: {'blockType': blockquoteAttribution},
      );
    case domain.NoteBlockKind.bulletItem:
      return ListItemNode.unordered(
        id: block.id,
        text: AttributedText(block.text),
      );
    case domain.NoteBlockKind.orderedItem:
      return ListItemNode.ordered(
        id: block.id,
        text: AttributedText(block.text),
      );
    case domain.NoteBlockKind.task:
      return TaskNode(
        id: block.id,
        text: AttributedText(block.text),
        isComplete: block.isComplete,
      );
    case domain.NoteBlockKind.divider:
      return HorizontalRuleNode(id: block.id);
    case domain.NoteBlockKind.paragraph:
    case domain.NoteBlockKind.codeBlock:
    case domain.NoteBlockKind.wikiLink:
    case domain.NoteBlockKind.table:
    case domain.NoteBlockKind.image:
      // code/table/image/wikilink fall back to paragraph for now (Phase 3C custom nodes TBD)
      return ParagraphNode(
        id: block.id,
        text: AttributedText(block.text),
      );
  }
}

// ── NoteEditorController ──────────────────────────────────────────────────────

/// Holds the super_editor state for a single note and exposes
/// [onDocumentChanged] for autosave/backlink extraction.
class NoteEditorController {
  NoteEditorController({required domain.NoteDocument initialDocument}) {
    _doc = noteDocumentToSuperEditor(initialDocument);
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _doc,
        Editor.composerKey: _composer,
      },
      requestHandlers: List.from(defaultRequestHandlers),
      reactionPipeline: List.from(defaultEditorReactions),
    );
    _doc.addListener((_) => _notifyChange());
  }

  late final MutableDocument _doc;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  // Listeners called when the document content changes.
  final List<VoidCallback> _changeListeners = [];

  MutableDocument get document => _doc;
  MutableDocumentComposer get composer => _composer;
  Editor get editor => _editor;

  void addChangeListener(VoidCallback fn) => _changeListeners.add(fn);
  void removeChangeListener(VoidCallback fn) => _changeListeners.remove(fn);

  void _notifyChange() {
    for (final fn in List.of(_changeListeners)) {
      fn();
    }
  }

  /// Extract current content as a [domain.NoteDocument].
  domain.NoteDocument toDomain() => superEditorToNoteDocument(_doc);

  void dispose() {
    _editor.dispose();
  }
}
