// Track 7B: breathing rhythm and reduced-motion pulse.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/zen/presentation/zen_screen.dart';

void main() {
  test('rhythm is 4 s in / 6 s out (10 s cycle)', () {
    expect(kInhale, const Duration(seconds: 4));
    expect(kExhale, const Duration(seconds: 6));
  });

  test('scale expands during inhale and contracts during exhale', () {
    final start = breathScale(0);
    final peak = breathScale(0.4);
    final end = breathScale(0.999);
    expect(peak, closeTo(1.0, 1e-6));
    expect(start, lessThan(peak));
    expect(end, lessThan(peak));
    expect(breathLabel(0.1), 'Breathe in');
    expect(breathLabel(0.8), 'Breathe out');
  });

  test('reduced motion never exceeds a 3% pulse', () {
    for (var t = 0.0; t <= 1.0; t += 0.05) {
      final s = breathScale(t, reduced: true);
      expect(s, inInclusiveRange(1.0, kReducedPulseScale + 1e-9));
    }
  });
}
