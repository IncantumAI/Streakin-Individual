// lib/features/notes/search/embedding_pipeline.dart
// Spec §4.7 / §11.4 background embedding queue.
//
// Phase 7 ships the FTS-only fallback (Spike S3 decision): no ONNX runtime or
// model is bundled, so [EmbeddingModel.isAvailable] is false, the queue never
// runs, and the "Meaning" toggle stays hidden. Everything else — queue, idle
// pause, 60 s model disposal, vault-vector isolation — is implemented and
// tested so a model can be dropped in without touching callers.

import 'dart:async';
import 'dart:typed_data';

import 'package:streakin/features/notes/search/note_chunker.dart';

abstract interface class EmbeddingModel {
  bool get isAvailable;
  String get version;

  /// Loads the session (expensive). Called once per idle burst.
  Future<void> load();

  /// Embeds each text.
  Future<List<Float32List>> embed(List<String> texts);

  /// Frees the session.
  void dispose();
}

/// Default: no model bundled → FTS-only search.
class NoEmbeddingModel implements EmbeddingModel {
  const NoEmbeddingModel();
  @override
  bool get isAvailable => false;
  @override
  String get version => 'none';
  @override
  Future<void> load() async {}
  @override
  Future<List<Float32List>> embed(List<String> texts) async =>
      throw UnsupportedError('No embedding model bundled');
  @override
  void dispose() {}
}

abstract interface class EmbeddingStore {
  /// Non-vault notes that need (re-)embedding, with their plain text.
  Future<List<({String noteId, String text})>> pending(String modelVersion);
  Future<void> write(
    String noteId,
    List<TextChunk> chunks,
    List<Float32List> vectors,
    String modelVersion,
  );
  Future<void> deleteForNote(String noteId);
}

class EmbeddingPipeline {
  EmbeddingPipeline({
    required this.model,
    required this.store,
    this.chunker = const NoteChunker(),
    this.modelIdle = const Duration(seconds: 60),
  });

  final EmbeddingModel model;
  final EmbeddingStore store;
  final NoteChunker chunker;

  /// The model session is disposed after this much inactivity (hard req.).
  final Duration modelIdle;

  bool _editing = false;
  bool _loaded = false;
  Timer? _disposeTimer;

  /// Per-vault vectors live only here, never in the shared table, and are
  /// dropped on vault lock.
  final Map<String, Map<String, List<Float32List>>> _vaultVectors = {};

  bool get modelLoaded => _loaded;

  /// The editor reports typing so the queue pauses during active editing.
  void setEditing(bool editing) => _editing = editing;

  /// Drains the queue if the model exists and the user is idle. Returns the
  /// number of notes embedded.
  Future<int> drain() async {
    if (!model.isAvailable || _editing) return 0;
    final todo = await store.pending(model.version);
    if (todo.isEmpty) return 0;
    if (!_loaded) {
      await model.load();
      _loaded = true;
    }
    var done = 0;
    for (final t in todo) {
      if (_editing) break; // pause as soon as the user starts typing again
      final chunks = chunker.chunk(t.text);
      if (chunks.isEmpty) {
        await store.deleteForNote(t.noteId);
        continue;
      }
      final vectors = await model.embed([for (final c in chunks) c.text]);
      await store.write(t.noteId, chunks, vectors, model.version);
      done++;
    }
    _armDispose();
    return done;
  }

  void _armDispose() {
    _disposeTimer?.cancel();
    _disposeTimer = Timer(modelIdle, disposeModel);
  }

  /// Also called on `didHaveMemoryPressure`.
  void disposeModel() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
    if (_loaded) {
      model.dispose();
      _loaded = false;
    }
  }

  // ── Vault vectors (in-memory only) ─────────────────────────────────────

  void putVaultVectors(String vaultId, String noteId, List<Float32List> v) =>
      (_vaultVectors[vaultId] ??= {})[noteId] = v;

  Iterable<({String id, Float32List vector})> vaultVectors(
    String vaultId,
  ) sync* {
    for (final e in (_vaultVectors[vaultId] ?? const {}).entries) {
      for (final v in e.value) {
        yield (id: e.key, vector: v);
      }
    }
  }

  /// Zeroes and drops a vault's vectors (called when the vault locks).
  void dropVault(String vaultId) {
    final m = _vaultVectors.remove(vaultId);
    if (m == null) return;
    for (final list in m.values) {
      for (final v in list) {
        v.fillRange(0, v.length, 0);
      }
    }
  }

  void dispose() {
    disposeModel();
    for (final id in _vaultVectors.keys.toList()) {
      dropVault(id);
    }
  }
}
