// Track 4E: graph model — vault omission, locked placeholders, clustering,
// local subgraph, filters.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/graph/graph_model.dart';

GraphNoteRef _n(
  String id, {
  String? folder,
  String? vault,
  Set<String> tags = const {},
}) => GraphNoteRef(
  id: id,
  title: 'Note $id',
  folderId: folder,
  vaultId: vault,
  tags: tags,
);

void main() {
  bool locked(String _) => true;

  test('renders all non-vault notes and links', () {
    final g = buildGraph(
      notes: [_n('a'), _n('b'), _n('c')],
      links: {
        'a': {'b'},
        'b': {'c'},
      },
      isVaultLocked: locked,
    );
    expect(g.nodes.map((n) => n.id), containsAll(['a', 'b', 'c']));
    expect(g.edges.length, 2);
    expect(g.nodes.firstWhere((n) => n.id == 'b').inCount, 1);
  });

  test('locked-vault notes are omitted; links become generic placeholders', () {
    final g = buildGraph(
      notes: [
        _n('a'),
        _n('v', vault: 'vault1'),
      ],
      links: {
        'a': {'v'},
      },
      isVaultLocked: locked,
    );
    expect(g.nodes.any((n) => n.id == 'v'), isFalse);
    final ph = g.nodes.singleWhere(
      (n) => n.kind == GraphNodeKind.lockedPlaceholder,
    );
    expect(ph.label, lockedPlaceholderLabel);
    expect(ph.label.contains('Note v'), isFalse);
  });

  test('unlocked vault notes are shown', () {
    final g = buildGraph(
      notes: [
        _n('a'),
        _n('v', vault: 'vault1'),
      ],
      links: {
        'a': {'v'},
      },
      isVaultLocked: (_) => false,
    );
    expect(g.nodes.any((n) => n.id == 'v'), isTrue);
  });

  test('clusters by folder above the soft cap', () {
    final notes = [
      for (var i = 0; i < 2100; i++) _n('n$i', folder: i.isEven ? 'f1' : 'f2'),
    ];
    final g = buildGraph(
      notes: notes,
      links: {
        'n0': {'n1'},
      },
      isVaultLocked: locked,
      folderNames: {'f1': 'Work', 'f2': 'Home'},
    );
    expect(g.clustered, isTrue);
    expect(g.nodes.length, 2);
    expect(g.nodes.map((n) => n.count).reduce((a, b) => a + b), 2100);
    expect(g.edges.length, 1);
  });

  test('does not cluster at or below the cap', () {
    final g = buildGraph(
      notes: [for (var i = 0; i < 2000; i++) _n('n$i')],
      links: const {},
      isVaultLocked: locked,
    );
    expect(g.clustered, isFalse);
    expect(g.nodes.length, 2000);
  });

  test('local graph depth 1 shows only immediate neighbours', () {
    final g = buildGraph(
      notes: [_n('a'), _n('b'), _n('c'), _n('d')],
      links: {
        'a': {'b'},
        'b': {'c'},
        'c': {'d'},
      },
      isVaultLocked: locked,
    );
    final local = localSubgraph(g, 'b', 1);
    expect(local.nodes.map((n) => n.id).toSet(), {'a', 'b', 'c'});
    final deeper = localSubgraph(g, 'b', 2);
    expect(deeper.nodes.length, 4);
  });

  test('filters by folder, tag and orphans', () {
    final g = buildGraph(
      notes: [
        _n('a', folder: 'f1', tags: {'x'}),
        _n('b', folder: 'f2'),
        _n('c', folder: 'f1'),
      ],
      links: {
        'a': {'b'},
      },
      isVaultLocked: locked,
    );
    expect(filterGraph(g, folderId: 'f1').nodes.length, 2);
    expect(filterGraph(g, tag: 'x').nodes.single.id, 'a');
    expect(filterGraph(g, orphansOnly: true).nodes.single.id, 'c');
  });
}
