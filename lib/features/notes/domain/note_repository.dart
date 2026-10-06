// lib/features/notes/domain/note_repository.dart
// NoteRepository, AttachmentRepository, and FtsRepository interfaces.
// Implementations live in lib/features/notes/data/.

import 'dart:typed_data';

import 'package:streakin/features/notes/domain/attachment.dart';
import 'package:streakin/features/notes/domain/folder.dart';
import 'package:streakin/features/notes/domain/note.dart';

// ── FTS result ────────────────────────────────────────────────────────────────

class FtsResult {
  const FtsResult({
    required this.noteId,
    required this.title,
    required this.snippet,
    this.rank = 0.0,
  });

  final String noteId;
  final String title;
  final String snippet;
  final double rank;
}

// ── NoteRepository ────────────────────────────────────────────────────────────

abstract interface class NoteRepository {
  /// Stream of all non-deleted notes in [folderId] (null = root inbox).
  Stream<List<Note>> watchFolder(String? folderId);

  /// Stream of a single note (null when deleted or not found).
  Stream<Note?> watchNote(String id);

  /// Stream of all non-deleted folders.
  Stream<List<Folder>> watchFolders();

  /// Upsert a note. Rebuilds note_links and note_tags in the same transaction.
  Future<void> saveNote(Note note);

  /// Upsert a folder.
  Future<void> saveFolder(Folder folder);

  /// Move a note to a different folder.
  Future<void> moveNote(String noteId, String? targetFolderId);

  /// Move a folder to a different parent (null = root).
  Future<void> moveFolder(String folderId, String? targetParentId);

  /// Soft-delete a note.
  Future<void> softDeleteNote(String id);

  /// Soft-delete a folder and cascade soft-delete all notes within it.
  Future<void> softDeleteFolder(String id);

  /// Stream of all notes that contain a [[link]] pointing at [noteId].
  Stream<List<Note>> watchBacklinks(String noteId);

  /// Stream of all notes this note links to.
  Stream<List<Note>> watchOutgoingLinks(String noteId);

  /// Stream of all unique tags across all non-deleted notes.
  Stream<List<String>> watchTags();

  /// Stream of all non-deleted notes with [tag].
  Stream<List<Note>> watchNotesByTag(String tag);

  /// Fetch a single note by ID (returns null if not found / deleted).
  Future<Note?> getById(String id);

  /// Look up a note by its title (for wiki-link autocomplete + "create and link").
  Future<List<Note>> searchByTitle(String query);
}

// ── AttachmentRepository ──────────────────────────────────────────────────────

abstract interface class AttachmentRepository {
  /// Save attachment metadata + encrypted blob to FileStore.
  Future<void> saveAttachment(Attachment attachment, Uint8List encryptedBlob);

  /// Delete attachment metadata and encrypted blob.
  Future<void> deleteAttachment(String id);

  /// Load encrypted blob from FileStore.
  Future<Uint8List> loadBlob(String storageName);

  /// Check for an existing attachment with the same sha256 in the same note.
  Future<Attachment?> dedupeCheck(String sha256, String noteId);

  /// Stream of all attachments for a note.
  Stream<List<Attachment>> watchForNote(String noteId);

  /// Delete all orphan blobs (blobs without a DB row). Call on app startup.
  Future<void> orphanSweep();
}

// ── FtsRepository ─────────────────────────────────────────────────────────────

abstract interface class FtsRepository {
  /// Index (or re-index) a note in the FTS table.
  Future<void> indexNote(String noteId, String title, String plainText);

  /// Remove a note from the FTS index.
  Future<void> removeNote(String noteId);

  /// Full-text search. Optionally scoped to [folderId].
  Future<List<FtsResult>> search(String query, {String? folderId});
}
