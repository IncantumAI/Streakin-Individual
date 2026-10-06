// lib/features/notes/domain/dashboard_section_provider.dart
// DashboardSectionProvider interface — implemented by NotesDashboardProvider.
// Dashboard reads this interface; never imports notes internals directly.

/// A single recent note item for the dashboard widget.
class RecentNoteItem {
  const RecentNoteItem({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.folderName,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String? folderName;
}

/// A pinned note item for the dashboard widget.
class PinnedNoteItem {
  const PinnedNoteItem({
    required this.id,
    required this.title,
    this.folderName,
  });

  final String id;
  final String title;
  final String? folderName;
}

abstract class DashboardSectionProvider {
  /// Stream of the [limit] most recently edited non-vault notes.
  Stream<List<RecentNoteItem>> watchRecentNotes(int limit);

  /// Stream of all pinned non-vault notes.
  Stream<List<PinnedNoteItem>> watchPinnedNotes();
}
