// test/core/design/contrast_test.dart
// Spec §5.2: WCAG AA automated contrast test over all token pairs, both themes.
// Uses Color.value (raw ARGB int) to extract 8-bit channels, avoiding the
// Flutter 3.47+ .r/.g/.b linear-light conversion that breaks the calculation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/design/tokens.dart';

/// Extract 8-bit channels from Color.value (0xAARRGGBB).
int _ri(Color c) => (c.toARGB32() >> 16) & 0xFF;
int _gi(Color c) => (c.toARGB32() >> 8) & 0xFF;
int _bi(Color c) => c.toARGB32() & 0xFF;

double _relativeLuminance(Color c) {
  double linearise(int v) {
    final s = v / 255.0;
    return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) * ((s + 0.055) / 1.055);
  }
  return 0.2126 * linearise(_ri(c)) +
      0.7152 * linearise(_gi(c)) +
      0.0722 * linearise(_bi(c));
}

double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA Contrast — Light theme', () {
    const t = AppColorTokens.light;

    test('text on bg ≥ 4.5:1', () {
      expect(_contrastRatio(t.text, t.bg), greaterThanOrEqualTo(4.5));
    });

    test('text on surface ≥ 4.5:1', () {
      expect(_contrastRatio(t.text, t.surface), greaterThanOrEqualTo(4.5));
    });

    test('text on surfaceAlt ≥ 4.5:1', () {
      expect(_contrastRatio(t.text, t.surfaceAlt), greaterThanOrEqualTo(4.5));
    });

    test('onBrand on brand ≥ 3:1 (UI elements, not small text)', () {
      expect(_contrastRatio(t.onBrand, t.brand), greaterThanOrEqualTo(3.0));
    });

    test('textMuted on bg ≥ 3:1 (large text)', () {
      expect(_contrastRatio(t.textMuted, t.bg), greaterThanOrEqualTo(3.0));
    });

    test('success token exists', () {
      expect(t.success, isA<Color>());
    });
  });

  group('WCAG AA Contrast — Dark theme', () {
    const t = AppColorTokens.dark;

    test('text on bg ≥ 4.5:1', () {
      expect(_contrastRatio(t.text, t.bg), greaterThanOrEqualTo(4.5));
    });

    test('text on surface ≥ 4.5:1', () {
      expect(_contrastRatio(t.text, t.surface), greaterThanOrEqualTo(4.5));
    });

    test('text on surfaceAlt ≥ 4.5:1', () {
      expect(_contrastRatio(t.text, t.surfaceAlt), greaterThanOrEqualTo(4.5));
    });

    test('onBrand on brand ≥ 3:1 (UI elements, not small text)', () {
      expect(_contrastRatio(t.onBrand, t.brand), greaterThanOrEqualTo(3.0));
    });

    test('textMuted on bg ≥ 3:1 (large text)', () {
      expect(_contrastRatio(t.textMuted, t.bg), greaterThanOrEqualTo(3.0));
    });
  });
}
