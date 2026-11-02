// lib/features/notes/editor/date_mention_picker.dart
// Spec §4.4.5: typing '@' opens an inline picker with natural-language
// suggestions. Choosing one inserts an inline date chip (`@YYYY-MM-DD` or
// `@YYYY-MM-DD HH:mm`) which the note layer turns into a `date_mentions` row.

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/domain/date_mention_parser.dart';

/// Marks the text of an inline date chip so it can be styled as a pill.
const dateChipAttribution = NamedAttribution('dateChip');

/// Matches a stored chip: `@2026-10-15` or `@2026-10-15 16:00`.
final dateChipPattern = RegExp(r'@(\d{4}-\d{2}-\d{2})(?: (\d{2}:\d{2}))?');

/// Formats a parsed mention into chip text.
String dateChipText(ParsedMention m) {
  String two(int v) => v.toString().padLeft(2, '0');
  final d = m.startsAt;
  final date = '${d.year}-${two(d.month)}-${two(d.day)}';
  return m.allDay ? '@$date' : '@$date ${two(d.hour)}:${two(d.minute)}';
}

/// Detects an `@query` before the cursor and drives the suggestion overlay.
class DateMentionPickerController {
  DateMentionPickerController({
    required this.editor,
    required this.composer,
    required this.document,
  });

  final Editor editor;
  final MutableDocumentComposer composer;
  final MutableDocument document;
  final DateMentionParser _parser = const DateMentionParser();

  OverlayEntry? _overlay;
  String? _lastKey;

  static const _quick = <String>['today', 'tomorrow', 'next mon', 'fri 9:00'];

  void onDocumentChanged(BuildContext context) {
    final sel = composer.selection;
    if (sel == null || !sel.isCollapsed) return dismiss();
    final node = document.getNodeById(sel.extent.nodeId);
    if (node is! TextNode || sel.extent.nodePosition is! TextNodePosition) {
      return dismiss();
    }
    final cursor = (sel.extent.nodePosition as TextNodePosition).offset;
    final text = node.text.toPlainText();
    final query = extractQuery(text, cursor);
    if (query == null) return dismiss();

    final key = '${node.id}:$cursor:$query';
    if (key == _lastKey && _overlay != null) return;
    _lastKey = key;
    dismiss();
    _overlay = OverlayEntry(
      builder: (_) => _PickerOverlay(
        suggestions: suggestionsFor(query),
        onPick: (m) => _insert(node.id, cursor, query, m),
        onPickDate: () => _pickDate(context, node.id, cursor, query),
        onDismiss: dismiss,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  /// Text between the nearest preceding `@` (at word start) and [cursor],
  /// or null when the cursor is not inside an `@` token.
  static String? extractQuery(String text, int cursor) {
    if (cursor <= 0 || cursor > text.length) return null;
    for (var i = cursor - 1; i >= 0 && cursor - i <= 24; i--) {
      final ch = text[i];
      if (ch == '\n') return null;
      if (ch == '@') {
        if (i > 0 && text[i - 1] != ' ') return null;
        return text.substring(i + 1, cursor);
      }
    }
    return null;
  }

  /// Parsed suggestions for [query] (typed preview first, then quick picks).
  List<({String label, ParsedMention mention})> suggestionsFor(String query) {
    final out = <({String label, ParsedMention mention})>[];
    void add(String q) {
      try {
        final m = _parser.parse(q);
        if (!out.any((e) => dateChipText(e.mention) == dateChipText(m))) {
          out.add((label: q, mention: m));
        }
      } on DateMentionParseException {
        // Not parseable (yet) — skip.
      }
    }

    if (query.trim().isNotEmpty) add(query.trim());
    for (final q in _quick) {
      if (query.isEmpty || q.startsWith(query.toLowerCase())) add(q);
    }
    return out;
  }

  Future<void> _pickDate(
    BuildContext context,
    String nodeId,
    int cursor,
    String query,
  ) async {
    dismiss();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    _insert(nodeId, cursor, query, ParsedMention(startsAt: date, allDay: true));
  }

  void _insert(String nodeId, int cursor, String query, ParsedMention m) {
    dismiss();
    final start = cursor - query.length - 1; // include '@'
    final chip = dateChipText(m);
    editor.execute([
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: start),
          ),
          end: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: cursor),
          ),
        ),
      ),
      InsertTextRequest(
        documentPosition: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: start),
        ),
        textToInsert: chip,
        attributions: {dateChipAttribution},
      ),
      InsertTextRequest(
        documentPosition: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: start + chip.length),
        ),
        textToInsert: ' ',
        attributions: const {},
      ),
    ]);
  }

  void dismiss() {
    _overlay?.remove();
    _overlay = null;
    _lastKey = null;
  }
}

class _PickerOverlay extends StatelessWidget {
  const _PickerOverlay({
    required this.suggestions,
    required this.onPick,
    required this.onPickDate,
    required this.onDismiss,
  });

  final List<({String label, ParsedMention mention})> suggestions;
  final void Function(ParsedMention) onPick;
  final VoidCallback onPickDate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              width: 240,
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final s in suggestions)
                    InkWell(
                      onTap: () => onPick(s.mention),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(AppIcons.event, size: 14, color: colors.brand),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.text,
                                ),
                              ),
                            ),
                            Text(
                              dateChipText(s.mention).substring(1),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: onPickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.calendarActive,
                            size: 14,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pick a date…',
                            style: TextStyle(fontSize: 14, color: colors.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
