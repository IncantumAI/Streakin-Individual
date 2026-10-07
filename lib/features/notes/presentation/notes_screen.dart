// lib/features/notes/presentation/notes_screen.dart
// Notes root screen. Responsive:
//   Mobile  — hamburger drawer for folder sidebar
//   Desktop — 3-pane layout via NotesLayout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/editor/note_templates.dart';
import 'package:streakin/features/notes/presentation/folder_breadcrumbs.dart';
import 'package:streakin/features/notes/presentation/folder_sidebar.dart';
import 'package:streakin/features/notes/presentation/notes_layout.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;

    if (isDesktop) {
      return NotesLayout(
        noteList: _NoteListPane(onNewNote: () => _showTemplatePicker(context, ref)),
      );
    }

    return Scaffold(
      drawer: const Drawer(child: FolderSidebar()),
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New note',
            onPressed: () => _showTemplatePicker(context, ref),
          ),
        ],
      ),
      body: _NoteListPane(
        onNewNote: () => _showTemplatePicker(context, ref),
        showAppBar: false,
      ),
    );
  }

  static void _showTemplatePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<NoteTemplateKind>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _TemplatePickerSheet(),
    ).then((kind) {
      if (kind != null && context.mounted) {
        _createNote(context, ref, kind);
      }
    });
  }

  static Future<void> _createNote(
      BuildContext context, WidgetRef ref, NoteTemplateKind kind) async {
    final repo = ref.read(noteRepositoryProvider);
    final folderId = ref.read(activeFolderIdProvider);
    final now = DateTime.now();
    final id = const Uuid().v4();
    final doc = buildTemplate(kind);
    final title = templateTitle(kind);
    final note = Note(
      id: id,
      folderId: folderId,
      title: title,
      templateKind: kind,
      body: doc.toJson(),
      createdAt: now,
      updatedAt: now,
      hlc: Hlc.now().toIso(),
    );
    await repo.saveNote(note);
    if (context.mounted) {
      context.push('/notes/$id');
    }
  }
}

// ── Note list pane ────────────────────────────────────────────────────────────

class _NoteListPane extends ConsumerWidget {
  const _NoteListPane({
    required this.onNewNote,
    this.showAppBar = true,
  });
  final VoidCallback onNewNote;
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderId = ref.watch(activeFolderIdProvider);
    final activeTag = ref.watch(activeTagFilterProvider);
    // Tag filter takes priority over folder filter.
    final notesAsync = activeTag != null
        ? ref.watch(notesByTagProvider(activeTag))
        : ref.watch(notesInFolderProvider(folderId));
    final colors = context.colors;

    final body = Column(
      children: [
        const FolderBreadcrumbs(),
        Expanded(
          child: notesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (notes) {
              if (notes.isEmpty) return const _EmptyNotesState();
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notes.length,
                itemBuilder: (ctx, i) => _NoteListTile(note: notes[i]),
              );
            },
          ),
        ),
      ],
    );

    if (!showAppBar) return body;

    // Desktop pane header
    final folderName = _activeFolderName(ref);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(folderName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New note',
            onPressed: onNewNote,
          ),
        ],
      ),
      body: body,
    );
  }

  String _activeFolderName(WidgetRef ref) {
    final folderId = ref.read(activeFolderIdProvider);
    if (folderId == null) return 'Notes';
    final folders = ref.read(foldersProvider).value ?? [];
    try {
      return folders.firstWhere((f) => f.id == folderId).name;
    } catch (_) {
      return 'Notes';
    }
  }
}

// ── Note list tile ────────────────────────────────────────────────────────────

class _NoteListTile extends ConsumerWidget {
  const _NoteListTile({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return ListTile(
      onTap: () => context.push('/notes/${note.id}'),
      title: Text(
        note.title.isEmpty ? 'Untitled' : note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontWeight: FontWeight.w500, color: colors.text, fontSize: 15),
      ),
      subtitle: Text(
        _formatDate(note.updatedAt),
        style: TextStyle(fontSize: 12, color: colors.textMuted),
      ),
      leading: Icon(Icons.article_outlined, color: colors.textMuted, size: 22),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin_outlined, size: 16, color: colors.brand),
            ),
          PopupMenuButton<_NoteAction>(
            icon: Icon(Icons.more_vert, size: 18, color: colors.textMuted),
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _NoteAction.pin, child: Text('Pin / Unpin')),
              PopupMenuItem(value: _NoteAction.move, child: Text('Move to folder')),
              PopupMenuItem(value: _NoteAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, _NoteAction action) async {
    final repo = ref.read(noteRepositoryProvider);
    switch (action) {
      case _NoteAction.pin:
        await repo.saveNote(note.copyWith(
          isPinned: !note.isPinned,
          updatedAt: DateTime.now(),
          hlc: Hlc.now().toIso(),
        ));
      case _NoteAction.delete:
        await repo.softDeleteNote(note.id);
      case _NoteAction.move:
        if (!context.mounted) return;
        final targetId = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => _MoveFolderSheet(currentFolderId: note.folderId),
        );
        if (targetId != null) {
          await repo.moveNote(note.id, targetId.isEmpty ? null : targetId);
        }
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

enum _NoteAction { pin, move, delete }

// ── Move to folder sheet ──────────────────────────────────────────────────────

class _MoveFolderSheet extends ConsumerWidget {
  const _MoveFolderSheet({this.currentFolderId});
  final String? currentFolderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Move to folder',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: colors.text)),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.inbox_outlined, color: colors.textMuted),
              title: const Text('Inbox'),
              onTap: () => Navigator.of(context).pop(''),
            ),
            ...?foldersAsync.value?.map((f) => ListTile(
                  leading: Icon(Icons.folder_outlined, color: colors.textMuted),
                  title: Text(f.name),
                  onTap: () => Navigator.of(context).pop(f.id),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 56, color: colors.outline),
          const SizedBox(height: 16),
          Text('No notes yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.text)),
          const SizedBox(height: 8),
          Text('Tap + to create your first note.',
              style: TextStyle(fontSize: 14, color: colors.textMuted)),
        ],
      ),
    );
  }
}

// ── Template picker sheet ─────────────────────────────────────────────────────

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Choose a template',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.text)),
            const SizedBox(height: 12),
            ...kAllTemplates.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.text)),
                  subtitle: Text(t.description,
                      style: TextStyle(fontSize: 13, color: colors.textMuted)),
                  leading: Icon(
                    t.kind == NoteTemplateKind.blank
                        ? Icons.add
                        : Icons.description_outlined,
                    color: colors.brand,
                  ),
                  onTap: () => Navigator.of(context).pop(t.kind),
                )),
          ],
        ),
      ),
    );
  }
}
