// lib/features/notes/editor/tag_autocomplete.dart
// Tag autocomplete overlay: shown when the user types '#' in the editor.
// Queries existing tags and inserts the selected one inline.

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_editor/super_editor.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';

/// Stateless widget that wraps the editor and adds tag autocomplete.
/// Call [TagAutocompleteController.onDocumentChanged] whenever the
/// document changes to trigger detection.
class TagAutocompleteController {
  TagAutocompleteController({
    required this.editor,
    required this.composer,
    required this.document,
    required this.overlayKey,
  });

  final Editor editor;
  final MutableDocumentComposer composer;
  final MutableDocument document;
  final GlobalKey overlayKey;

  OverlayEntry? _overlay;

  /// Call when document content changes. Returns true if autocomplete opened.
  bool onDocumentChanged(BuildContext context, WidgetRef ref) {
    final selection = composer.selection;
    if (selection == null) {
      _dismiss();
      return false;
    }
    final nodeId = selection.extent.nodeId;
    final node = document.getNodeById(nodeId);
    if (node is! TextNode) {
      _dismiss();
      return false;
    }
    final offset = (selection.extent.nodePosition as TextNodePosition).offset;
    final text = node.text.toPlainText();

    // Scan backwards from cursor to find '#' trigger.
    final tagQuery = _extractTagQuery(text, offset);
    if (tagQuery == null) {
      _dismiss();
      return false;
    }

    _show(context, ref, nodeId, tagQuery, offset);
    return true;
  }

  /// Extract the partial tag after the last '#' before the cursor.
  /// Returns null if no '#' found or there's a space between '#' and cursor.
  String? _extractTagQuery(String text, int cursor) {
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
    // Partial text between '#' and cursor (may be empty = just typed '#')
    return text.substring(hashPos + 1, cursor);
  }

  void _show(
    BuildContext context,
    WidgetRef ref,
    String nodeId,
    String query,
    int cursorOffset,
  ) {
    _dismiss(); // Remove any existing overlay first.
    _overlay = OverlayEntry(
      builder: (_) => _TagAutocompleteOverlay(
        query: query,
        ref: ref,
        onSelect: (tag) => _insertTag(nodeId, tag, cursorOffset, query),
        onDismiss: _dismiss,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _insertTag(String nodeId, String tag, int cursorOffset, String query) {
    _dismiss();
    // Replace the partial '#query' with '#tag'.
    final hashPos = cursorOffset - query.length - 1; // -1 for '#'
    final replaceStart = hashPos < 0 ? 0 : hashPos;
    editor.execute([
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: replaceStart),
          ),
          end: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: cursorOffset),
          ),
        ),
      ),
      InsertTextRequest(
        documentPosition: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: replaceStart),
        ),
        textToInsert: '#$tag ',
        attributions: {},
      ),
    ]);
  }

  void _dismiss() {
    _overlay?.remove();
    _overlay = null;
  }

  void dispose() => _dismiss();
}

// ── Overlay widget ─────────────────────────────────────────────────────────

class _TagAutocompleteOverlay extends ConsumerWidget {
  const _TagAutocompleteOverlay({
    required this.query,
    required this.ref,
    required this.onSelect,
    required this.onDismiss,
  });

  final String query;
  final WidgetRef ref;
  final void Function(String tag) onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final colors = context.colors;

    final allTags = tagsAsync.value ?? [];
    final filtered = allTags
        .where((t) => t.toLowerCase().startsWith(query.toLowerCase()))
        .take(8)
        .toList();

    if (filtered.isEmpty && query.isEmpty) {
      // Show all tags when query is empty (just typed '#')
    } else if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayTags = filtered.isEmpty ? allTags.take(8).toList() : filtered;

    return Stack(
      children: [
        GestureDetector(onTap: onDismiss, child: const SizedBox.expand()),
        Positioned(
          bottom: 100,
          left: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            color: colors.surface,
            child: Container(
              width: 200,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: displayTags.length,
                itemBuilder: (_, i) {
                  final tag = displayTags[i];
                  return InkWell(
                    onTap: () => onSelect(tag),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(AppIcons.tagIcon, size: 14, color: colors.brand),
                          const SizedBox(width: 6),
                          Text(
                            tag,
                            style: TextStyle(fontSize: 14, color: colors.text),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
