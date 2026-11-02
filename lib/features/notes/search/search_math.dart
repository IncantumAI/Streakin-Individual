// lib/features/notes/search/search_math.dart
// Cosine similarity, top-K and Reciprocal Rank Fusion for hybrid search.

import 'dart:math';
import 'dart:typed_data';

double cosine(Float32List a, Float32List b) {
  assert(a.length == b.length);
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (sqrt(na) * sqrt(nb));
}

class Scored<T> {
  const Scored(this.item, this.score);
  final T item;
  final double score;
}

/// Brute-force top-[k] by cosine over a streamed vector source.
List<Scored<String>> topKByCosine(
  Float32List query,
  Iterable<({String id, Float32List vector})> vectors, {
  int k = 10,
  Set<String> exclude = const {},
}) {
  final best = <String, double>{};
  for (final v in vectors) {
    if (exclude.contains(v.id)) continue;
    final s = cosine(query, v.vector);
    if (s > (best[v.id] ?? double.negativeInfinity)) best[v.id] = s;
  }
  final list = [for (final e in best.entries) Scored(e.key, e.value)]
    ..sort((a, b) => b.score.compareTo(a.score));
  return list.take(k).toList();
}

/// Reciprocal Rank Fusion of ranked id lists (best first).
List<Scored<String>> reciprocalRankFusion(
  List<List<String>> rankings, {
  int k = 60,
}) {
  final scores = <String, double>{};
  for (final r in rankings) {
    for (var i = 0; i < r.length; i++) {
      scores[r[i]] = (scores[r[i]] ?? 0) + 1 / (k + i + 1);
    }
  }
  return [for (final e in scores.entries) Scored(e.key, e.value)]
    ..sort((a, b) => b.score.compareTo(a.score));
}
