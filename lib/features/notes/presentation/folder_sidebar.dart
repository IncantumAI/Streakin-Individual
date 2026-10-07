// lib/features/notes/presentation/folder_sidebar.dart
// Folder tree sidebar used in both mobile (drawer/stack) and desktop (pane).
// Supports: expand/collapse, create, rename (inline), delete, move (long-press menu).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/features/notes/application/folder_tree.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/folder.dart';
import 'package:streakin/features/notes/presentation/tag_panel.dart';

class FolderSidebar extends ConsumerWidget {
  const FolderSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarHeader(onNewFolder: () => _createFolder(context, ref, null)),
        Expanded(
          child: foldersAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator.adaptive()),
            error: (e, _) =>
                Center(child: Text('Error', style: TextStyle(color: colors.danger))),
            data: (folders) => Column(
              children: [
                Expanded(child: _FolderTree(folders: folders)),
                const TagPanel(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _createFolder(
    BuildContext context,
    WidgetRef ref,
    String? parentId,
  ) async {
    final name = await _promptFolderName(context, initial: '');
    if (name == null || name.trim().isEmpty) return;

    // Check nesting depth.
    final allFolders = ref.read(foldersProvider).value ?? [];
    if (parentId != null && exceedsSoftCap(allFolders, parentId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Folders nested this deep may be hard to navigate.'),
        ));
      }
    }

    final repo = ref.read(noteRepositoryProvider);
    final now = DateTime.now();
    final folder = Folder(
      id: const Uuid().v4(),
      parentId: parentId,
      name: name.trim(),
      sortOrder: allFolders.where((f) => f.parentId == parentId).length,
      hlc: Hlc.now().toIso(),
    );
    await repo.saveFolder(folder);
  }
}

// ── Folder tree widget ────────────────────────────────────────────────────────

class _FolderTree extends ConsumerWidget {
  const _FolderTree({required this.folders});
  final List<Folder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(folderSortModeProvider);
    final expanded = ref.watch(expandedFolderIdsProvider);
    final activeId = ref.watch(activeFolderIdProvider);
    final colors = context.colors;

    final roots = buildFolderTree(folders, sort: sort);
    final flat = flattenTree(roots, expanded);

    if (flat.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Root Inbox
            _FolderTile(
              label: 'Inbox',
              icon: Icons.inbox_outlined,
              isActive: activeId == null,
              depth: 0,
              onTap: () => ref.read(activeFolderIdProvider.notifier).set(null),
            ),
            const SizedBox(height: 8),
            Text('No folders yet.',
                style: TextStyle(fontSize: 13, color: colors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: flat.length + 1, // +1 for Inbox at top
      itemBuilder: (context, i) {
        // Index 0 is always Inbox.
        if (i == 0) {
          return _FolderTile(
            label: 'Inbox',
            icon: Icons.inbox_outlined,
            isActive: activeId == null,
            depth: 0,
            onTap: () => ref.read(activeFolderIdProvider.notifier).set(null),
          );
        }
        final node = flat[i - 1];
        final folder = node.folder;
        final isExpanded = expanded.contains(folder.id);
        final isActive = activeId == folder.id;

        return _FolderTile(
          label: folder.name,
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          isActive: isActive,
          depth: node.depth,
          hasChildren: node.children.isNotEmpty,
          isExpanded: isExpanded,
          onTap: () {
            ref.read(activeFolderIdProvider.notifier).set(folder.id);
          },
          onToggleExpand: () {
            ref.read(expandedFolderIdsProvider.notifier).toggle(folder.id);
          },
          onLongPress: () =>
              _showFolderMenu(context, ref, folder, folders),
        );
      },
    );
  }

  void _showFolderMenu(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
    List<Folder> allFolders,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _FolderActionSheet(
        folder: folder,
        allFolders: allFolders,
        ref: ref,
      ),
    );
  }
}

// ── Folder tile ───────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.isActive,
    required this.depth,
    this.hasChildren = false,
    this.isExpanded = false,
    required this.onTap,
    this.onToggleExpand,
    this.onLongPress,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final bool isActive;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: isActive ? colors.brand.withValues(alpha: 0.1) : null,
        padding: EdgeInsets.only(
          left: 12.0 + depth * 16.0,
          right: 8,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            // Expand/collapse toggle
            if (hasChildren)
              GestureDetector(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 16,
                    color: colors.textMuted,
                  ),
                ),
              )
            else
              const SizedBox(width: 20),
            Icon(
              isActive ? (activeIcon ?? icon) : icon,
              size: 18,
              color: isActive ? colors.brand : colors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? colors.brand : colors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar header ────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.onNewFolder});
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
      child: Row(
        children: [
          Text('Folders',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                  letterSpacing: 0.5)),
          const Spacer(),
          InkWell(
            onTap: onNewFolder,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.add, size: 18, color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Folder action sheet ───────────────────────────────────────────────────────

class _FolderActionSheet extends StatelessWidget {
  const _FolderActionSheet({
    required this.folder,
    required this.allFolders,
    required this.ref,
  });

  final Folder folder;
  final List<Folder> allFolders;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(folder.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: colors.text)),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.drive_file_rename_outline, color: colors.text),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.of(context).pop();
                final name =
                    await _promptFolderName(context, initial: folder.name);
                if (name != null && name.trim().isNotEmpty) {
                  await ref.read(noteRepositoryProvider).saveFolder(
                        folder.copyWith(name: name.trim(), hlc: Hlc.now().toIso()),
                      );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.create_new_folder_outlined, color: colors.text),
              title: const Text('New subfolder'),
              onTap: () async {
                Navigator.of(context).pop();
                await FolderSidebar._createFolder(context, ref, folder.id);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.danger),
              title: Text('Delete folder',
                  style: TextStyle(color: colors.danger)),
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed = await _confirmDelete(context, folder.name);
                if (confirmed == true) {
                  await ref
                      .read(noteRepositoryProvider)
                      .softDeleteFolder(folder.id);
                  // Reset active folder if we deleted it.
                  if (ref.read(activeFolderIdProvider) == folder.id) {
                    ref.read(activeFolderIdProvider.notifier).set(null);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
            'All notes in "$name" will be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
  }
}

// ── Prompt helpers ────────────────────────────────────────────────────────────

Future<String?> _promptFolderName(BuildContext context,
    {required String initial}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Folder name'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter folder name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('OK')),
      ],
    ),
  );
}
