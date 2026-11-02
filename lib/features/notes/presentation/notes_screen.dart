// lib/features/notes/presentation/notes_screen.dart
// Notes root screen. Responsive:
//   Mobile  — hamburger drawer for folder sidebar
//   Desktop — 3-pane layout via NotesLayout

import 'package:streakin/core/design/icons.dart';

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/editor/note_templates.dart';
import 'package:streakin/features/notes/presentation/folder_breadcrumbs.dart';
import 'package:streakin/features/notes/presentation/folder_sidebar.dart';
import 'package:streakin/features/notes/presentation/notes_layout.dart';
import 'package:streakin/shared/widgets/widgets.dart';

/// Opens the template picker and creates the chosen note (used by the
/// dashboard "New note" quick action).
void showNewNoteFlow(BuildContext context, WidgetRef ref) =>
    NotesScreen._showTemplatePicker(context, ref);

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;

    if (isDesktop) {
      return NotesLayout(
        noteList: _NoteListPane(
          onNewNote: () => _showTemplatePicker(context, ref),
        ),
      );
    }

    final colors = context.colors;
    return Scaffold(
      drawer: const Drawer(child: FolderSidebar()),
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.graph),
            tooltip: 'Graph view',
            onPressed: () => context.push('/notes/graph'),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      backgroundColor: colors.bg,
      body: _NoteListPane(
        onNewNote: () => _showTemplatePicker(context, ref),
        showAppBar: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplatePicker(context, ref),
        tooltip: 'New note',
        icon: const Icon(AppIcons.add),
        label: const Text('New note'),
      ),
    );
  }

  static void _showTemplatePicker(BuildContext context, WidgetRef ref) {
    showAppBottomSheet<NoteTemplateKind>(
      context,
      title: 'Choose a template',
      builder: (_) => const _TemplatePickerSheet(),
    ).then((kind) {
      if (kind != null && context.mounted) {
        _createNote(context, ref, kind);
      }
    });
  }

  static Future<void> _createNote(
    BuildContext context,
    WidgetRef ref,
    NoteTemplateKind kind,
  ) async {
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
      unawaited(context.push('/notes/$id'));
    }
  }
}

// ── Note list pane ────────────────────────────────────────────────────────────

class _NoteListPane extends ConsumerWidget {
  const _NoteListPane({required this.onNewNote, this.showAppBar = true});
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
        // Search affordance (mobile header; desktop has its own panes).
        if (!showAppBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.xs,
              AppSpace.lg,
              AppSpace.xs,
            ),
            child: _SearchField(onTap: () => context.push('/notes/search')),
          ),
        const FolderBreadcrumbs(),
        Expanded(
          child: notesAsync.when(
            loading: () => const SkeletonList(),
            error: (e, st) => ErrorState(
              error: e,
              stackTrace: st,
              title: 'Couldn’t load notes',
            ),
            data: (notes) {
              if (notes.isEmpty) {
                return _EmptyNotesState(onNewNote: onNewNote);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.lg,
                  96,
                ),
                itemCount: notes.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
                itemBuilder: (ctx, i) => StaggeredEntrance(
                  index: i,
                  child: _NoteListTile(note: notes[i]),
                ),
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
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(folderName),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.search),
            tooltip: 'Search notes (Ctrl+K)',
            onPressed: () => context.push('/notes/search'),
          ),
          IconButton(
            icon: const Icon(AppIcons.add),
            tooltip: 'New note (Ctrl+N)',
            onPressed: onNewNote,
          ),
          const SizedBox(width: AppSpace.sm),
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
    final title = note.title.isEmpty ? 'Untitled' : note.title;
    return AppCard(
      onTap: () => context.push('/notes/${note.id}'),
      onLongPress: () => _showActionSheet(context, ref),
      onSecondaryTapDown: (d) =>
          _showContextMenu(context, ref, d.globalPosition),
      semanticLabel: title,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.md,
        AppSpace.xs,
        AppSpace.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: note.isPinned ? colors.brandSubtle : colors.surfaceAlt,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(
              note.isPinned ? AppIcons.pinFill : AppIcons.articleOutlined,
              color: note.isPinned ? colors.brandText : colors.textMuted,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall!.copyWith(
                    fontSize: 15,
                    color: note.title.isEmpty ? colors.textMuted : colors.text,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  _formatDate(note.updatedAt),
                  style: context.text.bodySmall!.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<_NoteAction>(
            tooltip: 'Note options',
            icon: Icon(AppIcons.more, size: 18, color: colors.textMuted),
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (_) => _menuItems(),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<_NoteAction>> _menuItems() => [
    PopupMenuItem(
      value: _NoteAction.pin,
      child: Text(note.isPinned ? 'Unpin' : 'Pin'),
    ),
    const PopupMenuItem(value: _NoteAction.move, child: Text('Move to folder')),
    const PopupMenuItem(value: _NoteAction.delete, child: Text('Delete')),
  ];

  /// Desktop right-click menu at the pointer.
  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset at,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<_NoteAction>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: _menuItems(),
    );
    if (action != null && context.mounted) {
      await _handleAction(context, ref, action);
    }
  }

  /// Mobile long-press actions.
  Future<void> _showActionSheet(BuildContext context, WidgetRef ref) async {
    final action = await showAppBottomSheet<_NoteAction>(
      context,
      title: note.title.isEmpty ? 'Untitled' : note.title,
      isScrollControlled: false,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.isPinned ? AppIcons.pin : AppIcons.pinFill),
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              onTap: () => Navigator.of(ctx).pop(_NoteAction.pin),
            ),
            ListTile(
              leading: const Icon(AppIcons.folder),
              title: const Text('Move to folder'),
              onTap: () => Navigator.of(ctx).pop(_NoteAction.move),
            ),
            ListTile(
              leading: Icon(AppIcons.delete, color: ctx.colors.danger),
              title: Text('Delete', style: TextStyle(color: ctx.colors.danger)),
              onTap: () => Navigator.of(ctx).pop(_NoteAction.delete),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
    if (action != null && context.mounted) {
      await _handleAction(context, ref, action);
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _NoteAction action,
  ) async {
    final repo = ref.read(noteRepositoryProvider);
    switch (action) {
      case _NoteAction.pin:
        await repo.saveNote(
          note.copyWith(
            isPinned: !note.isPinned,
            updatedAt: DateTime.now(),
            hlc: Hlc.now().toIso(),
          ),
        );
      case _NoteAction.delete:
        await repo.softDeleteNote(note.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '“${note.title.isEmpty ? 'Untitled' : note.title}” deleted',
              ),
            ),
          );
        }
      case _NoteAction.move:
        if (!context.mounted) return;
        final targetId = await showAppBottomSheet<String>(
          context,
          title: 'Move to folder',
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(AppIcons.inboxOutlined, color: colors.textMuted),
              title: const Text('Inbox'),
              selected: currentFolderId == null,
              trailing: currentFolderId == null
                  ? Icon(AppIcons.check, color: colors.brandText)
                  : null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            ...?foldersAsync.value?.map(
              (f) => ListTile(
                leading: Icon(AppIcons.folder, color: colors.textMuted),
                title: Text(f.name),
                selected: currentFolderId == f.id,
                trailing: currentFolderId == f.id
                    ? Icon(AppIcons.check, color: colors.brandText)
                    : null,
                onTap: () => Navigator.of(context).pop(f.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState({required this.onNewNote});
  final VoidCallback onNewNote;
  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.emptyNotes,
      title: 'No notes yet',
      message: 'Start with a blank page or pick a template.',
      action: FilledButton.icon(
        onPressed: onNewNote,
        icon: const Icon(AppIcons.add, size: AppSizes.iconMd),
        label: const Text('New note'),
      ),
    );
  }
}

/// Tappable faux search field that opens the search screen.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Search notes',
      excludeSemantics: true,
      child: Material(
        color: c.surfaceAlt,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.search,
                  size: AppSizes.iconMd,
                  color: c.textMuted,
                ),
                const SizedBox(width: AppSpace.md),
                Text(
                  'Search notes',
                  style: context.text.bodyMedium!.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < kAllTemplates.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.sm),
              StaggeredEntrance(
                index: i,
                child: AppCard(
                  onTap: () => Navigator.of(context).pop(kAllTemplates[i].kind),
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.brandSubtle,
                          borderRadius: AppRadius.brMd,
                        ),
                        child: Icon(
                          kAllTemplates[i].kind == NoteTemplateKind.blank
                              ? AppIcons.add
                              : AppIcons.descriptionOutlined,
                          color: colors.brandText,
                          size: AppSizes.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kAllTemplates[i].label,
                              style: context.text.titleSmall,
                            ),
                            const SizedBox(height: AppSpace.xxs),
                            Text(
                              kAllTemplates[i].description,
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
