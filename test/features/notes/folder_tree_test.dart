// test/features/notes/folder_tree_test.dart
// Unit tests for Track 3D: folder tree logic, breadcrumbs, depth checks.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/application/folder_tree.dart';
import 'package:streakin/features/notes/domain/folder.dart';

Folder _f(String id, {String? parentId, String name = '', int sort = 0}) =>
    Folder(
      id: id,
      parentId: parentId,
      name: name.isEmpty ? id : name,
      sortOrder: sort,
      hlc: '0-0-test',
    );

void main() {
  group('buildFolderTree', () {
    test('empty list produces empty tree', () {
      expect(buildFolderTree([]), isEmpty);
    });

    test('root folders have depth 0', () {
      final roots = buildFolderTree([_f('a'), _f('b')]);
      expect(roots.length, 2);
      expect(roots.every((n) => n.depth == 0), isTrue);
    });

    test('children are nested under correct parent', () {
      final tree = buildFolderTree([
        _f('root'),
        _f('child', parentId: 'root'),
        _f('grandchild', parentId: 'child'),
      ]);
      expect(tree.length, 1);
      expect(tree[0].children.length, 1);
      expect(tree[0].children[0].children.length, 1);
      expect(tree[0].children[0].children[0].folder.id, 'grandchild');
    });

    test('children have correct depth', () {
      final tree = buildFolderTree([
        _f('root'),
        _f('child', parentId: 'root'),
        _f('grandchild', parentId: 'child'),
      ]);
      expect(tree[0].depth, 0);
      expect(tree[0].children[0].depth, 1);
      expect(tree[0].children[0].children[0].depth, 2);
    });

    test('sort by name orders alphabetically', () {
      final tree = buildFolderTree([
        _f('z', name: 'Zebra'),
        _f('a', name: 'Apple'),
        _f('m', name: 'Mango'),
      ], sort: FolderSortMode.name);
      expect(tree.map((n) => n.folder.name).toList(), [
        'Apple',
        'Mango',
        'Zebra',
      ]);
    });

    test('sort by manual uses sortOrder', () {
      final tree = buildFolderTree([
        _f('b', sort: 2),
        _f('a'),
        _f('c', sort: 1),
      ]);
      expect(tree.map((n) => n.folder.id).toList(), ['a', 'c', 'b']);
    });

    test('maxDepth returns deepest nesting level', () {
      final tree = buildFolderTree([
        _f('root'),
        _f('child', parentId: 'root'),
        _f('grandchild', parentId: 'child'),
      ]);
      expect(tree[0].maxDepth, 2);
    });
  });

  group('flattenTree', () {
    test('collapsed root only shows roots', () {
      final tree = buildFolderTree([_f('root'), _f('child', parentId: 'root')]);
      final flat = flattenTree(tree, {});
      expect(flat.length, 1);
      expect(flat[0].folder.id, 'root');
    });

    test('expanding a node shows its children', () {
      final tree = buildFolderTree([
        _f('root'),
        _f('child', parentId: 'root'),
        _f('grandchild', parentId: 'child'),
      ]);
      // Expand root only
      final flat = flattenTree(tree, {'root'});
      expect(flat.length, 2);
      expect(flat[1].folder.id, 'child');
    });

    test('expanding multiple levels shows all visible nodes', () {
      final tree = buildFolderTree([
        _f('root'),
        _f('child', parentId: 'root'),
        _f('grandchild', parentId: 'child'),
      ]);
      final flat = flattenTree(tree, {'root', 'child'});
      expect(flat.length, 3);
    });
  });

  group('buildBreadcrumbs', () {
    test('null folderId returns empty list', () {
      expect(buildBreadcrumbs([], null), isEmpty);
    });

    test('root folder returns single crumb', () {
      final crumbs = buildBreadcrumbs([_f('root', name: 'Root')], 'root');
      expect(crumbs.length, 1);
      expect(crumbs[0].id, 'root');
      expect(crumbs[0].name, 'Root');
    });

    test('nested folder returns full path from root', () {
      final folders = [
        _f('root', name: 'Root'),
        _f('child', parentId: 'root', name: 'Child'),
        _f('grand', parentId: 'child', name: 'Grand'),
      ];
      final crumbs = buildBreadcrumbs(folders, 'grand');
      expect(crumbs.map((c) => c.name).toList(), ['Root', 'Child', 'Grand']);
    });

    test('unknown folderId returns empty list', () {
      expect(buildBreadcrumbs([_f('root')], 'missing'), isEmpty);
    });
  });

  group('folderDepth', () {
    test('root level folder has depth 0', () {
      expect(folderDepth([_f('root')], 'root'), 0);
    });

    test('one level deep has depth 1', () {
      final folders = [_f('root'), _f('child', parentId: 'root')];
      expect(folderDepth(folders, 'child'), 1);
    });

    test('three levels deep has depth 3', () {
      final folders = [
        _f('a'),
        _f('b', parentId: 'a'),
        _f('c', parentId: 'b'),
        _f('d', parentId: 'c'),
      ];
      expect(folderDepth(folders, 'd'), 3);
    });
  });

  group('exceedsSoftCap', () {
    List<Folder> deepFolders(int depth) {
      final list = [_f('f0')];
      for (int i = 1; i <= depth; i++) {
        list.add(_f('f$i', parentId: 'f${i - 1}'));
      }
      return list;
    }

    test('folder at depth 11 does not exceed soft cap (12)', () {
      final folders = deepFolders(11);
      expect(exceedsSoftCap(folders, 'f11'), isFalse);
    });

    test('folder at depth 12 exceeds soft cap', () {
      final folders = deepFolders(12);
      expect(exceedsSoftCap(folders, 'f12'), isTrue);
    });
  });
}
