// lib/core/design/tokens.dart
//
// Single source of truth for all colour tokens.
// Spec §5.2: "no hard-coded colours outside tokens.dart".
// Lint rule enforces this — see tool/lint_checks.sh.

import 'package:flutter/material.dart';

/// Light and dark theme colour tokens.
/// ALL colours in the app must reference these constants.
/// Never use Color(0x...) or Colors.* outside this file.
class AppColors {
  AppColors._();

  // ── Neutrals — Light ──────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFFAFAFB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceAltLight = Color(0xFFF1F1F5);
  static const Color outlineLight = Color(0xFFE3E3EA);
  static const Color textLight = Color(0xFF17171C);
  static const Color textMutedLight = Color(0xFF6B6B78);

  // ── Neutrals — Dark ───────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF0E0E12);
  static const Color surfaceDark = Color(0xFF16161C);
  static const Color surfaceAltDark = Color(0xFF1F1F27);
  static const Color outlineDark = Color(0xFF2C2C36);
  static const Color textDark = Color(0xFFF2F2F5);
  static const Color textMutedDark = Color(0xFF9A9AA8);

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color brandLight = Color(0xFF6E56CF);
  static const Color brandDark = Color(0xFF8E7BEA);
  static const Color onBrandLight = Color(0xFFFFFFFF);
  static const Color onBrandDark = Color(0xFF0E0E12);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color successLight = Color(0xFF2FBF71);
  static const Color successDark = Color(0xFF3DD68C);
  static const Color warningLight = Color(0xFFF5A524);
  static const Color warningDark = Color(0xFFFFB224);
  static const Color dangerLight = Color(0xFFE5484D);
  static const Color dangerDark = Color(0xFFFF6369);

  // ── Streak flame ─────────────────────────────────────────────────────────
  /// Only used for streak flame and counters.
  static const Color streakLight = Color(0xFFFF7A45);
  static const Color streakDark = Color(0xFFFF8F5E);

  // ── Celebration palette ───────────────────────────────────────────────────
  /// Usable ONLY in: splash, confetti, lock-in, milestone, streak flame, zen ambient.
  static const Color celebBrand = Color(0xFF6E56CF);
  static const Color celebPink = Color(0xFFFF5FA2);
  static const Color celebAmber = Color(0xFFFFC53D);
  static const Color celebTeal = Color(0xFF2DD4BF);
  static const Color celebBlue = Color(0xFF3E9BFF);

  // ── Habit accent palette (8 swatches) ─────────────────────────────────────
  static const List<Color> habitAccents = [
    Color(0xFF6E56CF), // violet
    Color(0xFF3E9BFF), // blue
    Color(0xFF2DD4BF), // teal
    Color(0xFF3DD68C), // green
    Color(0xFFFFC53D), // amber
    Color(0xFFFF7A45), // orange
    Color(0xFFFF5FA2), // pink
    Color(0xFF8B8D98), // slate
  ];
}

/// ThemeExtension carrying semantic token references for the current theme.
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.brand,
    required this.onBrand,
    required this.success,
    required this.warning,
    required this.danger,
    required this.streak,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color outline;
  final Color text;
  final Color textMuted;
  final Color brand;
  final Color onBrand;
  final Color success;
  final Color warning;
  final Color danger;
  final Color streak;

  static const AppColorTokens light = AppColorTokens(
    bg: AppColors.bgLight,
    surface: AppColors.surfaceLight,
    surfaceAlt: AppColors.surfaceAltLight,
    outline: AppColors.outlineLight,
    text: AppColors.textLight,
    textMuted: AppColors.textMutedLight,
    brand: AppColors.brandLight,
    onBrand: AppColors.onBrandLight,
    success: AppColors.successLight,
    warning: AppColors.warningLight,
    danger: AppColors.dangerLight,
    streak: AppColors.streakLight,
  );

  static const AppColorTokens dark = AppColorTokens(
    bg: AppColors.bgDark,
    surface: AppColors.surfaceDark,
    surfaceAlt: AppColors.surfaceAltDark,
    outline: AppColors.outlineDark,
    text: AppColors.textDark,
    textMuted: AppColors.textMutedDark,
    brand: AppColors.brandDark,
    onBrand: AppColors.onBrandDark,
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    danger: AppColors.dangerDark,
    streak: AppColors.streakDark,
  );

  @override
  AppColorTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? text,
    Color? textMuted,
    Color? brand,
    Color? onBrand,
    Color? success,
    Color? warning,
    Color? danger,
    Color? streak,
  }) {
    return AppColorTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outline: outline ?? this.outline,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      streak: streak ?? this.streak,
    );
  }

  @override
  AppColorTokens lerp(AppColorTokens? other, double t) {
    if (other == null) return this;
    return AppColorTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
    );
  }
}

/// Helper to get tokens from context.
extension AppColorsContext on BuildContext {
  AppColorTokens get colors =>
      Theme.of(this).extension<AppColorTokens>()!;
}
