// lib/features/notes/graph/graph_screen.dart
// Spec §4.4.4 (FR-NT-3): global + local graph. Force-directed layout runs in
// a background isolate (killed when the screen is disposed); rendering is a
// CustomPainter inside an InteractiveViewer behind a RepaintBoundary.

import 'package:streakin/core/design/icons.dart';

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/application/vault_lock_hook.dart';
import 'package:streakin/features/notes/graph/graph_model.dart';

/// Labels are hidden below this zoom level (level-of-detail).
const double kGraphLabelZoom = 0.9;
const double _canvas = 2000;

class GraphScreen extends ConsumerStatefulWidget {
  /// When [focusNoteId] is set, shows the local graph around that note.
  const GraphScreen({this.focusNoteId, this.depth = 1, super.key});
  final String? focusNoteId;
  final int depth;

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen>
    with SingleTickerProviderStateMixin {
  GraphData _full = const GraphData(nodes: [], edges: []);
  GraphData _shown = const GraphData(nodes: [], edges: []);
  bool _loading = true;
  GraphNode? _selected;

  // Filters
  String? _folderFilter;
  String? _tagFilter;
  bool _orphansOnly = false;
  late int _depth;
  Map<String, String> _folderNames = {};
  List<String> _allTags = [];

  // Layout isolate
  Isolate? _isolate;
  ReceivePort? _port;
  int _layoutGeneration = 0;

  // Interaction
  final _transform = TransformationController();
  late final AnimationController _pulse;
  Offset? _doubleTapAt;

  @override
  void initState() {
    super.initState();
    _depth = widget.depth.clamp(1, 3);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _killLayout();
    _pulse.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _killLayout() {
    _layoutGeneration++;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
  }

  Future<void> _load() async {
    final repo = ref.read(noteRepositoryStateProvider);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final folders = await repo.watchFolders().first;
    final folderIds = <String?>[null, ...folders.map((f) => f.id)];
    final refs = <GraphNoteRef>[];
    for (final fid in folderIds) {
      for (final n in await repo.watchFolder(fid).first) {
        if (n.isDeleted) continue;
        refs.add(
          GraphNoteRef(
            id: n.id,
            title: n.title,
            folderId: n.folderId,
            vaultId: n.vaultId,
          ),
        );
      }
    }

    // Tags per note (for the tag filter).
    final tags = await repo.watchTags().first;
    final tagsByNote = <String, Set<String>>{};
    for (final t in tags) {
      for (final n in await repo.watchNotesByTag(t).first) {
        tagsByNote.putIfAbsent(n.id, () => {}).add(t);
      }
    }
    final withTags = [
      for (final r in refs)
        GraphNoteRef(
          id: r.id,
          title: r.title,
          folderId: r.folderId,
          vaultId: r.vaultId,
          tags: tagsByNote[r.id] ?? const {},
        ),
    ];

    final links = <String, Set<String>>{};
    for (final r in refs) {
      final out = await repo.watchOutgoingLinks(r.id).first;
      if (out.isNotEmpty) links[r.id] = out.map((l) => l.id).toSet();
    }

    _folderNames = {for (final f in folders) f.id: f.name};
    _allTags = tags;
    _full = buildGraph(
      notes: withTags,
      links: links,
      isVaultLocked: ref.read(isVaultLockedProvider),
      folderNames: _folderNames,
    );
    await _applyView();
  }

  /// Recomputes the visible subgraph (local focus + filters) and re-lays it out.
  Future<void> _applyView() async {
    var data = _full;
    if (widget.focusNoteId != null) {
      data = localSubgraph(data, widget.focusNoteId!, _depth);
    }
    data = filterGraph(
      data,
      folderId: _folderFilter,
      tag: _tagFilter,
      orphansOnly: _orphansOnly,
    );

    _killLayout();
    final gen = _layoutGeneration;
    final laid = await _runLayout(data);
    if (!mounted || gen != _layoutGeneration) return;
    setState(() {
      _shown = laid;
      _selected = null;
      _loading = false;
    });
  }

  Future<GraphData> _runLayout(GraphData data) async {
    if (data.nodes.isEmpty) return data;
    final port = ReceivePort();
    _port = port;
    final index = {
      for (var i = 0; i < data.nodes.length; i++) data.nodes[i].id: i,
    };
    final pairs = <int>[];
    for (final e in data.edges) {
      final a = index[e.from];
      final b = index[e.to];
      if (a != null && b != null) {
        pairs
          ..add(a)
          ..add(b);
      }
    }
    _isolate = await Isolate.spawn(
      _forceDirected,
      _LayoutMsg(
        count: data.nodes.length,
        edgePairs: pairs,
        sendPort: port.sendPort,
      ),
    );
    final result = await port.first as List<double>;
    _isolate?.kill();
    _isolate = null;
    return GraphData(
      clustered: data.clustered,
      edges: data.edges,
      nodes: [
        for (var i = 0; i < data.nodes.length; i++)
          data.nodes[i].copyWith(
            position: Offset(result[i * 2], result[i * 2 + 1]),
          ),
      ],
    );
  }

  void _select(GraphNode? node) {
    setState(() => _selected = node);
    // Reduced motion: no pulse, selection ring only.
    if (node != null && !MediaQuery.disableAnimationsOf(context)) {
      _pulse.forward(from: 0);
    }
  }

  GraphNode? _hit(Offset pos) {
    for (final n in _shown.nodes.reversed) {
      if ((pos - n.position).distance <= _nodeRadius(n)) return n;
    }
    return null;
  }

  void _open(GraphNode n) {
    if (n.kind == GraphNodeKind.note) context.push('/notes/${n.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLocal = widget.focusNoteId != null;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(isLocal ? 'Local graph' : 'Note Graph'),
        actions: [
          if (isLocal)
            PopupMenuButton<int>(
              tooltip: 'Depth',
              icon: const Icon(AppIcons.layersOutlined),
              onSelected: (d) {
                _depth = d;
                _applyView();
              },
              itemBuilder: (_) => [
                for (final d in [1, 2, 3])
                  CheckedPopupMenuItem(
                    value: d,
                    checked: d == _depth,
                    child: Text('Depth $d'),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            folders: _folderNames,
            tags: _allTags,
            folder: _folderFilter,
            tag: _tagFilter,
            orphansOnly: _orphansOnly,
            onFolder: (v) {
              _folderFilter = v;
              _applyView();
            },
            onTag: (v) {
              _tagFilter = v;
              _applyView();
            },
            onOrphans: (v) {
              _orphansOnly = v;
              _applyView();
            },
          ),
          if (_shown.clustered)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Large vault — showing folders as clusters',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ),
          Expanded(child: _body(colors)),
        ],
      ),
    );
  }

  Widget _body(AppColorTokens colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_shown.nodes.isEmpty) {
      return Center(
        child: Text(
          'No notes to show',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }
    final neighbours = _selected == null
        ? const <String>{}
        : _shown.neighboursOf(_selected!.id);
    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transform,
          boundaryMargin: const EdgeInsets.all(400),
          minScale: 0.1,
          maxScale: 5,
          child: GestureDetector(
            onTapUp: (d) => _select(_hit(d.localPosition)),
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: () {
              final n = _doubleTapAt == null ? null : _hit(_doubleTapAt!);
              if (n != null) _open(n);
            },
            child: RepaintBoundary(
              child: Semantics(
                label:
                    'Note graph with ${_shown.nodes.length} notes. '
                    'Tap a note for details, double-tap to open.',
                child: CustomPaint(
                  size: const Size(_canvas, _canvas),
                  painter: _GraphPainter(
                    data: _shown,
                    selected: _selected?.id,
                    neighbours: neighbours,
                    orphans: _shown.orphanIds,
                    colors: colors,
                    pulse: _pulse,
                    transform: _transform,
                  ),
                ),
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
              onOpen: _selected!.kind == GraphNodeKind.note
                  ? () => _open(_selected!)
                  : null,
              onClose: () => setState(() => _selected = null),
            ),
          ),
      ],
    );
  }
}

double _nodeRadius(GraphNode n) {
  final base = switch (n.kind) {
    GraphNodeKind.cluster => 14.0 + min(n.count, 200) * 0.1,
    _ => 8.0,
  };
  return (base + n.inCount * 2.0).clamp(8.0, 32.0);
}

// ── Filters ──────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.folders,
    required this.tags,
    required this.folder,
    required this.tag,
    required this.orphansOnly,
    required this.onFolder,
    required this.onTag,
    required this.onOrphans,
  });
  final Map<String, String> folders;
  final List<String> tags;
  final String? folder;
  final String? tag;
  final bool orphansOnly;
  final ValueChanged<String?> onFolder;
  final ValueChanged<String?> onTag;
  final ValueChanged<bool> onOrphans;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          DropdownButton<String?>(
            value: folder,
            hint: const Text('Folder'),
            items: [
              const DropdownMenuItem(child: Text('All folders')),
              for (final f in folders.entries)
                DropdownMenuItem(value: f.key, child: Text(f.value)),
            ],
            onChanged: onFolder,
          ),
          const SizedBox(width: 12),
          DropdownButton<String?>(
            value: tag,
            hint: const Text('Tag'),
            items: [
              const DropdownMenuItem(child: Text('All tags')),
              for (final t in tags)
                DropdownMenuItem(value: t, child: Text('#$t')),
            ],
            onChanged: onTag,
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Orphans only'),
            selected: orphansOnly,
            onSelected: onOrphans,
          ),
        ],
      ),
    );
  }
}

// ── Preview card ─────────────────────────────────────────────────────────────

class _NodePreviewCard extends StatelessWidget {
  const _NodePreviewCard({
    required this.node,
    required this.colors,
    required this.onOpen,
    required this.onClose,
  });
  final GraphNode node;
  final AppColorTokens colors;
  final VoidCallback? onOpen;
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
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onOpen != null)
              TextButton(onPressed: onOpen, child: const Text('Open')),
            IconButton(
              icon: Icon(AppIcons.close, color: colors.textMuted),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.data,
    required this.selected,
    required this.neighbours,
    required this.orphans,
    required this.colors,
    required this.pulse,
    required this.transform,
  }) : super(repaint: Listenable.merge([pulse, transform]));

  final GraphData data;
  final String? selected;
  final Set<String> neighbours;
  final Set<String> orphans;
  final AppColorTokens colors;
  final Animation<double> pulse;
  final TransformationController transform;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = selected != null;
    final nodeMap = {for (final n in data.nodes) n.id: n};
    final zoom = transform.value.getMaxScaleOnAxis();

    for (final e in data.edges) {
      final a = nodeMap[e.from];
      final b = nodeMap[e.to];
      if (a == null || b == null) continue;
      final active =
          selected != null && (e.from == selected || e.to == selected);
      canvas.drawLine(
        a.position,
        b.position,
        Paint()
          ..color = active ? colors.brand : colors.outline
          ..strokeWidth = active ? 2 : 1,
      );
    }

    for (final n in data.nodes) {
      final isSelected = n.id == selected;
      final highlighted = isSelected || neighbours.contains(n.id);
      final base = switch (n.kind) {
        GraphNodeKind.lockedPlaceholder => colors.textMuted,
        GraphNodeKind.cluster => colors.success,
        GraphNodeKind.note =>
          orphans.contains(n.id) ? colors.warning : colors.brand,
      };
      final alpha = dim && !highlighted ? 60 : 200;
      var r = _nodeRadius(n);
      // Select animation: 300 ms pulse on the selected node.
      if (isSelected) r += 6 * sin(pulse.value * pi);
      canvas.drawCircle(n.position, r, Paint()..color = base.withAlpha(alpha));
      if (isSelected) {
        canvas.drawCircle(
          n.position,
          r + 3,
          Paint()
            ..color = colors.brand
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
      if (zoom >= kGraphLabelZoom || highlighted) {
        final tp = TextPainter(
          text: TextSpan(
            text: n.label,
            style: TextStyle(color: colors.text, fontSize: 11),
          ),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);
        tp.paint(canvas, n.position + Offset(-tp.width / 2, r + 3));
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.selected != selected || old.data != data || old.colors != colors;
}

// ── Layout isolate ───────────────────────────────────────────────────────────

class _LayoutMsg {
  const _LayoutMsg({
    required this.count,
    required this.edgePairs,
    required this.sendPort,
  });
  final int count;
  final List<int> edgePairs; // [a0, b0, a1, b1, …]
  final SendPort sendPort;
}

/// Fruchterman–Reingold; returns [x0, y0, x1, y1, …].
void _forceDirected(_LayoutMsg msg) {
  final n = msg.count;
  const w = _canvas;
  const h = _canvas;
  final rng = Random(42);
  final pos = List.generate(
    n,
    (_) => Offset(rng.nextDouble() * w, rng.nextDouble() * h),
  );
  // Fewer iterations for big graphs keeps the isolate responsive.
  final iterations = n > 800 ? 25 : 60;
  final k = n > 400 ? 40.0 : 80.0;
  var temp = w / 4;

  for (var iter = 0; iter < iterations; iter++) {
    final disp = List.filled(n, Offset.zero);
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final delta = pos[i] - pos[j];
        final dist = delta.distance.clamp(0.01, double.infinity);
        final f = (delta / dist) * (k * k / dist);
        disp[i] += f;
        disp[j] -= f;
      }
    }
    for (var e = 0; e + 1 < msg.edgePairs.length; e += 2) {
      final a = msg.edgePairs[e];
      final b = msg.edgePairs[e + 1];
      final delta = pos[a] - pos[b];
      final dist = delta.distance.clamp(0.01, double.infinity);
      final force = delta / dist * (dist * dist / k);
      disp[a] -= force;
      disp[b] += force;
    }
    for (var i = 0; i < n; i++) {
      final d = disp[i];
      final dist = d.distance.clamp(0.01, double.infinity);
      final moved = pos[i] + d / dist * min(dist, temp);
      pos[i] = Offset(
        moved.dx.clamp(40.0, w - 40.0),
        moved.dy.clamp(40.0, h - 40.0),
      );
    }
    temp = max(temp * 0.92, 1.0);
  }
  msg.sendPort.send([
    for (final p in pos) ...[p.dx, p.dy],
  ]);
}
