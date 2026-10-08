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
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchFolder(folderId).handleError(
      (_) => <Note>[],
      test: (e) => e.toString().contains('SqliteException') ||
          e.toString().contains('database_closed'));
});

// ── Single note ───────────────────────────────────────────────────────────────

final noteProvider = StreamProvider.family<Note?, String>((ref, id) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  // Handle SqliteException gracefully — repo may be cleared mid-stream
  // when SessionScope disposes (lock/sign-out). Return null instead of
  // letting the exception escape to the root zone.
  return repo.watchNote(id).handleError((e) => null,
      test: (e) => e.toString().contains('SqliteException') ||
          e.toString().contains('database_closed'));
});

// ── Folder tree ───────────────────────────────────────────────────────────────

final foldersProvider = StreamProvider<List<Folder>>((ref) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchFolders().handleError(
      (_) => <Folder>[],
      test: (e) => e.toString().contains('SqliteException') ||
          e.toString().contains('database_closed'));
});

// ── Tags ──────────────────────────────────────────────────────────────────────

final allTagsProvider = StreamProvider<List<String>>((ref) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchTags().handleError(
      (_) => <String>[],
      test: (e) => e.toString().contains('SqliteException') ||
          e.toString().contains('database_closed'));
});

final notesByTagProvider =
    StreamProvider.family<List<Note>, String>((ref, tag) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchNotesByTag(tag).handleError(
      (_) => <Note>[],
      test: (e) => e.toString().contains('SqliteException') ||
          e.toString().contains('database_closed'));
});

// ── Backlinks ─────────────────────────────────────────────────────────────────

final backlinksProvider =
    StreamProvider.family<List<Note>, String>((ref, noteId) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchBacklinks(noteId).handleError(
      (_) => <Note>[],
      test: (e) => e.toString().contains('SqliteException') ||
          e.toString().contains('database_closed'));
});

final outgoingLinksProvider =
    StreamProvider.family<List<Note>, String>((ref, noteId) {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchOutgoingLinks(noteId).handleError(
      (_) => <Note>[],
      test: (e) => e.toString().contains('SqliteException') ||
          e.toString().contains('database_closed'));
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
