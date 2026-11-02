// lib/features/notes/graph/graph_model.dart
// Pure graph-building logic (no Flutter): node/edge construction, vault
// omission, >2,000-node clustering, local subgraphs and filters.
// Spec §4.4.4 (FR-NT-3).

import 'dart:ui' show Offset;

/// Soft cap: above this many notes the graph clusters by folder.
const int kGraphSoftCap = 2000;

class GraphNoteRef {
  const GraphNoteRef({
    required this.id,
    required this.title,
    this.folderId,
    this.vaultId,
    this.tags = const {},
  });
  final String id;
  final String title;
  final String? folderId;
  final String? vaultId;
  final Set<String> tags;
}

enum GraphNodeKind { note, cluster, lockedPlaceholder }

class GraphNode {
  const GraphNode({
    required this.id,
    required this.label,
    required this.kind,
    this.inCount = 0,
    this.count = 1,
    this.folderId,
    this.tags = const {},
    this.position = Offset.zero,
  });

  final String id;
  final String label;
  final GraphNodeKind kind;
  final int inCount;

  /// Notes represented (1 for a note, N for a folder cluster).
  final int count;
  final String? folderId;
  final Set<String> tags;
  final Offset position;

  GraphNode copyWith({int? inCount, Offset? position}) => GraphNode(
    id: id,
    label: label,
    kind: kind,
    inCount: inCount ?? this.inCount,
    count: count,
    folderId: folderId,
    tags: tags,
    position: position ?? this.position,
  );
}

class GraphEdge {
  const GraphEdge({required this.from, required this.to});
  final String from;
  final String to;
}

class GraphData {
  const GraphData({
    required this.nodes,
    required this.edges,
    this.clustered = false,
  });
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final bool clustered;

  Set<String> neighboursOf(String id) => {
    for (final e in edges)
      if (e.from == id) e.to else if (e.to == id) e.from,
  };

  Set<String> get orphanIds {
    final linked = {
      for (final e in edges) ...[e.from, e.to],
    };
    return {
      for (final n in nodes)
        if (!linked.contains(n.id)) n.id,
    };
  }
}

const lockedPlaceholderLabel = '🔒 Locked note';

/// Builds the global graph.
///
/// * Notes in a locked vault are omitted entirely.
/// * A link from a visible note to a locked-vault note becomes a generic
///   "🔒 Locked note" placeholder node (one per link target, no title leaks).
/// * Above [cap] visible notes, notes collapse into one node per folder.
GraphData buildGraph({
  required List<GraphNoteRef> notes,
  required Map<String, Set<String>> links,
  required bool Function(String vaultId) isVaultLocked,
  Map<String, String> folderNames = const {},
  int cap = kGraphSoftCap,
}) {
  final visible = <GraphNoteRef>[];
  final lockedIds = <String>{};
  for (final n in notes) {
    if (n.vaultId != null && isVaultLocked(n.vaultId!)) {
      lockedIds.add(n.id);
    } else {
      visible.add(n);
    }
  }
  final visibleIds = {for (final n in visible) n.id};

  // Links, with locked targets mapped to opaque placeholders.
  final edges = <GraphEdge>[];
  final placeholders = <String>{};
  for (final entry in links.entries) {
    if (!visibleIds.contains(entry.key)) continue;
    for (final dst in entry.value) {
      if (visibleIds.contains(dst)) {
        edges.add(GraphEdge(from: entry.key, to: dst));
      } else if (lockedIds.contains(dst)) {
        final ph = 'locked:$dst';
        placeholders.add(ph);
        edges.add(GraphEdge(from: entry.key, to: ph));
      }
    }
  }

  if (visible.length > cap) {
    return _cluster(visible, edges, placeholders, folderNames);
  }

  final inCounts = <String, int>{};
  for (final e in edges) {
    inCounts[e.to] = (inCounts[e.to] ?? 0) + 1;
  }
  final nodes = <GraphNode>[
    for (final n in visible)
      GraphNode(
        id: n.id,
        label: n.title.isEmpty ? 'Untitled' : n.title,
        kind: GraphNodeKind.note,
        inCount: inCounts[n.id] ?? 0,
        folderId: n.folderId,
        tags: n.tags,
      ),
    for (final ph in placeholders)
      GraphNode(
        id: ph,
        label: lockedPlaceholderLabel,
        kind: GraphNodeKind.lockedPlaceholder,
        inCount: inCounts[ph] ?? 0,
      ),
  ];
  return GraphData(nodes: nodes, edges: edges);
}

GraphData _cluster(
  List<GraphNoteRef> visible,
  List<GraphEdge> edges,
  Set<String> placeholders,
  Map<String, String> folderNames,
) {
  String clusterOf(String? folderId) => 'cluster:${folderId ?? 'inbox'}';
  final noteCluster = {for (final n in visible) n.id: clusterOf(n.folderId)};
  final counts = <String, int>{};
  final folderOf = <String, String?>{};
  for (final n in visible) {
    final c = clusterOf(n.folderId);
    counts[c] = (counts[c] ?? 0) + 1;
    folderOf[c] = n.folderId;
  }

  final seen = <String>{};
  final out = <GraphEdge>[];
  for (final e in edges) {
    final a = noteCluster[e.from];
    final b = noteCluster[e.to] ?? e.to; // placeholders stay as-is
    if (a == null || a == b) continue;
    if (seen.add('$a>$b')) out.add(GraphEdge(from: a, to: b));
  }
  final inCounts = <String, int>{};
  for (final e in out) {
    inCounts[e.to] = (inCounts[e.to] ?? 0) + 1;
  }
  return GraphData(
    clustered: true,
    edges: out,
    nodes: [
      for (final c in counts.entries)
        GraphNode(
          id: c.key,
          label:
              '${folderNames[folderOf[c.key]] ?? (folderOf[c.key] == null ? 'Inbox' : 'Folder')} (${c.value})',
          kind: GraphNodeKind.cluster,
          count: c.value,
          inCount: inCounts[c.key] ?? 0,
          folderId: folderOf[c.key],
        ),
      for (final ph in placeholders)
        GraphNode(
          id: ph,
          label: lockedPlaceholderLabel,
          kind: GraphNodeKind.lockedPlaceholder,
          inCount: inCounts[ph] ?? 0,
        ),
    ],
  );
}

/// Subgraph within [depth] hops (1–3) of [focusId], ignoring edge direction.
GraphData localSubgraph(GraphData data, String focusId, int depth) {
  final d = depth.clamp(1, 3);
  final adjacency = <String, Set<String>>{};
  for (final e in data.edges) {
    adjacency.putIfAbsent(e.from, () => {}).add(e.to);
    adjacency.putIfAbsent(e.to, () => {}).add(e.from);
  }
  final keep = <String>{focusId};
  var frontier = <String>{focusId};
  for (var i = 0; i < d; i++) {
    final next = <String>{};
    for (final id in frontier) {
      for (final nb in adjacency[id] ?? const <String>{}) {
        if (keep.add(nb)) next.add(nb);
      }
    }
    frontier = next;
  }
  return GraphData(
    clustered: data.clustered,
    nodes: [
      for (final n in data.nodes)
        if (keep.contains(n.id)) n,
    ],
    edges: [
      for (final e in data.edges)
        if (keep.contains(e.from) && keep.contains(e.to)) e,
    ],
  );
}

/// Applies folder / tag / orphan-only filters. Edges between removed nodes
/// are dropped with them.
GraphData filterGraph(
  GraphData data, {
  String? folderId,
  String? tag,
  bool orphansOnly = false,
}) {
  final orphans = data.orphanIds;
  final nodes = [
    for (final n in data.nodes)
      if ((folderId == null || n.folderId == folderId) &&
          (tag == null || n.tags.contains(tag)) &&
          (!orphansOnly || orphans.contains(n.id)))
        n,
  ];
  final ids = {for (final n in nodes) n.id};
  return GraphData(
    clustered: data.clustered,
    nodes: nodes,
    edges: [
      for (final e in data.edges)
        if (ids.contains(e.from) && ids.contains(e.to)) e,
    ],
  );
}
