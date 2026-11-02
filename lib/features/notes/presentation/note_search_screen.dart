// lib/features/notes/presentation/note_search_screen.dart
// Spec §4.7: keyword search (FTS5). The "Meaning" (hybrid) toggle only
// appears when an embedding model is bundled — currently it is not (FTS-only
// fallback), so it is hidden.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';
import 'package:streakin/features/notes/search/embedding_pipeline.dart';

/// Whether semantic search can run. False until a model is bundled.
final embeddingModelProvider = Provider<EmbeddingModel>(
  (ref) => const NoEmbeddingModel(),
);

class NoteSearchScreen extends ConsumerStatefulWidget {
  const NoteSearchScreen({super.key});

  @override
  ConsumerState<NoteSearchScreen> createState() => _NoteSearchScreenState();
}

class _NoteSearchScreenState extends ConsumerState<NoteSearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<FtsResult> _results = const [];
  bool _meaning = false; // per-session only
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(q));
  }

  Future<void> _run(String q) async {
    final fts = ref.read(ftsRepositoryStateProvider);
    if (q.trim().isEmpty || fts == null) {
      if (mounted) setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    final r = await fts.search(q);
    if (mounted) {
      setState(() {
        _results = r;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semantic = ref.watch(embeddingModelProvider).isAvailable;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search notes',
            border: InputBorder.none,
            hintStyle: TextStyle(color: colors.textMuted),
          ),
        ),
        actions: [
          if (semantic)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Meaning'),
                selected: _meaning,
                onSelected: (v) {
                  setState(() => _meaning = v);
                  _run(_ctrl.text);
                },
              ),
            ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _results.isEmpty
          ? Center(
              child: Text(
                _ctrl.text.isEmpty ? 'Type to search' : 'No matches',
                style: TextStyle(color: colors.textMuted),
              ),
            )
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  title: Text(r.title.isEmpty ? 'Untitled' : r.title),
                  subtitle: Text(
                    r.snippet.replaceAll('**', ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.push('/notes/${r.noteId}'),
                );
              },
            ),
    );
  }
}
