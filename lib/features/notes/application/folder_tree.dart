// lib/features/notes/application/folder_tree.dart
// Folder tree helpers: build tree from flat list, breadcrumb path,
// nesting depth check, sort modes.

import 'package:streakin/features/notes/domain/folder.dart';

// ── Sort mode ─────────────────────────────────────────────────────────────────

enum FolderSortMode { name, modified, manual }

// ── Tree node ─────────────────────────────────────────────────────────────────

class FolderTreeNode {
  FolderTreeNode({
    required this.folder,
    this.children = const [],
    this.depth = 0,
  });

  final Folder folder;
  final List<FolderTreeNode> children;
  final int depth;

  /// Maximum nesting level in this subtree (inclusive of self).
  int get maxDepth {
    if (children.isEmpty) return depth;
    return children.map((c) => c.maxDepth).reduce((a, b) => a > b ? a : b);
  }
}

// ── Build tree from flat list ─────────────────────────────────────────────────

/// Converts a flat list of [Folder] objects into a tree.
/// Root nodes have [parentId] == null.
List<FolderTreeNode> buildFolderTree(
  List<Folder> folders, {
  FolderSortMode sort = FolderSortMode.manual,
}) {
  final sorted = _sort(folders, sort);
  return _buildChildren(null, sorted, 0);
}

List<FolderTreeNode> _buildChildren(
  String? parentId,
  List<Folder> all,
  int depth,
) {
  return all
      .where((f) => f.parentId == parentId)
      .map(
        (f) => FolderTreeNode(
          folder: f,
          children: _buildChildren(f.id, all, depth + 1),
          depth: depth,
        ),
      )
      .toList();
}

List<Folder> _sort(List<Folder> folders, FolderSortMode mode) {
  final copy = List<Folder>.from(folders);
  switch (mode) {
    case FolderSortMode.name:
      copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case FolderSortMode.manual:
      copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    case FolderSortMode.modified:
      // No updatedAt on Folder — fall back to manual.
      copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return copy;
}

// ── Flatten for ListView ──────────────────────────────────────────────────────

/// Flatten a tree into an in-order list for rendering in a ListView.
/// [expanded] is the set of folder IDs whose children are visible.
List<FolderTreeNode> flattenTree(
  List<FolderTreeNode> roots,
  Set<String> expanded,
) {
  final result = <FolderTreeNode>[];
  void visit(FolderTreeNode node) {
    result.add(node);
    if (expanded.contains(node.folder.id)) {
      for (final child in node.children) {
        visit(child);
      }
    }
  }

  for (final root in roots) {
    visit(root);
  }
  return result;
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────

/// Build the breadcrumb path from root to [folderId].
List<FolderCrumb> buildBreadcrumbs(List<Folder> allFolders, String? folderId) {
  if (folderId == null) return [];
  final map = {for (final f in allFolders) f.id: f};
  final crumbs = <FolderCrumb>[];
  String? current = folderId;
  int guard = 0;
  while (current != null && guard++ < 50) {
    final folder = map[current];
    if (folder == null) break;
    crumbs.insert(0, FolderCrumb(id: folder.id, name: folder.name));
    current = folder.parentId;
  }
  return crumbs;
}

// ── Nesting depth ─────────────────────────────────────────────────────────────

/// Count how deeply nested [folderId] is (0 = root level).
int folderDepth(List<Folder> allFolders, String folderId) {
  final map = {for (final f in allFolders) f.id: f};
  int depth = 0;
  String? current = map[folderId]?.parentId;
  int guard = 0;
  while (current != null && guard++ < 50) {
    depth++;
    current = map[current]?.parentId;
  }
  return depth;
}

// ── Soft cap ──────────────────────────────────────────────────────────────────

const int kFolderDepthSoftCap = 12;

bool exceedsSoftCap(List<Folder> allFolders, String folderId) =>
    folderDepth(allFolders, folderId) >= kFolderDepthSoftCap;
