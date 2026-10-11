import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note.dart';

class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});
  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  List<_GraphNode> _nodes = [];
  List<_GraphEdge> _edges = [];
  bool _loading = true;
  _GraphNode? _selected;
  Isolate? _isolate;
  ReceivePort? _port;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  @override
  void dispose() {
    _isolate?.kill();
    _port?.close();
    super.dispose();
  }

  Future<void> _build() async {
    final repo = ref.read(noteRepositoryStateProvider);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final allFolders = await repo.watchFolders().first;
    final folderIds = <String?>[null, ...allFolders.map((f) => f.id)];
    final notes = <Note>[];
    for (final fid in folderIds) {
      final batch = await repo.watchFolder(fid).first;
      notes.addAll(batch.where((n) => !n.isDeleted && n.vaultId == null));
    }

    const cap = 2000;
    final capped = notes.length > cap ? notes.sublist(0, cap) : notes;

    final linkMap = <String, Set<String>>{};
    for (final n in capped) {
      final links = await repo.watchOutgoingLinks(n.id).first;
      if (links.isNotEmpty) {
        linkMap[n.id] = links.map((l) => l.id).toSet();
      }
    }

    final nodes = capped.map((n) => _GraphNode(
          id: n.id,
          label: n.title.isEmpty ? 'Untitled' : n.title,
          inCount: 0,
        )).toList();

    for (final n in nodes) {
      final targets = linkMap[n.id] ?? {};
      for (final t in targets) {
        final ti = nodes.indexWhere((x) => x.id == t);
        if (ti >= 0) nodes[ti] = nodes[ti].copyWith(inCount: nodes[ti].inCount + 1);
      }
    }

    final edges = <_GraphEdge>[];
    for (final n in nodes) {
      for (final t in linkMap[n.id] ?? <String>{}) {
        if (nodes.any((x) => x.id == t)) {
          edges.add(_GraphEdge(from: n.id, to: t));
        }
      }
    }

    final layoutNodes = await _runLayout(nodes, edges);
    if (mounted) {
      setState(() {
        _nodes = layoutNodes;
        _edges = edges;
        _loading = false;
      });
    }
  }

  Future<List<_GraphNode>> _runLayout(
      List<_GraphNode> nodes, List<_GraphEdge> edges) async {
    if (nodes.isEmpty) return nodes;
    final port = ReceivePort();
    _port = port;
    _isolate = await Isolate.spawn(
      _forceDirected,
      _LayoutMsg(nodes: nodes, edges: edges, sendPort: port.sendPort),
    );
    final result = await port.first as List<_GraphNode>;
    _isolate?.kill();
    _isolate = null;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Note Graph'),
        actions: [
          if (_selected != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selected = null),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _nodes.isEmpty
              ? Center(
                  child: Text('No notes yet',
                      style: TextStyle(color: colors.textMuted)))
              : Stack(
                  children: [
                    InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(400),
                      minScale: 0.1,
                      maxScale: 5,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(2000, 2000),
                          painter: _GraphPainter(
                            nodes: _nodes,
                            edges: _edges,
                            selected: _selected?.id,
                            colors: colors,
                          ),
                          child: GestureDetector(
                            onTapUp: (d) => _onTap(d.localPosition),
                            child: const SizedBox(width: 2000, height: 2000),
                          ),
                        ),
                      ),
                    ),
                    if (_selected != null)
                      Positioned(
                        bottom: 24,
                        left: 16,
                        right: 16,
                        child: _NodePreviewCard(
                          node: _selected!,
                          colors: colors,
                          onOpen: () => context.push('/notes/${_selected!.id}'),
                          onClose: () => setState(() => _selected = null),
                        ),
                      ),
                  ],
                ),
    );
  }

  void _onTap(Offset pos) {
    for (final n in _nodes) {
      final r = _nodeRadius(n.inCount);
      if ((pos - n.position).distance <= r) {
        setState(() => _selected = n);
        return;
      }
    }
    setState(() => _selected = null);
  }
}

double _nodeRadius(int inCount) => (8.0 + inCount * 2.0).clamp(8.0, 28.0);

class _NodePreviewCard extends StatelessWidget {
  const _NodePreviewCard(
      {required this.node,
      required this.colors,
      required this.onOpen,
      required this.onClose});
  final _GraphNode node;
  final AppColorTokens colors;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                node.label,
                style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(onPressed: onOpen, child: const Text('Open')),
            IconButton(
                icon: Icon(Icons.close, color: colors.textMuted),
                onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(
      {required this.nodes,
      required this.edges,
      required this.selected,
      required this.colors});
  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final String? selected;
  final AppColorTokens colors;

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = colors.outline
      ..strokeWidth = 1;
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final e in edges) {
      final a = nodeMap[e.from];
      final b = nodeMap[e.to];
      if (a != null && b != null) {
        canvas.drawLine(a.position, b.position, edgePaint);
      }
    }

    for (final n in nodes) {
      final isSelected = n.id == selected;
      final r = _nodeRadius(n.inCount);
      final fill = Paint()
        ..color = isSelected ? colors.brand : colors.brand.withAlpha(160);
      canvas.drawCircle(n.position, r, fill);
      if (isSelected) {
        final ring = Paint()
          ..color = colors.brand
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(n.position, r + 3, ring);
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.selected != selected || old.nodes != nodes;
}

class _GraphNode {
  const _GraphNode(
      {required this.id,
      required this.label,
      required this.inCount,
      this.position = Offset.zero});
  final String id;
  final String label;
  final int inCount;
  final Offset position;

  _GraphNode copyWith({int? inCount, Offset? position}) => _GraphNode(
        id: id,
        label: label,
        inCount: inCount ?? this.inCount,
        position: position ?? this.position,
      );
}

class _GraphEdge {
  const _GraphEdge({required this.from, required this.to});
  final String from;
  final String to;
}

class _LayoutMsg {
  const _LayoutMsg(
      {required this.nodes, required this.edges, required this.sendPort});
  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final SendPort sendPort;
}

void _forceDirected(_LayoutMsg msg) {
  final nodes = msg.nodes;
  final edges = msg.edges;
  const w = 2000.0;
  const h = 2000.0;
  final rng = Random(42);

  var positions = List.generate(
    nodes.length,
    (_) => Offset(rng.nextDouble() * w, rng.nextDouble() * h),
  );

  const k = 80.0;
  const iterations = 60;
  double temp = w / 4;

  for (int iter = 0; iter < iterations; iter++) {
    final disp = List.filled(nodes.length, Offset.zero);

    for (int i = 0; i < nodes.length; i++) {
      for (int j = 0; j < nodes.length; j++) {
        if (i == j) continue;
        final delta = positions[i] - positions[j];
        final dist = delta.distance.clamp(0.01, double.infinity);
        disp[i] = disp[i] + (delta / dist) * (k * k / dist);
      }
    }

    final nodeMap = {for (int i = 0; i < nodes.length; i++) nodes[i].id: i};
    for (final e in edges) {
      final ai = nodeMap[e.from];
      final bi = nodeMap[e.to];
      if (ai == null || bi == null) continue;
      final delta = positions[ai] - positions[bi];
      final dist = delta.distance.clamp(0.01, double.infinity);
      final force = delta / dist * (dist * dist / k);
      disp[ai] = disp[ai] - force;
      disp[bi] = disp[bi] + force;
    }

    for (int i = 0; i < nodes.length; i++) {
      final d = disp[i];
      final dist = d.distance.clamp(0.01, double.infinity);
      positions[i] = positions[i] + d / dist * min(dist, temp);
      positions[i] = Offset(
        positions[i].dx.clamp(40.0, w - 40.0),
        positions[i].dy.clamp(40.0, h - 40.0),
      );
    }

    temp = max(temp * 0.92, 1.0);
  }

  final result = List.generate(
    nodes.length,
    (i) => nodes[i].copyWith(position: positions[i]),
  );
  msg.sendPort.send(result);
}
