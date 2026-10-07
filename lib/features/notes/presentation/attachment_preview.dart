// lib/features/notes/presentation/attachment_preview.dart
// In-app preview for all attachment kinds.
// Images: decoded from encrypted bytes.
// PDF: metadata card + "Open externally" (via open_filex, deferred to Phase 8).
// CSV: table preview (≤ 1,000 rows). TXT: selectable text (≤ 1 MB).
// DOCX/PPTX: metadata card + "Open externally".

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/attachment.dart';

// ── Preview provider ──────────────────────────────────────────────────────────

final _attachmentBytesProvider =
    FutureProvider.family<Uint8List, String>((ref, storageName) async {
  final repo = ref.watch(attachmentRepositoryProvider);
  return repo.loadBlob(storageName);
});

// ── Preview sheet ─────────────────────────────────────────────────────────────

class AttachmentPreviewSheet extends ConsumerWidget {
  const AttachmentPreviewSheet({
    required this.attachment,
    required this.noteId,
    super.key,
  });
  final Attachment attachment;
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bytesAsync =
        ref.watch(_attachmentBytesProvider(attachment.storageName));

    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Filename
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                attachment.kind.serialized.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                    letterSpacing: 0.5),
              ),
            ),
            // Content
            Expanded(
              child: bytesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(
                    child: Text('Could not load preview.',
                        style: TextStyle(color: colors.textMuted))),
                data: (bytes) => _PreviewContent(
                  attachment: attachment,
                  bytes: bytes,
                  scrollController: ctrl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview content router ────────────────────────────────────────────────────

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.attachment,
    required this.bytes,
    required this.scrollController,
  });
  final Attachment attachment;
  final Uint8List bytes;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    switch (attachment.kind) {
      case AttachmentKind.png:
      case AttachmentKind.jpeg:
        return _ImagePreview(bytes: bytes);
      case AttachmentKind.svg:
        return _MetadataCard(
            attachment: attachment,
            note: 'SVG preview not available — open externally.');
      case AttachmentKind.pdf:
        return _MetadataCard(
            attachment: attachment,
            note: 'PDF in-app preview coming in a later update.');
      case AttachmentKind.csv:
        return _CsvPreview(bytes: bytes, scrollController: scrollController);
      case AttachmentKind.txt:
        return _TxtPreview(bytes: bytes, scrollController: scrollController);
      case AttachmentKind.docx:
      case AttachmentKind.pptx:
        return _MetadataCard(attachment: attachment);
    }
  }
}

// ── Image preview ─────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          cacheWidth: (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round(),
        ),
      ),
    );
  }
}

// ── CSV preview ───────────────────────────────────────────────────────────────

class _CsvPreview extends StatelessWidget {
  const _CsvPreview(
      {required this.bytes, required this.scrollController});
  final Uint8List bytes;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter()
        .convert(text)
        .take(1000)
        .toList();

    if (lines.isEmpty) {
      return Center(
          child: Text('Empty CSV',
              style: TextStyle(color: colors.textMuted)));
    }

    return SingleChildScrollView(
      controller: scrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          columns: _columns(lines.first, colors),
          rows: _rows(lines.skip(1).toList(), colors),
        ),
      ),
    );
  }

  List<DataColumn> _columns(String header, AppColorTokens colors) {
    return header
        .split(',')
        .map((h) => DataColumn(
            label: Text(h.trim(),
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                    fontSize: 13))))
        .toList();
  }

  List<DataRow> _rows(List<String> lines, AppColorTokens colors) {
    return lines
        .map((line) => DataRow(
              cells: line
                  .split(',')
                  .map((cell) => DataCell(Text(
                      // Formula injection guard — prefix = + - @ with apostrophe for display.
                      _safeCellText(cell.trim()),
                      style: TextStyle(fontSize: 12, color: colors.text))))
                  .toList(),
            ))
        .toList();
  }

  String _safeCellText(String cell) {
    if (cell.isNotEmpty &&
        (cell[0] == '=' ||
            cell[0] == '+' ||
            cell[0] == '-' ||
            cell[0] == '@')) {
      return "'$cell";
    }
    return cell;
  }
}

// ── TXT preview ───────────────────────────────────────────────────────────────

class _TxtPreview extends StatelessWidget {
  const _TxtPreview(
      {required this.bytes, required this.scrollController});
  final Uint8List bytes;
  final ScrollController scrollController;

  static const _maxPreviewBytes = 1024 * 1024; // 1 MB

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final truncated = bytes.length > _maxPreviewBytes;
    final preview = truncated
        ? bytes.sublist(0, _maxPreviewBytes)
        : bytes;
    final text = utf8.decode(preview, allowMalformed: true);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: SelectableText(
                text,
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'JetBrainsMono',
                    color: colors.text),
              ),
            ),
          ),
          if (truncated)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing first 1 MB of file.',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Metadata card ─────────────────────────────────────────────────────────────

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.attachment, this.note});
  final Attachment attachment;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sizeKb = (attachment.size / 1024).round();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _icon,
            size: 56,
            color: colors.brand,
          ),
          const SizedBox(height: 16),
          Text(
            attachment.kind.mime,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text),
          ),
          const SizedBox(height: 4),
          Text('$sizeKb KB',
              style: TextStyle(fontSize: 13, color: colors.textMuted)),
          if (note != null) ...[
            const SizedBox(height: 16),
            Text(note!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textMuted)),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open externally'),
            onPressed: () {
              // Phase 8: integrate open_filex to decrypt → temp file → open
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'External file opening coming in a later update.'),
              ));
            },
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (attachment.kind) {
        AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
        AttachmentKind.docx => Icons.description_outlined,
        AttachmentKind.pptx => Icons.slideshow_outlined,
        AttachmentKind.svg => Icons.auto_awesome_outlined,
        _ => Icons.attach_file,
      };
}
