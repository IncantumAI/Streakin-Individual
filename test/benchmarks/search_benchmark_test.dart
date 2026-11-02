// NFR-4 / Phase 7E benchmark: brute-force cosine over 50k chunks.
// The assertion is intentionally generous for CI/debug JIT; record the real
// number on the target device (release/profile) in the Phase 7 checklist.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/graph/graph_model.dart';
import 'package:streakin/features/notes/search/search_math.dart';

void main() {
  test('semantic top-10 over 50k chunks', () {
    const dim = 64;
    final q = Float32List.fromList(List.generate(dim, (i) => (i % 7) - 3.0));
    final vectors = [
      for (var i = 0; i < 50000; i++)
        (
          id: 'n${i ~/ 5}',
          vector: Float32List.fromList(
            List.generate(dim, (j) => ((i * 31 + j) % 11) - 5.0),
          ),
        ),
    ];
    final sw = Stopwatch()..start();
    final r = topKByCosine(q, vectors);
    sw.stop();
    // ignore: avoid_print
    print('topKByCosine 50k×$dim: ${sw.elapsedMilliseconds} ms (debug JIT)');
    expect(r.length, 10);
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });

  test('graph build with 2,000 notes stays fast', () {
    final notes = [
      for (var i = 0; i < 2000; i++) GraphNoteRef(id: 'n$i', title: 'N$i'),
    ];
    final links = {
      for (var i = 0; i < 1999; i++) 'n$i': {'n${i + 1}'},
    };
    final sw = Stopwatch()..start();
    final g = buildGraph(
      notes: notes,
      links: links,
      isVaultLocked: (_) => true,
    );
    sw.stop();
    expect(g.nodes.length, 2000);
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
