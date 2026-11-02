// lib/features/notes/presentation/attachment_strip.dart
// Horizontal attachment gallery strip at the bottom of the note editor.
// Tap to preview; long-press to delete.

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/attachment.dart';
import 'package:streakin/features/notes/presentation/attachment_preview.dart';

class AttachmentStrip extends ConsumerWidget {
  const AttachmentStrip({required this.noteId, super.key});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(noteAttachmentsProvider(noteId));
    final colors = context.colors;

    return attachmentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (attachments) {
        if (attachments.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 76,
          color: colors.surfaceAlt,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: attachments.length,
            itemBuilder: (context, i) =>
                _AttachmentThumb(attachment: attachments[i], noteId: noteId),
          ),
        );
      },
    );
  }
}

// ── Thumbnail tile ────────────────────────────────────────────────────────────

class _AttachmentThumb extends ConsumerWidget {
  const _AttachmentThumb({required this.attachment, required this.noteId});
  final Attachment attachment;
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return GestureDetector(
      onTap: () => _preview(context),
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconFor(attachment.kind), size: 24, color: colors.brand),
            const SizedBox(height: 2),
            Text(
              attachment.kind.serialized.toUpperCase(),
              style: TextStyle(fontSize: 9, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AttachmentKind kind) => switch (kind) {
    AttachmentKind.png || AttachmentKind.jpeg => AppIcons.imageOutlined,
    AttachmentKind.svg => AppIcons.autoAwesomeOutlined,
    AttachmentKind.pdf => AppIcons.pictureAsPdfOutlined,
    AttachmentKind.csv => AppIcons.tableChartOutlined,
    AttachmentKind.txt => AppIcons.textSnippetOutlined,
    AttachmentKind.docx => AppIcons.descriptionOutlined,
    AttachmentKind.pptx => AppIcons.slideshowOutlined,
  };

  void _preview(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          AttachmentPreviewSheet(attachment: attachment, noteId: noteId),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove attachment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(attachmentRepositoryProvider);
      await repo.deleteAttachment(attachment.id);
    }
  }
}
