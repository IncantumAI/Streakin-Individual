// test/core/time/hlc_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/time/hlc.dart';

void main() {
  setUp(() => Hlc.init('test'));

  group('HLC', () {
    test('generates monotonically increasing values', () {
      final values = List.generate(100, (_) => Hlc.now());
      for (int i = 1; i < values.length; i++) {
        expect(values[i].compareTo(values[i - 1]) >= 0, isTrue);
      }
    });

    test('parse round-trip', () {
      final h = Hlc.now();
      final s = h.toIso();
      final parsed = Hlc.parse(s);
      expect(parsed, h);
    });

    test('comparison: larger wallMs wins', () {
      const a = Hlc(wallMs: 1000, counter: 0, node: '0000');
      const b = Hlc(wallMs: 2000, counter: 0, node: '0000');
      expect(a < b, isTrue);
      expect(b > a, isTrue);
    });

    test('comparison: same wallMs, counter breaks tie', () {
      const a = Hlc(wallMs: 1000, counter: 0, node: '0000');
      const b = Hlc(wallMs: 1000, counter: 1, node: '0000');
      expect(a < b, isTrue);
    });

    test('toIso format: wallMs-counter-node', () {
      const h = Hlc(wallMs: 12345, counter: 255, node: 'abcd');
      expect(h.toIso(), '12345-00ff-abcd');
    });
  });
}
