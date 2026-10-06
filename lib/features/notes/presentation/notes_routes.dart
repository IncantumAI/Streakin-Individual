// lib/features/notes/presentation/notes_routes.dart
// Notes GoRouter routes — wired into the app shell in Track 3C.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final List<RouteBase> notesRoutes = [
  GoRoute(
    path: '/notes',
    name: 'notes',
    builder: (context, state) => const _NotesPlaceholder(),
    routes: [
      GoRoute(
        path: ':noteId',
        name: 'note-editor',
        builder: (context, state) => _NoteEditorPlaceholder(
          noteId: state.pathParameters['noteId']!,
        ),
      ),
    ],
  ),
];

// ── Placeholder screens (replaced in Track 3C) ────────────────────────────────

class _NotesPlaceholder extends StatelessWidget {
  const _NotesPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Notes — coming in Track 3C')),
      );
}

class _NoteEditorPlaceholder extends StatelessWidget {
  const _NoteEditorPlaceholder({required this.noteId});
  final String noteId;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: Center(child: Text('Editor for note $noteId — Track 3C')),
      );
}
