// lib/core/design/spacing.dart
//
// Spacing, radius and size tokens. Spec §5.1: generous space, 12–16 px radii.
// 4-pt grid; prefer these over literal numbers in EdgeInsets / SizedBox.

import 'package:flutter/widgets.dart';

/// Spacing scale (4-pt grid).
class AppSpace {
  AppSpace._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter for the given layout width (spec §5.6).
  static double pagePadding(double width) => width < 600 ? lg : xl;

  /// Max content width for single-column reading pages (settings, forms).
  static const double readableWidth = 720;

  // Gap widgets.
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);
}

/// Corner radius scale.
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Fixed component sizes.
class AppSizes {
  AppSizes._();

  /// Minimum interactive target (Material / WCAG 2.5.5).
  static const double minTap = 48;

  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  static const double navBarHeight = 64;
  static const double railWidthExpanded = 232;
}
