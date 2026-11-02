// lib/app/theme/app_theme.dart
//
// Spec §5: Material 3 with fully custom ColorScheme + ThemeExtensions.
// Live cross-fade theme switch (250ms). No restart needed.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
    brightness: Brightness.light,
    tokens: AppColorTokens.light,
    seed: AppColors.brandLight,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    tokens: AppColorTokens.dark,
    seed: AppColors.brandDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppColorTokens tokens,
    required Color seed,
  }) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          surface: tokens.surface,
          onSurface: tokens.text,
          primary: tokens.brand,
          onPrimary: tokens.onBrand,
          error: tokens.danger,
        );

    final textTheme = AppTypography.buildTextTheme(tokens.text);

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      textTheme: textTheme,
      scaffoldBackgroundColor: tokens.bg,
      cardColor: tokens.surface,
      dividerColor: tokens.outline,
      extensions: [tokens],
      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.brand, width: 1.5),
        ),
      ),
      // Cards
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.outline),
        ),
      ),
      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.brand.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.text,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tokens.text,
        ),
      ),
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceAlt,
        selectedColor: tokens.brand.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 13,
          color: tokens.text,
        ),
        side: BorderSide(color: tokens.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.brand,
          side: BorderSide(color: tokens.brand),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(0, 48),
        ),
      ),
    );
  }
}
