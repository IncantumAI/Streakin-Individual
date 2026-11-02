// lib/core/design/typography.dart
//
// Spec §5.3: Inter (UI & notes), JetBrains Mono (code).
// Scale: Display 32 / Title 22 / Heading 18 / Body 16 / Caption 13.
// The remaining M3 slots are filled around those anchors so that every
// widget reading the theme gets an on-brand style.
// Respects OS text scaling up to 200%.

import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  static TextStyle _s(
    Color c,
    double size,
    FontWeight w,
    double h, {
    double ls = 0,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: w,
    color: c,
    height: h,
    letterSpacing: ls,
  );

  static TextTheme buildTextTheme(Color textColor, {Color? mutedColor}) {
    final muted = mutedColor ?? textColor;
    return TextTheme(
      displayLarge: _s(textColor, 32, FontWeight.w700, 1.2, ls: -0.5),
      displayMedium: _s(textColor, 28, FontWeight.w700, 1.2, ls: -0.4),
      displaySmall: _s(textColor, 24, FontWeight.w700, 1.25, ls: -0.3),
      headlineLarge: _s(textColor, 24, FontWeight.w600, 1.3, ls: -0.3),
      headlineMedium: _s(textColor, 18, FontWeight.w600, 1.4, ls: -0.1),
      headlineSmall: _s(textColor, 18, FontWeight.w600, 1.35, ls: -0.1),
      titleLarge: _s(textColor, 22, FontWeight.w600, 1.3, ls: -0.2),
      titleMedium: _s(textColor, 16, FontWeight.w600, 1.4),
      titleSmall: _s(textColor, 14, FontWeight.w600, 1.4),
      bodyLarge: _s(textColor, 16, FontWeight.w400, 1.5),
      bodyMedium: _s(textColor, 16, FontWeight.w400, 1.5),
      bodySmall: _s(muted, 13, FontWeight.w400, 1.4),
      labelLarge: _s(textColor, 14, FontWeight.w600, 1.3, ls: 0.1),
      labelMedium: _s(textColor, 12, FontWeight.w500, 1.3, ls: 0.2),
      labelSmall: _s(textColor, 13, FontWeight.w500, 1.4),
    );
  }

  /// Mono style for code blocks in the editor.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 14,
    height: 1.6,
  );

  /// Tabular figures for counters, rings, timers (no width jitter).
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Large numeric display (streak counts, ring percentages).
  static const TextStyle numeric = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    fontFeatures: tabular,
    letterSpacing: -0.5,
    height: 1.1,
  );

  /// Small uppercase overline for section headers.
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.3,
  );
}

/// Shortcut for the theme's text styles.
extension AppTextContext on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
