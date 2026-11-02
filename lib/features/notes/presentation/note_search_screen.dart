// lib/features/notes/presentation/note_search_screen.dart
// Spec §4.7: keyword search (FTS5). The "Meaning" (hybrid) toggle only
// appears when an embedding model is bundled — currently it is not (FTS-only
// fallback), so it is hidden.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';
import 'package:streakin/features/notes/search/embedding_pipeline.dart';
import 'package:streakin/shared/widgets/widgets.dart';

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
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpace.md),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (q) {
              setState(() {});
              _onChanged(q);
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search notes',
              prefixIcon: const Icon(AppIcons.search, size: AppSizes.iconMd),
              isDense: true,
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(AppIcons.close, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() {});
                        _run('');
                      },
                    ),
            ),
          ),
        ),
        actions: [
          if (semantic)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
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
          ? const SkeletonList(count: 4, showLeading: false)
          : _results.isEmpty
          ? (_ctrl.text.isEmpty
                ? const EmptyState(
                    icon: AppIcons.emptySearch,
                    title: 'Search your notes',
                    message: 'Find words across titles and content.',
                  )
                : EmptyState(
                    icon: AppIcons.emptySearch,
                    title: 'No matches',
                    message: 'Nothing found for “${_ctrl.text.trim()}”.',
                  ))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpace.lg),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
              itemBuilder: (_, i) {
                final r = _results[i];
                return StaggeredEntrance(
                  index: i,
                  child: AppCard(
                    onTap: () => context.push('/notes/${r.noteId}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title.isEmpty ? 'Untitled' : r.title,
                          style: context.text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        _Snippet(text: r.snippet),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Renders an FTS snippet, highlighting `**matched**` segments.
class _Snippet extends StatelessWidget {
  const _Snippet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = context.text.bodySmall!;
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? base.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                      backgroundColor: c.brandSubtle,
                    )
                  : base,
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
