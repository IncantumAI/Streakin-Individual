// lib/features/notes/data/note_dao.dart
// Drift DAOs for notes, folders, links, tags, FTS, and date mentions.

import 'package:drift/drift.dart';
import 'package:streakin/core/storage/app_database.dart';

part 'note_dao.g.dart';

// ── NoteDao ───────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Notes, Folders, NoteLinks, NoteTags, DateMentions])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  // ── Notes ─────────────────────────────────────────────────────────────────

  Stream<List<Note>> watchFolder(String? folderId) {
    return (select(notes)
          ..where((n) => n.deletedAt.isNull())
          ..where((n) =>
              folderId == null ? n.folderId.isNull() : n.folderId.equals(folderId))
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Stream<Note?> watchNote(String id) {
    return (select(notes)
          ..where((n) => n.id.equals(id) & n.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<Note?> getById(String id) {
    return (select(notes)
          ..where((n) => n.id.equals(id) & n.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<List<Note>> searchByTitle(String query) {
    final q = '%${query.toLowerCase()}%';
    return (select(notes)
          ..where((n) => n.deletedAt.isNull() & n.title.lower().like(q))
          ..limit(20))
        .get();
  }

  Future<void> upsertNote(NotesCompanion companion) =>
      into(notes).insertOnConflictUpdate(companion);

  Future<void> softDeleteNote(String id, DateTime now) =>
      (update(notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(deletedAt: Value(now.toIso8601String())),
      );

  Future<void> softDeleteNotesInFolder(String folderId, DateTime now) =>
      (update(notes)..where((n) => n.folderId.equals(folderId))).write(
        NotesCompanion(deletedAt: Value(now.toIso8601String())),
      );

  Future<void> moveNote(String noteId, String? targetFolderId) =>
      (update(notes)..where((n) => n.id.equals(noteId))).write(
        NotesCompanion(folderId: Value(targetFolderId)),
      );

  // ── Folders ───────────────────────────────────────────────────────────────

  Stream<List<Folder>> watchFolders() =>
      (select(folders)..where((f) => f.deletedAt.isNull())
        ..orderBy([(f) => OrderingTerm.asc(f.sortOrder)]))
          .watch();

  Future<void> upsertFolder(FoldersCompanion companion) =>
      into(folders).insertOnConflictUpdate(companion);

  Future<void> softDeleteFolder(String id, DateTime now) =>
      (update(folders)..where((f) => f.id.equals(id))).write(
        FoldersCompanion(deletedAt: Value(now.toIso8601String())),
      );

  Future<void> moveFolder(String folderId, String? targetParentId) =>
      (update(folders)..where((f) => f.id.equals(folderId))).write(
        FoldersCompanion(parentId: Value(targetParentId)),
      );

  // ── NoteLinks ─────────────────────────────────────────────────────────────

  /// Delete all outgoing links from [srcNoteId] then re-insert.
  Future<void> rebuildLinks(
    String srcNoteId,
    List<NoteLinksCompanion> newLinks,
  ) async {
    await (delete(noteLinks)
          ..where((l) => l.srcNoteId.equals(srcNoteId)))
        .go();
    if (newLinks.isNotEmpty) {
      await batch((b) => b.insertAll(noteLinks, newLinks));
    }
  }

  Stream<List<Note>> watchBacklinks(String dstNoteId) {
    final query = select(notes).join([
      innerJoin(noteLinks, noteLinks.srcNoteId.equalsExp(notes.id)),
    ])
      ..where(noteLinks.dstNoteId.equals(dstNoteId) & notes.deletedAt.isNull());
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(notes)).toList(),
        );
  }

  Stream<List<Note>> watchOutgoingLinks(String srcNoteId) {
    final query = select(notes).join([
      innerJoin(noteLinks, noteLinks.dstNoteId.equalsExp(notes.id)),
    ])
      ..where(noteLinks.srcNoteId.equals(srcNoteId) & notes.deletedAt.isNull());
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(notes)).toList(),
        );
  }

  // ── NoteTags ──────────────────────────────────────────────────────────────

  Future<void> rebuildTags(
    String noteId,
    List<NoteTagsCompanion> newTags,
  ) async {
    await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
    if (newTags.isNotEmpty) {
      await batch((b) => b.insertAll(noteTags, newTags));
    }
  }

  Stream<List<String>> watchTags() {
    final q = selectOnly(noteTags)..addColumns([noteTags.tag])..groupBy([noteTags.tag]);
    return q.watch().map((rows) => rows.map((r) => r.read(noteTags.tag)!).toList());
  }

  Stream<List<Note>> watchNotesByTag(String tag) {
    final query = select(notes).join([
      innerJoin(noteTags, noteTags.noteId.equalsExp(notes.id)),
    ])
      ..where(noteTags.tag.equals(tag) & notes.deletedAt.isNull());
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(notes)).toList(),
        );
  }

  // ── DateMentions ──────────────────────────────────────────────────────────

  Future<void> rebuildDateMentions(
    String noteId,
    List<DateMentionsCompanion> newMentions,
  ) async {
    await (delete(dateMentions)..where((d) => d.noteId.equals(noteId))).go();
    if (newMentions.isNotEmpty) {
      await batch((b) => b.insertAll(dateMentions, newMentions));
    }
  }

  Stream<List<DateMention>> watchDateMentionsInRange(
      String startIso, String endIso) {
    return (select(dateMentions)
          ..where((d) =>
              d.startsAt.isBiggerOrEqualValue(startIso) &
              d.startsAt.isSmallerOrEqualValue(endIso)))
        .watch();
  }
}

// ── AttachmentDao ─────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Attachments])
class AttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentDaoMixin {
  AttachmentDao(super.db);

  Future<void> insert(AttachmentsCompanion c) =>
      into(attachments).insert(c);

  Future<void> delete_(String id) =>
      (delete(attachments)..where((a) => a.id.equals(id))).go();

  Future<Attachment?> findBySha256AndNote(String sha256, String noteId) =>
      (select(attachments)
            ..where((a) => a.sha256.equals(sha256) & a.noteId.equals(noteId)))
          .getSingleOrNull();

  Stream<List<Attachment>> watchForNote(String noteId) =>
      (select(attachments)..where((a) => a.noteId.equals(noteId))).watch();

  /// Returns all storage names still referenced in the DB.
  Future<List<String>> allStorageNames() =>
      (selectOnly(attachments)..addColumns([attachments.storageName]))
          .get()
          .then((rows) => rows.map((r) => r.read(attachments.storageName)!).toList());

  /// Returns the storageName(s) for a specific attachment id.
  Future<List<String>> allStorageNamesForId(String id) =>
      (selectOnly(attachments)
            ..addColumns([attachments.storageName])
            ..where(attachments.id.equals(id)))
          .get()
          .then((rows) => rows.map((r) => r.read(attachments.storageName)!).toList());
}

// ── NoteFtsDao ────────────────────────────────────────────────────────────────

/// Raw FTS5 operations via customStatement / customSelect.
class NoteFtsDao {
  NoteFtsDao(this._db);
  final AppDatabase _db;

  Future<void> index(String noteId, String title, String plainText) async {
    // Delete existing entry first (re-index support).
    await _db.customStatement(
      'DELETE FROM note_fts WHERE rowid = (SELECT rowid FROM notes WHERE id = ?)',
      [noteId],
    );
    await _db.customStatement(
      'INSERT INTO note_fts(rowid, title, plain_text) '
      'SELECT rowid, ?, ? FROM notes WHERE id = ?',
      [title, plainText, noteId],
    );
  }

  Future<void> remove(String noteId) async {
    await _db.customStatement(
      'DELETE FROM note_fts WHERE rowid = (SELECT rowid FROM notes WHERE id = ?)',
      [noteId],
    );
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    String? folderId,
  }) async {
    final q = '${query.trim()}*';
    final variables = <Variable<Object>>[
      Variable.withString(q),
      if (folderId != null) Variable.withString(folderId),
    ];
    final rows = await _db.customSelect(
      'SELECT n.id, n.title, snippet(note_fts, 1, "**", "**", "…", 20) AS snip, '
      'note_fts.rank AS rank '
      'FROM note_fts '
      'JOIN notes n ON note_fts.rowid = n.rowid '
      'WHERE note_fts MATCH ? '
      '${folderId != null ? "AND n.folder_id = ? " : ""}'
      'AND n.deleted_at IS NULL '
      'ORDER BY note_fts.rank '
      'LIMIT 50',
      variables: variables,
    ).get();
    return rows.map((r) => r.data).toList();
  }
}
