// lib/core/design/tokens.dart
//
// Single source of truth for all colour tokens.
// Spec §5.2: "no hard-coded colours outside tokens.dart".
// Lint rule enforces this — see tool/lint_checks.sh.
//
// Neutral scale is layered: bg < surface < surfaceAlt < surfaceRaised.
// Cards sit on `surface` with a hairline `outline`; floating UI (sheets,
// dialogs, nav bar, menus) uses `surfaceRaised` + soft elevation.
// Every text/background pair is covered by test/core/design/contrast_test.dart.

import 'package:flutter/material.dart';

/// Light and dark theme colour tokens.
/// ALL colours in the app must reference these constants.
/// Never use Color(0x...) or Colors.* outside this file.
class AppColors {
  AppColors._();

  // ── Neutrals — Light (warm paper) ─────────────────────────────────────────
  static const Color bgLight = Color(0xFFF8F6F2);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceAltLight = Color(0xFFF1EEE8);
  static const Color surfaceRaisedLight = Color(0xFFFFFFFF);
  static const Color outlineLight = Color(0xFFE6E1D8);
  static const Color outlineStrongLight = Color(0xFF827B70);
  static const Color textLight = Color(0xFF1C1B19);
  static const Color textMutedLight = Color(0xFF5C5750);

  // ── Neutrals — Dark (ink) ─────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF111113);
  static const Color surfaceDark = Color(0xFF18181B);
  static const Color surfaceAltDark = Color(0xFF1F1F23);
  static const Color surfaceRaisedDark = Color(0xFF26262B);
  static const Color outlineDark = Color(0xFF2A2A2F);
  static const Color outlineStrongDark = Color(0xFF6E6E78);
  static const Color textDark = Color(0xFFF4F4F5);
  static const Color textMutedDark = Color(0xFFA1A1AA);

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color brandLight = Color(0xFFFF8F34);
  static const Color brandDark = Color(0xFFFF8F34);
  static const Color onBrandLight = Color(0xFF2A1A0C);
  static const Color onBrandDark = Color(0xFF2A1A0C);

  /// Tinted backgrounds for selected states / indicators.
  static const Color brandSubtleLight = Color(0xFFFFEEDD);
  static const Color brandSubtleDark = Color(0xFF2B1D12);

  /// Text-safe brand (orange itself is ~2.3:1 on white, never use as text).
  static const Color brandTextLight = Color(0xFF934407);
  static const Color brandTextDark = Color(0xFFFFA559);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color successLight = Color(0xFF1E9A55);
  static const Color successDark = Color(0xFF3DD68C);
  static const Color warningLight = Color(0xFFB7791F);
  static const Color warningDark = Color(0xFFFFB224);
  static const Color dangerLight = Color(0xFFD1343A);
  static const Color dangerDark = Color(0xFFFF6369);

  static const Color successSubtleLight = Color(0xFFE3F5EA);
  static const Color successSubtleDark = Color(0xFF13261C);
  static const Color warningSubtleLight = Color(0xFFFBF0DC);
  static const Color warningSubtleDark = Color(0xFF2A2112);
  static const Color dangerSubtleLight = Color(0xFFFCE6E6);
  static const Color dangerSubtleDark = Color(0xFF2E1517);

  // ── Inverse (snackbars, tooltips) ─────────────────────────────────────────
  static const Color inverseSurfaceLight = Color(0xFF26262B);
  static const Color onInverseLight = Color(0xFFF4F4F5);
  static const Color inverseSurfaceDark = Color(0xFFF4F4F5);
  static const Color onInverseDark = Color(0xFF18181B);

  // ── Shadow / scrim ────────────────────────────────────────────────────────
  static const Color shadowLight = Color(0x14000000);
  static const Color shadowDark = Color(0x66000000);
  static const Color scrimLight = Color(0x66000000);
  static const Color scrimDark = Color(0x99000000);

  /// Fully transparent (use instead of Colors.transparent).
  static const Color transparent = Color(0x00000000);

  /// Pure white/black for marks drawn on top of saturated accent fills.
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ── Splash / chart chrome ─────────────────────────────────────────────────
  static const Color splashOrangeMid = Color(0xFFE67A22);
  static const Color splashOrangeDark = Color(0xFF9A4A0F);

  /// Dark chart tooltip background (white text on top).
  static const Color tooltipBackground = Color(0xFF26262B);

  // ── Streak flame ─────────────────────────────────────────────────────────
  /// Only used for streak flame and counters.
  static const Color streakLight = Color(0xFFE5532D);
  static const Color streakDark = Color(0xFFF2643F);

  // ── Celebration palette ───────────────────────────────────────────────────
  /// Usable ONLY in: splash, confetti, lock-in, milestone, streak flame, zen ambient.
  static const Color celebBrand = Color(0xFFFF8F34);
  static const Color celebPink = Color(0xFFFF5FA2);
  static const Color celebAmber = Color(0xFFFFC53D);
  static const Color celebTeal = Color(0xFF2DD4BF);
  static const Color celebBlue = Color(0xFF3E9BFF);

  static const List<Color> celebration = [
    celebBrand,
    celebPink,
    celebAmber,
    celebTeal,
    celebBlue,
  ];

  // ── Habit accent palette (8 swatches) ─────────────────────────────────────
  static const List<Color> habitAccents = [
    Color(0xFFFF8F34), // orange
    Color(0xFF3E9BFF), // blue
    Color(0xFF2DD4BF), // teal
    Color(0xFF3DD68C), // green
    Color(0xFFFFC53D), // amber
    Color(0xFFE5532D), // red-orange
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
    required this.surfaceRaised,
    required this.outlineStrong,
    required this.brandSubtle,
    required this.brandText,
    required this.successSubtle,
    required this.warningSubtle,
    required this.dangerSubtle,
    required this.inverseSurface,
    required this.onInverse,
    required this.shadow,
    required this.scrim,
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

  /// Floating surfaces: sheets, dialogs, menus, nav bar.
  final Color surfaceRaised;

  /// Interactive borders (inputs, switches); ≥3:1 on surface.
  final Color outlineStrong;

  /// Brand-tinted background for selected / indicator states.
  final Color brandSubtle;

  /// Text-safe brand foreground (links, selected labels).
  final Color brandText;

  final Color successSubtle;
  final Color warningSubtle;
  final Color dangerSubtle;
  final Color inverseSurface;
  final Color onInverse;
  final Color shadow;
  final Color scrim;

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
    surfaceRaised: AppColors.surfaceRaisedLight,
    outlineStrong: AppColors.outlineStrongLight,
    brandSubtle: AppColors.brandSubtleLight,
    brandText: AppColors.brandTextLight,
    successSubtle: AppColors.successSubtleLight,
    warningSubtle: AppColors.warningSubtleLight,
    dangerSubtle: AppColors.dangerSubtleLight,
    inverseSurface: AppColors.inverseSurfaceLight,
    onInverse: AppColors.onInverseLight,
    shadow: AppColors.shadowLight,
    scrim: AppColors.scrimLight,
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
    surfaceRaised: AppColors.surfaceRaisedDark,
    outlineStrong: AppColors.outlineStrongDark,
    brandSubtle: AppColors.brandSubtleDark,
    brandText: AppColors.brandTextDark,
    successSubtle: AppColors.successSubtleDark,
    warningSubtle: AppColors.warningSubtleDark,
    dangerSubtle: AppColors.dangerSubtleDark,
    inverseSurface: AppColors.inverseSurfaceDark,
    onInverse: AppColors.onInverseDark,
    shadow: AppColors.shadowDark,
    scrim: AppColors.scrimDark,
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
    Color? surfaceRaised,
    Color? outlineStrong,
    Color? brandSubtle,
    Color? brandText,
    Color? successSubtle,
    Color? warningSubtle,
    Color? dangerSubtle,
    Color? inverseSurface,
    Color? onInverse,
    Color? shadow,
    Color? scrim,
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
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      brandSubtle: brandSubtle ?? this.brandSubtle,
      brandText: brandText ?? this.brandText,
      successSubtle: successSubtle ?? this.successSubtle,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverse: onInverse ?? this.onInverse,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
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
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      dangerSubtle: Color.lerp(dangerSubtle, other.dangerSubtle, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
      onInverse: Color.lerp(onInverse, other.onInverse, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Helper to get tokens from context.
extension AppColorsContext on BuildContext {
  AppColorTokens get colors => Theme.of(this).extension<AppColorTokens>()!;
}
