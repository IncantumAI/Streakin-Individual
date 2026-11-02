// Track 7A: chunker, cosine/RRF, embedding pipeline (FTS-only fallback).

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streakin/features/notes/search/embedding_pipeline.dart';
import 'package:streakin/features/notes/search/note_chunker.dart';
import 'package:streakin/features/notes/search/search_math.dart';

class _FakeModel implements EmbeddingModel {
  int loads = 0, disposes = 0;
  @override
  bool get isAvailable => true;
  @override
  String get version => 'fake-1';
  @override
  Future<void> load() async => loads++;
  @override
  Future<List<Float32List>> embed(List<String> texts) async => [
    for (final _ in texts) Float32List.fromList([1, 0, 0]),
  ];
  @override
  void dispose() => disposes++;
}

class _MemStore implements EmbeddingStore {
  final List<({String noteId, String text})> queue;
  final Map<String, int> written = {};
  _MemStore(this.queue);
  @override
  Future<List<({String noteId, String text})>> pending(String v) async =>
      queue.where((q) => !written.containsKey(q.noteId)).toList();
  @override
  Future<void> write(
    String id,
    List<TextChunk> c,
    List<Float32List> v,
    String ver,
  ) async => written[id] = c.length;
  @override
  Future<void> deleteForNote(String id) async => written.remove(id);
}

void main() {
  group('NoteChunker', () {
    test(
      '10k-word document → chunks within 200–300 tokens (last may be short)',
      () {
        final para = List.generate(100, (i) => 'word$i').join(' ');
        final doc = List.filled(100, para).join('\n\n'); // 10,000 words
        final chunks = const NoteChunker().chunk(doc);
        expect(chunks.length, greaterThan(30));
        for (final c in chunks.take(chunks.length - 1)) {
          expect(c.tokens, inInclusiveRange(200, 300));
        }
        expect(chunks.last.tokens, lessThanOrEqualTo(300));
        expect(
          chunks.map((c) => c.chunkIdx),
          List.generate(chunks.length, (i) => i),
        );
      },
    );

    test('paragraph boundaries are respected (no mid-paragraph cut)', () {
      final a = List.generate(120, (i) => 'a$i').join(' ');
      final b = List.generate(120, (i) => 'b$i').join(' ');
      final chunks = const NoteChunker().chunk('$a\n$b');
      // 240 tokens → one chunk containing both paragraphs whole.
      expect(chunks.length, 1);
      expect(chunks.single.text, contains('a119'));
      expect(chunks.single.text, contains('b0'));
    });

    test('a huge single paragraph is split by sentences/words', () {
      final p = List.generate(800, (i) => 'w$i').join(' ');
      final chunks = const NoteChunker().chunk(p);
      expect(chunks.every((c) => c.tokens <= 300), isTrue);
      expect(chunks.fold<int>(0, (a, c) => a + c.tokens), 800);
    });

    test(
      'empty text → no chunks',
      () => expect(const NoteChunker().chunk('  \n '), isEmpty),
    );
  });

  group('search math', () {
    test('cosine: identical = 1.0, orthogonal = 0, opposite = -1', () {
      final a = Float32List.fromList([1, 2, 3]);
      expect(cosine(a, a), closeTo(1.0, 1e-6));
      expect(
        cosine(Float32List.fromList([1, 0]), Float32List.fromList([0, 1])),
        0,
      );
      expect(
        cosine(a, Float32List.fromList([-1, -2, -3])),
        closeTo(-1.0, 1e-6),
      );
    });

    test('topK returns best distinct ids and honours exclude', () {
      final q = Float32List.fromList([1, 0]);
      final r = topKByCosine(
        q,
        [
          (id: 'a', vector: Float32List.fromList([1, 0])),
          (id: 'b', vector: Float32List.fromList([0.7, 0.7])),
          (id: 'b', vector: Float32List.fromList([0, 1])),
          (id: 'c', vector: Float32List.fromList([-1, 0])),
        ],
        k: 2,
        exclude: {'c'},
      );
      expect(r.map((e) => e.item), ['a', 'b']);
    });

    test('RRF fuses rankings', () {
      final fused = reciprocalRankFusion([
        ['a', 'b', 'c'],
        ['c', 'a', 'd'],
      ]);
      expect(fused.first.item, 'a');
      expect(fused.map((e) => e.item), containsAll(['a', 'b', 'c', 'd']));
    });
  });

  group('EmbeddingPipeline', () {
    test('no model bundled → FTS-only: nothing runs', () async {
      final p = EmbeddingPipeline(
        model: const NoEmbeddingModel(),
        store: _MemStore([(noteId: 'n', text: 'hello world')]),
      );
      expect(await p.drain(), 0);
      expect(p.modelLoaded, isFalse);
    });

    test('enqueue → idle → embedding written', () async {
      final store = _MemStore([(noteId: 'n1', text: 'hello world')]);
      final p = EmbeddingPipeline(model: _FakeModel(), store: store);
      expect(await p.drain(), 1);
      expect(store.written['n1'], 1);
      p.dispose();
    });

    test('paused while the user is editing', () async {
      final store = _MemStore([(noteId: 'n1', text: 'hello world')]);
      final p = EmbeddingPipeline(model: _FakeModel(), store: store)
        ..setEditing(true);
      expect(await p.drain(), 0);
      p.setEditing(false);
      expect(await p.drain(), 1);
      p.dispose();
    });

    test('model session disposed after 60 s idle', () {
      fakeAsync((async) {
        final model = _FakeModel();
        final p = EmbeddingPipeline(
          model: model,
          store: _MemStore([(noteId: 'n', text: 'hi there')]),
        );
        p.drain();
        async.flushMicrotasks();
        expect(p.modelLoaded, isTrue);
        async.elapse(const Duration(seconds: 59));
        expect(model.disposes, 0);
        async.elapse(const Duration(seconds: 2));
        expect(model.disposes, 1);
        expect(p.modelLoaded, isFalse);
      });
    });

    test('memory pressure disposes immediately', () async {
      final model = _FakeModel();
      final p = EmbeddingPipeline(
        model: model,
        store: _MemStore([(noteId: 'n', text: 'hi there')]),
      );
      await p.drain();
      p.disposeModel();
      expect(model.disposes, 1);
    });

    test('vault vectors stay in memory and are zeroed on lock', () {
      final p = EmbeddingPipeline(
        model: const NoEmbeddingModel(),
        store: _MemStore(const []),
      );
      final v = Float32List.fromList([1, 2, 3]);
      p.putVaultVectors('vault', 'note', [v]);
      expect(p.vaultVectors('vault').length, 1);
      p.dropVault('vault');
      expect(p.vaultVectors('vault'), isEmpty);
      expect(v.every((x) => x == 0), isTrue);
    });
  });
}
