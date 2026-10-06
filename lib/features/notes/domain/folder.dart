// lib/features/notes/domain/folder.dart
// Folder domain entity. Folders form an unlimited tree (parentId = null → root).


/// Breadcrumb item used to display folder path.
class FolderCrumb {
  const FolderCrumb({required this.id, required this.name});
  final String id;
  final String name;
}

class Folder {
  const Folder({
    required this.id,
    this.parentId,
    required this.name,
    this.iconIndex = 0,
    this.accentIndex = 0,
    this.vaultId,
    this.sortOrder = 0,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String? parentId;      // null = root level
  final String name;
  final int iconIndex;
  final int accentIndex;
  final String? vaultId;       // null = not vaulted
  final int sortOrder;
  final String hlc;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Folder copyWith({
    String? id,
    String? parentId,
    bool clearParentId = false,
    String? name,
    int? iconIndex,
    int? accentIndex,
    String? vaultId,
    bool clearVaultId = false,
    int? sortOrder,
    String? hlc,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Folder(
      id: id ?? this.id,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      name: name ?? this.name,
      iconIndex: iconIndex ?? this.iconIndex,
      accentIndex: accentIndex ?? this.accentIndex,
      vaultId: clearVaultId ? null : (vaultId ?? this.vaultId),
      sortOrder: sortOrder ?? this.sortOrder,
      hlc: hlc ?? this.hlc,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Folder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
