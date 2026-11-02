// lib/features/notes/data/drift_embedding_store.dart
// Persists chunk embeddings in `note_embeddings` (Float32 BLOBs). Vault notes
// are never read or written here — their vectors stay in memory only.

import 'dart:typed_data';

import 'package:drift/drift.dart';

import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/search/embedding_pipeline.dart';
import 'package:streakin/features/notes/search/note_chunker.dart';

class DriftEmbeddingStore implements EmbeddingStore {
  DriftEmbeddingStore(this._db);
  final AppDatabase _db;

  @override
  Future<List<({String noteId, String text})>> pending(
    String modelVersion,
  ) async {
    final notes = await (_db.select(
      _db.notes,
    )..where((n) => n.deletedAt.isNull() & n.vaultId.isNull())).get();
    final done = <String>{
      for (final e in await (_db.select(
        _db.noteEmbeddings,
      )..where((e) => e.modelVer.equals(modelVersion))).get())
        e.noteId,
    };
    return [
      for (final n in notes)
        if (!done.contains(n.id))
          (noteId: n.id, text: NoteDocument.fromJson(n.body).toPlainText()),
    ];
  }

  @override
  Future<void> write(
    String noteId,
    List<TextChunk> chunks,
    List<Float32List> vectors,
    String modelVersion,
  ) async {
    await _db.transaction(() async {
      await deleteForNote(noteId);
      for (var i = 0; i < chunks.length; i++) {
        await _db
            .into(_db.noteEmbeddings)
            .insert(
              NoteEmbeddingsCompanion.insert(
                noteId: noteId,
                chunkIdx: chunks[i].chunkIdx,
                vector: vectors[i].buffer.asUint8List(),
                modelVer: modelVersion,
              ),
            );
      }
    });
  }

  @override
  Future<void> deleteForNote(String noteId) => (_db.delete(
    _db.noteEmbeddings,
  )..where((e) => e.noteId.equals(noteId))).go();
}
