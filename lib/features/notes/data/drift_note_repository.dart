// lib/features/notes/data/drift_note_repository.dart
// Drift implementation of NoteRepository, AttachmentRepository, FtsRepository.
//
// NOTE: Drift generates data classes named Note, Folder, Attachment that clash
// with our domain entities. We import domain types with an 'as domain' prefix
// and use the unqualified names for Drift row types.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/features/notes/data/note_dao.dart';
import 'package:streakin/features/notes/domain/attachment.dart' as domain;
import 'package:streakin/features/notes/domain/folder.dart' as domain;
import 'package:streakin/features/notes/domain/note.dart' as domain;
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

// ── Mappers ───────────────────────────────────────────────────────────────────

// domain.Note → Drift companion
extension _DomainNoteToCompanion on domain.Note {
  NotesCompanion toCompanion() => NotesCompanion(
        id: Value(id),
        folderId: Value(folderId),
        title: Value(title),
        templateKind: Value(templateKind.serialized),
        body: Value(body),
        isPinned: Value(isPinned),
        vaultId: Value(vaultId),
        createdAt: Value(createdAt.toIso8601String()),
        updatedAt: Value(updatedAt.toIso8601String()),
        hlc: Value(hlc),
        deletedAt: Value(deletedAt?.toIso8601String()),
      );
}

// Drift row Note → domain.Note
extension _NoteRowToDomain on Note {
  domain.Note toDomain() => domain.Note(
        id: id,
        folderId: folderId,
        title: title,
        templateKind: domain.NoteTemplateKindExt.fromString(templateKind),
        body: body,
        isPinned: isPinned,
        vaultId: vaultId,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        hlc: hlc,
        deletedAt: deletedAt != null ? DateTime.parse(deletedAt!) : null,
      );
}

// domain.Folder → Drift companion
extension _DomainFolderToCompanion on domain.Folder {
  FoldersCompanion toCompanion() => FoldersCompanion(
        id: Value(id),
        parentId: Value(parentId),
        name: Value(name),
        iconIndex: Value(iconIndex),
        accentIndex: Value(accentIndex),
        vaultId: Value(vaultId),
        sortOrder: Value(sortOrder),
        hlc: Value(hlc),
        deletedAt: Value(deletedAt?.toIso8601String()),
      );
}

// Drift row Folder → domain.Folder
extension _FolderRowToDomain on Folder {
  domain.Folder toDomain() => domain.Folder(
        id: id,
        parentId: parentId,
        name: name,
        iconIndex: iconIndex,
        accentIndex: accentIndex,
        vaultId: vaultId,
        sortOrder: sortOrder,
        hlc: hlc,
        deletedAt: deletedAt != null ? DateTime.parse(deletedAt!) : null,
      );
}

// Drift row Attachment → domain.Attachment
extension _AttachmentRowToDomain on Attachment {
  domain.Attachment toDomain() => domain.Attachment(
        id: id,
        noteId: noteId,
        kind: domain.AttachmentKindExt.fromString(kind),
        mime: mime,
        size: size,
        sha256: sha256,
        storageName: storageName,
        createdAt: DateTime.parse(createdAt),
      );
}

// ── DriftNoteRepository ───────────────────────────────────────────────────────

class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._dao, this._fts);

  final NoteDao _dao;
  final NoteFtsDao _fts;

  @override
  Stream<List<domain.Note>> watchFolder(String? folderId) =>
      _dao.watchFolder(folderId).map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Stream<domain.Note?> watchNote(String id) =>
      _dao.watchNote(id).map((r) => r?.toDomain());

  @override
  Stream<List<domain.Folder>> watchFolders() =>
      _dao.watchFolders().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<void> saveNote(domain.Note note) async {
    await _dao.db.transaction(() async {
      await _dao.upsertNote(note.toCompanion());

      final doc = NoteDocument.fromJson(note.body);

      // Rebuild note_links — resolve title → note ID
      final links = doc.extractLinks();
      final linkCompanions = <NoteLinksCompanion>[];
      for (final link in links) {
        final dstNoteId = await _resolveLink(link.targetTitle);
        if (dstNoteId != null) {
          linkCompanions.add(NoteLinksCompanion(
            srcNoteId: Value(note.id),
            dstNoteId: Value(dstNoteId),
            blockId: Value(link.blockId),
          ));
        }
      }
      await _dao.rebuildLinks(note.id, linkCompanions);

      // Rebuild note_tags
      final tags = doc.extractTags();
      final tagCompanions = tags
          .map((t) => NoteTagsCompanion(
                noteId: Value(note.id),
                tag: Value(t),
              ))
          .toList();
      await _dao.rebuildTags(note.id, tagCompanions);

      // Rebuild date_mentions
      final mentions = doc.extractDateMentions();
      final mentionCompanions = mentions.map((m) {
        return DateMentionsCompanion(
          id: Value(const Uuid().v4()),
          noteId: Value(note.id),
          blockId: Value(m.blockId),
          startsAt: Value(m.isoDate),
          allDay: const Value(true),
        );
      }).toList();
      await _dao.rebuildDateMentions(note.id, mentionCompanions);
    });

    // Update FTS index outside the transaction.
    final doc = NoteDocument.fromJson(note.body);
    await _fts.index(note.id, note.title, doc.toPlainText());
  }

  Future<String?> _resolveLink(String titleOrId) async {
    if (_uuidRegex.hasMatch(titleOrId)) return titleOrId;
    final matches = await _dao.searchByTitle(titleOrId);
    return matches.isNotEmpty ? matches.first.id : null;
  }

  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  Future<void> saveFolder(domain.Folder folder) =>
      _dao.upsertFolder(folder.toCompanion());

  @override
  Future<void> moveNote(String noteId, String? targetFolderId) =>
      _dao.moveNote(noteId, targetFolderId);

  @override
  Future<void> moveFolder(String folderId, String? targetParentId) =>
      _dao.moveFolder(folderId, targetParentId);

  @override
  Future<void> softDeleteNote(String id) =>
      _dao.softDeleteNote(id, DateTime.now());

  @override
  Future<void> softDeleteFolder(String id) async {
    await _dao.db.transaction(() async {
      await _dao.softDeleteNotesInFolder(id, DateTime.now());
      await _dao.softDeleteFolder(id, DateTime.now());
    });
  }

  @override
  Stream<List<domain.Note>> watchBacklinks(String noteId) =>
      _dao.watchBacklinks(noteId).map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Stream<List<domain.Note>> watchOutgoingLinks(String noteId) =>
      _dao.watchOutgoingLinks(noteId).map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Stream<List<String>> watchTags() => _dao.watchTags();

  @override
  Stream<List<domain.Note>> watchNotesByTag(String tag) =>
      _dao.watchNotesByTag(tag).map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<domain.Note?> getById(String id) async {
    final row = await _dao.getById(id);
    return row?.toDomain();
  }

  @override
  Future<List<domain.Note>> searchByTitle(String query) async {
    final rows = await _dao.searchByTitle(query);
    return rows.map((r) => r.toDomain()).toList();
  }
}

// ── DriftAttachmentRepository ─────────────────────────────────────────────────

class DriftAttachmentRepository implements AttachmentRepository {
  DriftAttachmentRepository(this._dao);

  final AttachmentDao _dao;

  @override
  Future<void> saveAttachment(
    domain.Attachment attachment,
    Uint8List encryptedBlob,
  ) async {
    final file = await _blobFile(attachment.storageName);
    await file.writeAsBytes(encryptedBlob);
    await _dao.insert(AttachmentsCompanion(
      id: Value(attachment.id),
      noteId: Value(attachment.noteId),
      kind: Value(attachment.kind.serialized),
      mime: Value(attachment.mime),
      size: Value(attachment.size),
      sha256: Value(attachment.sha256),
      storageName: Value(attachment.storageName),
      createdAt: Value(attachment.createdAt.toIso8601String()),
    ));
  }

  @override
  Future<void> deleteAttachment(String id) async {
    // Look up storageName before deleting row.
    final rows = await _dao.allStorageNamesForId(id);
    for (final name in rows) {
      final file = await _blobFile(name);
      if (await file.exists()) await file.delete();
    }
    await _dao.delete_(id);
  }

  // Expose db for the query above.
  AppDatabase get db => _dao.db;

  @override
  Future<Uint8List> loadBlob(String storageName) async {
    final file = await _blobFile(storageName);
    return file.readAsBytes();
  }

  @override
  Future<domain.Attachment?> dedupeCheck(String sha256, String noteId) async {
    final row = await _dao.findBySha256AndNote(sha256, noteId);
    return row?.toDomain();
  }

  @override
  Stream<List<domain.Attachment>> watchForNote(String noteId) =>
      _dao.watchForNote(noteId).map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<void> orphanSweep() async {
    final dir = await _attachmentsDir();
    if (!await dir.exists()) return;
    final knownNames = Set<String>.from(await _dao.allStorageNames());
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (!knownNames.contains(name)) {
          await entity.delete();
        }
      }
    }
  }

  Future<Directory> _attachmentsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _blobFile(String storageName) async {
    final dir = await _attachmentsDir();
    return File(p.join(dir.path, storageName));
  }
}

// ── DriftFtsRepository ────────────────────────────────────────────────────────

class DriftFtsRepository implements FtsRepository {
  DriftFtsRepository(this._dao);

  final NoteFtsDao _dao;

  @override
  Future<void> indexNote(String noteId, String title, String plainText) =>
      _dao.index(noteId, title, plainText);

  @override
  Future<void> removeNote(String noteId) => _dao.remove(noteId);

  @override
  Future<List<FtsResult>> search(String query, {String? folderId}) async {
    final rows = await _dao.search(query, folderId: folderId);
    return rows.map((r) => FtsResult(
          noteId: r['id'] as String,
          title: r['title'] as String,
          snippet: r['snip'] as String? ?? '',
          rank: (r['rank'] as num?)?.toDouble() ?? 0.0,
        )).toList();
  }
}
