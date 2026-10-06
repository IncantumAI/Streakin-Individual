// lib/features/notes/application/notes_dashboard_provider.dart
// NotesDashboardProvider — implements DashboardSectionProvider.
// Feeds the dashboard widget with recent + pinned notes.

import 'package:streakin/features/notes/domain/dashboard_section_provider.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

class NotesDashboardProvider implements DashboardSectionProvider {
  NotesDashboardProvider(this._repo);
  final NoteRepository _repo;

  @override
  Stream<List<RecentNoteItem>> watchRecentNotes(int limit) {
    // Watch root inbox + all folders for non-vault, non-deleted notes,
    // sort by updatedAt desc, take [limit].
    // For now, watch root inbox only — Track 3D will add cross-folder query.
    return _repo.watchFolder(null).map((notes) {
      final sorted = notes
          .where((n) => n.vaultId == null && !n.isDeleted)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sorted.take(limit).map((n) => RecentNoteItem(
            id: n.id,
            title: n.title.isEmpty ? 'Untitled' : n.title,
            updatedAt: n.updatedAt,
          )).toList();
    });
  }

  @override
  Stream<List<PinnedNoteItem>> watchPinnedNotes() {
    return _repo.watchFolder(null).map((notes) {
      return notes
          .where((n) => n.isPinned && n.vaultId == null && !n.isDeleted)
          .map((n) => PinnedNoteItem(
                id: n.id,
                title: n.title.isEmpty ? 'Untitled' : n.title,
              ))
          .toList();
    });
  }
}
