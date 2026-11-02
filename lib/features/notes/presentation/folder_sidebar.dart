// lib/features/notes/presentation/folder_sidebar.dart
// Folder tree sidebar used in both mobile (drawer/stack) and desktop (pane).
// Supports: expand/collapse, create, rename (inline), delete, move (long-press menu).

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/shared/widgets/widgets.dart';
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
        // ── Header — uses DrawerHeader for proper system-bar clearance ──────
        DrawerHeader(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.brand, colors.brand.withAlpha(200)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.folderSpecialOutlined,
                        color: colors.onBrand,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Folders',
                          style: TextStyle(
                            color: colors.onBrand,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // New folder button — at the bottom of the header, thumb-reachable
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _createFolder(context, ref, null),
                      icon: Icon(
                        AppIcons.createNewFolderOutlined,
                        size: 16,
                        color: colors.onBrand,
                      ),
                      label: Text(
                        'New folder',
                        style: TextStyle(color: colors.onBrand, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.onBrand.withAlpha(128)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Folder list + tags ──────────────────────────────────────────────
        Expanded(
          child: foldersAsync.when(
            loading: () => const SkeletonList(count: 4, showLeading: false),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: ErrorState.inline(
                error: e,
                stackTrace: st,
                title: 'Couldn’t load folders',
                onRetry: () => ref.invalidate(foldersProvider),
              ),
            ),
            data: (folders) => Column(
              children: [
                Expanded(child: _FolderTree(folders: folders)),
                const TagPanel(),
              ],
            ),
          ),
        ),

        // ── Safe area bottom padding (navigation bar) ───────────────────────
        const SafeArea(top: false, child: SizedBox(height: 4)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folders nested this deep may be hard to navigate.'),
          ),
        );
      }
    }

    final repo = ref.read(noteRepositoryProvider);
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
              icon: AppIcons.inboxOutlined,
              isActive: activeId == null,
              depth: 0,
              onTap: () => _selectFolder(context, ref, null),
            ),
            const SizedBox(height: 8),
            Text(
              'No folders yet.',
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
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
            icon: AppIcons.inboxOutlined,
            isActive: activeId == null,
            depth: 0,
            onTap: () => _selectFolder(context, ref, null),
          );
        }
        final node = flat[i - 1];
        final folder = node.folder;
        final isExpanded = expanded.contains(folder.id);
        final isActive = activeId == folder.id;

        return _FolderTile(
          label: folder.name,
          icon: AppIcons.folder,
          activeIcon: AppIcons.folderFill,
          isActive: isActive,
          depth: node.depth,
          hasChildren: node.children.isNotEmpty,
          isExpanded: isExpanded,
          onTap: () => _selectFolder(context, ref, folder.id),
          onToggleExpand: () {
            ref.read(expandedFolderIdsProvider.notifier).toggle(folder.id);
          },
          onLongPress: () => _showFolderMenu(context, ref, folder, folders),
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
      builder: (_) =>
          _FolderActionSheet(folder: folder, allFolders: allFolders, ref: ref),
    );
  }

  /// Set the active folder and close the drawer if open (mobile layout).
  void _selectFolder(BuildContext context, WidgetRef ref, String? folderId) {
    ref.read(activeFolderIdProvider.notifier).set(folderId);
    // Close drawer when running inside a Scaffold with a drawer (mobile).
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.sm + depth * 14.0,
        right: AppSpace.sm,
        top: AppSpace.xxs,
        bottom: AppSpace.xxs,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          borderRadius: AppRadius.brSm,
          child: AnimatedContainer(
            duration: resolvedDuration(context, AppDurations.fast),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm + 2,
              vertical: AppSpace.sm + 1,
            ),
            decoration: BoxDecoration(
              color: isActive ? colors.brandSubtle : AppColors.transparent,
              borderRadius: AppRadius.brSm,
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
                            ? AppIcons.keyboardArrowDown
                            : AppIcons.keyboardArrowRight,
                        size: 16,
                        color: isActive ? colors.brandText : colors.textMuted,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 20),
                Icon(
                  isActive ? (activeIcon ?? icon) : icon,
                  size: 18,
                  color: isActive ? colors.brandText : colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive ? colors.brandText : colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              child: Text(
                folder.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colors.text,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                AppIcons.driveFileRenameOutline,
                color: colors.text,
              ),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.of(context).pop();
                final name = await _promptFolderName(
                  context,
                  initial: folder.name,
                );
                if (name != null && name.trim().isNotEmpty) {
                  await ref
                      .read(noteRepositoryProvider)
                      .saveFolder(
                        folder.copyWith(
                          name: name.trim(),
                          hlc: Hlc.now().toIso(),
                        ),
                      );
                }
              },
            ),
            ListTile(
              leading: Icon(
                AppIcons.createNewFolderOutlined,
                color: colors.text,
              ),
              title: const Text('New subfolder'),
              onTap: () async {
                Navigator.of(context).pop();
                await FolderSidebar._createFolder(context, ref, folder.id);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.delete, color: colors.danger),
              title: Text(
                'Delete folder',
                style: TextStyle(color: colors.danger),
              ),
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
          'All notes in "$name" will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Prompt helpers ────────────────────────────────────────────────────────────

Future<String?> _promptFolderName(
  BuildContext context, {
  required String initial,
}) {
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
