// lib/features/notes/application/note_providers.dart
// Riverpod providers for the notes feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/features/notes/application/folder_tree.dart';
import 'package:streakin/features/notes/domain/attachment.dart';
import 'package:streakin/features/notes/domain/folder.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

// ── Repository state (set by SessionScope after DB opens) ─────────────────────

class _NoteRepositoryNotifier extends Notifier<NoteRepository?> {
  @override
  NoteRepository? build() => null;
  void set(NoteRepository repo) => state = repo;
  void clear() => state = null;
}

final noteRepositoryStateProvider =
    NotifierProvider<_NoteRepositoryNotifier, NoteRepository?>(
        _NoteRepositoryNotifier.new);

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) {
    throw StateError('noteRepositoryProvider: SessionScope has not set the repository yet.');
  }
  return repo;
});

// ── AttachmentRepository ──────────────────────────────────────────────────────

class _AttachmentRepositoryNotifier extends Notifier<AttachmentRepository?> {
  @override
  AttachmentRepository? build() => null;
  void set(AttachmentRepository repo) => state = repo;
  void clear() => state = null;
}

final attachmentRepositoryStateProvider =
    NotifierProvider<_AttachmentRepositoryNotifier, AttachmentRepository?>(
        _AttachmentRepositoryNotifier.new);

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final repo = ref.watch(attachmentRepositoryStateProvider);
  if (repo == null) {
    throw StateError('attachmentRepositoryProvider: SessionScope has not set the repository yet.');
  }
  return repo;
});

// ── FtsRepository ─────────────────────────────────────────────────────────────

class _FtsRepositoryNotifier extends Notifier<FtsRepository?> {
  @override
  FtsRepository? build() => null;
  void set(FtsRepository repo) => state = repo;
  void clear() => state = null;
}

final ftsRepositoryStateProvider =
    NotifierProvider<_FtsRepositoryNotifier, FtsRepository?>(
        _FtsRepositoryNotifier.new);

// ── Notes in a folder ─────────────────────────────────────────────────────────

final notesInFolderProvider =
    StreamProvider.family<List<Note>, String?>((ref, folderId) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchFolder(folderId);
});

// ── Single note ───────────────────────────────────────────────────────────────

final noteProvider = StreamProvider.family<Note?, String>((ref, id) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchNote(id);
});

// ── Folder tree ───────────────────────────────────────────────────────────────

final foldersProvider = StreamProvider<List<Folder>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchFolders();
});

// ── Tags ──────────────────────────────────────────────────────────────────────

final allTagsProvider = StreamProvider<List<String>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchTags();
});

final notesByTagProvider =
    StreamProvider.family<List<Note>, String>((ref, tag) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchNotesByTag(tag);
});

// ── Backlinks ─────────────────────────────────────────────────────────────────

final backlinksProvider =
    StreamProvider.family<List<Note>, String>((ref, noteId) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchBacklinks(noteId);
});

final outgoingLinksProvider =
    StreamProvider.family<List<Note>, String>((ref, noteId) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchOutgoingLinks(noteId);
});

// ── Attachments for a note ────────────────────────────────────────────────────

final noteAttachmentsProvider =
    StreamProvider.family<List<Attachment>, String>((ref, noteId) {
  final repo = ref.watch(attachmentRepositoryProvider);
  return repo.watchForNote(noteId);
});

// ── Active folder filter (UI state) ──────────────────────────────────────────

class _ActiveFolderNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final activeFolderIdProvider =
    NotifierProvider<_ActiveFolderNotifier, String?>(_ActiveFolderNotifier.new);

// ── Active tag filter (UI state) ─────────────────────────────────────────────

class _ActiveTagNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? tag) => state = tag;
}

final activeTagFilterProvider =
    NotifierProvider<_ActiveTagNotifier, String?>(_ActiveTagNotifier.new);

// ── Folder sort mode (UI state) ───────────────────────────────────────────────

class _FolderSortNotifier extends Notifier<FolderSortMode> {
  @override
  FolderSortMode build() => FolderSortMode.manual;
  void set(FolderSortMode mode) => state = mode;
}

final folderSortModeProvider =
    NotifierProvider<_FolderSortNotifier, FolderSortMode>(_FolderSortNotifier.new);

// ── Expanded folder IDs (UI state) ────────────────────────────────────────────

class _ExpandedFoldersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    final current = Set<String>.from(state);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = current;
  }

  void expand(String id) {
    if (!state.contains(id)) state = {...state, id};
  }

  void collapse(String id) {
    if (state.contains(id)) state = state.difference({id});
  }
}

final expandedFolderIdsProvider =
    NotifierProvider<_ExpandedFoldersNotifier, Set<String>>(
        _ExpandedFoldersNotifier.new);
