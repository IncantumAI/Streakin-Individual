// lib/core/design/typography.dart
//
// Spec §5.3: Inter (UI & notes), JetBrains Mono (code).
// Scale: Display 32 / Title 22 / Heading 18 / Body 16 / Caption 13.
// Respects OS text scaling up to 200%.

import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  static TextTheme buildTextTheme(Color textColor) {
    return TextTheme(
      // Display 32
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.2,
      ),
      // Title 22
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
      // Heading 18
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      // Body 16
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      // Caption 13
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textColor,
        height: 1.4,
      ),
    );
  }

  /// Mono style for code blocks in the editor.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 14,
    height: 1.6,
  );
}
