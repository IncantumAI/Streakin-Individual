// lib/features/notes/presentation/notes_routes.dart
// Notes GoRouter routes.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/features/notes/presentation/note_editor_screen.dart';

final List<RouteBase> notesRoutes = [
  GoRoute(
    path: '/notes',
    name: 'notes',
    // Notes list is rendered inline in the shell branch (NotesScreen).
    // Sub-routes push on top.
    builder: (context, state) => const _NotesShellPlaceholder(),
    routes: [
      GoRoute(
        path: ':noteId',
        name: 'note-editor',
        builder: (context, state) =>
            NoteEditorScreen(noteId: state.pathParameters['noteId']!),
      ),
    ],
  ),
];

/// This placeholder is never actually shown — the shell branch renders
/// NotesScreen directly. It exists so go_router has a builder for /notes.
class _NotesShellPlaceholder extends StatelessWidget {
  const _NotesShellPlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
