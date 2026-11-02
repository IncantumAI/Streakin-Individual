// lib/features/notes/application/notes_dashboard_provider.dart
// NotesDashboardProvider — implements DashboardSectionProvider.
// Feeds the dashboard with recent + pinned notes across ALL folders.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/dashboard_section_provider.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

class NotesDashboardProvider implements DashboardSectionProvider {
  NotesDashboardProvider(this._repo);
  final NoteRepository _repo;

  @override
  Stream<List<RecentNoteItem>> watchRecentNotes(int limit) {
    // Combine root inbox + all sub-folders by watching folders stream.
    // Simplification: scan all non-deleted notes via watchFolder(null) (root inbox).
    // Full cross-folder search requires a dedicated DAO query — added here.
    return _repo.watchFolder(null).asyncExpand((rootNotes) async* {
      // Also fetch notes from all known folders.
      final allFolders = await _repo.watchFolders().first;
      final allNotes = List.of(rootNotes);
      for (final folder in allFolders) {
        final folderNotes = await _repo.watchFolder(folder.id).first;
        allNotes.addAll(folderNotes);
      }
      final filtered =
          allNotes.where((n) => n.vaultId == null && !n.isDeleted).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      yield filtered
          .take(limit)
          .map(
            (n) => RecentNoteItem(
              id: n.id,
              title: n.title.isEmpty ? 'Untitled' : n.title,
              updatedAt: n.updatedAt,
            ),
          )
          .toList();
    });
  }

  @override
  Stream<List<PinnedNoteItem>> watchPinnedNotes() {
    return _repo.watchFolder(null).asyncExpand((rootNotes) async* {
      final allFolders = await _repo.watchFolders().first;
      final allNotes = List.of(rootNotes);
      for (final folder in allFolders) {
        final folderNotes = await _repo.watchFolder(folder.id).first;
        allNotes.addAll(folderNotes);
      }
      yield allNotes
          .where((n) => n.isPinned && n.vaultId == null && !n.isDeleted)
          .map(
            (n) => PinnedNoteItem(
              id: n.id,
              title: n.title.isEmpty ? 'Untitled' : n.title,
            ),
          )
          .toList();
    });
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

final recentNotesProvider = StreamProvider.family<List<RecentNoteItem>, int>((
  ref,
  limit,
) {
  final repo = ref.watch(noteRepositoryProvider);
  return NotesDashboardProvider(repo).watchRecentNotes(limit);
});

final pinnedNotesProvider = StreamProvider<List<PinnedNoteItem>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  return NotesDashboardProvider(repo).watchPinnedNotes();
});
