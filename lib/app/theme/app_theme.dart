// lib/app/theme/app_theme.dart
//
// Spec §5: Material 3 with fully custom ColorScheme + ThemeExtensions.
// Live cross-fade theme switch (250ms, see app.dart). No restart needed.
//
// The ColorScheme is built explicitly from tokens (not fromSeed) so no stray
// M3 tonal colours leak into components. Every commonly used component has a
// theme here so screens rarely need inline styling.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:streakin/app/transitions.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() =>
      _build(brightness: Brightness.light, tokens: AppColorTokens.light);

  static ThemeData dark() =>
      _build(brightness: Brightness.dark, tokens: AppColorTokens.dark);

  static ThemeData _build({
    required Brightness brightness,
    required AppColorTokens tokens,
  }) {
    final t = tokens;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.brand,
      onPrimary: t.onBrand,
      primaryContainer: t.brandSubtle,
      onPrimaryContainer: t.brandText,
      secondary: t.brandText,
      onSecondary: t.surface,
      secondaryContainer: t.brandSubtle,
      onSecondaryContainer: t.brandText,
      tertiary: t.streak,
      onTertiary: t.surface,
      error: t.danger,
      onError: t.surface,
      errorContainer: t.dangerSubtle,
      onErrorContainer: t.danger,
      surface: t.surface,
      onSurface: t.text,
      onSurfaceVariant: t.textMuted,
      surfaceDim: t.bg,
      surfaceBright: t.surfaceRaised,
      surfaceContainerLowest: t.bg,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surfaceAlt,
      surfaceContainerHigh: t.surfaceRaised,
      surfaceContainerHighest: t.surfaceRaised,
      surfaceTint: AppColors.transparent,
      outline: t.outlineStrong,
      outlineVariant: t.outline,
      shadow: t.shadow,
      scrim: t.scrim,
      inverseSurface: t.inverseSurface,
      onInverseSurface: t.onInverse,
      inversePrimary: t.brand,
    );

    final textTheme = AppTypography.buildTextTheme(
      t.text,
      mutedColor: t.textMuted,
    );

    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.brMd);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpace.xl,
      vertical: AppSpace.md,
    );
    final buttonText = textTheme.labelLarge!.copyWith(fontSize: 15);
    const buttonMinSize = Size(64, AppSizes.minTap);

    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: c, width: w),
        );

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      cardColor: t.surface,
      dividerColor: t.outline,
      hoverColor: t.text.withValues(alpha: 0.04),
      focusColor: t.brand.withValues(alpha: 0.12),
      highlightColor: AppColors.transparent,
      splashColor: t.brand.withValues(alpha: 0.10),
      splashFactory: isAndroid
          ? InkSparkle.splashFactory
          : InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [tokens],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
        },
      ),

      // ── Text selection ────────────────────────────────────────────────────
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.brand,
        selectionColor: t.brand.withValues(alpha: 0.28),
        selectionHandleColor: t.brand,
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyLarge!.copyWith(color: t.textMuted),
        labelStyle: textTheme.bodyLarge!.copyWith(color: t.textMuted),
        floatingLabelStyle: textTheme.bodyMedium!.copyWith(color: t.brandText),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall!.copyWith(color: t.danger),
        prefixIconColor: t.textMuted,
        suffixIconColor: t.textMuted,
        border: inputBorder(t.outline),
        enabledBorder: inputBorder(t.outline),
        disabledBorder: inputBorder(t.outline.withValues(alpha: 0.5)),
        focusedBorder: inputBorder(t.brand, 1.5),
        errorBorder: inputBorder(t.danger),
        focusedErrorBorder: inputBorder(t.danger, 1.5),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(color: t.outline),
        ),
      ),

      // ── App bar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpace.lg,
        iconTheme: IconThemeData(color: t.text, size: AppSizes.iconLg),
        titleTextStyle: textTheme.headlineSmall,
      ),

      // ── Navigation ────────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: AppColors.transparent,
        indicatorColor: t.brandSubtle,
        height: AppSizes.navBarHeight,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelMedium!.copyWith(
            color: s.contains(WidgetState.selected) ? t.brandText : t.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? t.brandText : t.textMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.brandSubtle,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
        ),
        selectedIconTheme: IconThemeData(color: t.brandText),
        unselectedIconTheme: IconThemeData(color: t.textMuted),
        selectedLabelTextStyle: textTheme.labelLarge!.copyWith(
          color: t.brandText,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge!.copyWith(
          color: t.textMuted,
          fontWeight: FontWeight.w500,
        ),
        useIndicator: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.text,
        unselectedLabelColor: t.textMuted,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: t.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: t.outline,
        overlayColor: WidgetStatePropertyAll(t.brand.withValues(alpha: 0.06)),
        splashFactory: NoSplash.splashFactory,
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceAlt,
        selectedColor: t.brandSubtle,
        disabledColor: t.surfaceAlt,
        checkmarkColor: t.brandText,
        labelStyle: textTheme.labelLarge!.copyWith(
          color: t.text,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.labelLarge!.copyWith(color: t.brandText),
        side: BorderSide(color: t.outline),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        iconTheme: IconThemeData(color: t.textMuted, size: AppSizes.iconSm),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.brand,
          foregroundColor: t.onBrand,
          disabledBackgroundColor: t.surfaceAlt,
          disabledForegroundColor: t.textMuted,
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: buttonText,
          minimumSize: buttonMinSize,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.brand,
          foregroundColor: t.onBrand,
          disabledBackgroundColor: t.surfaceAlt,
          disabledForegroundColor: t.textMuted,
          surfaceTintColor: AppColors.transparent,
          shadowColor: AppColors.transparent,
          elevation: 0,
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: buttonText,
          minimumSize: buttonMinSize,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          side: BorderSide(color: t.outline),
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: buttonText,
          minimumSize: buttonMinSize,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.brandText,
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          textStyle: buttonText,
          minimumSize: const Size(48, 40),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.text,
          minimumSize: const Size.square(AppSizes.minTap),
          shape: buttonShape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.brandSubtle : t.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.brandText : t.text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: t.outline)),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.brand,
        foregroundColor: t.onBrand,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        extendedTextStyle: buttonText,
      ),

      // ── Selection controls ────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onBrand : t.outlineStrong,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.brand : t.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.transparent
              : t.outlineStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? t.brand
              : AppColors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(t.onBrand),
        side: BorderSide(color: t.outlineStrong, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXs),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.brand : t.outlineStrong,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.brand,
        inactiveTrackColor: t.surfaceAlt,
        thumbColor: t.brand,
        overlayColor: t.brand.withValues(alpha: 0.12),
      ),

      // ── Lists ─────────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: t.textMuted,
        textColor: t.text,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        minVerticalPadding: AppSpace.md,
        horizontalTitleGap: AppSpace.md,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        selectedColor: t.brandText,
        selectedTileColor: t.brandSubtle,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: t.textMuted,
        collapsedIconColor: t.textMuted,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      dividerTheme: DividerThemeData(color: t.outline, thickness: 1, space: 1),

      // ── Overlays ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brXl,
          side: BorderSide(color: t.outline),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: t.textMuted),
        barrierColor: t.scrim,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surfaceRaised,
        modalBackgroundColor: t.surfaceRaised,
        surfaceTintColor: AppColors.transparent,
        modalBarrierColor: t.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: t.outlineStrong.withValues(alpha: 0.6),
        dragHandleSize: const Size(36, 4),
        constraints: const BoxConstraints(maxWidth: 640),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.inverseSurface,
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: t.onInverse,
          fontSize: 14,
        ),
        actionTextColor: t.brand,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.inverseSurface,
          borderRadius: AppRadius.brSm,
        ),
        textStyle: textTheme.labelMedium!.copyWith(color: t.onInverse),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs + 2,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surfaceRaised,
        surfaceTintColor: AppColors.transparent,
        elevation: 6,
        shadowColor: t.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: BorderSide(color: t.outline),
        ),
        textStyle: textTheme.bodyMedium!.copyWith(fontSize: 15),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(AppColors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppRadius.brMd,
              side: BorderSide(color: t.outline),
            ),
          ),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: AppColors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
        headerBackgroundColor: t.surfaceRaised,
        headerForegroundColor: t.text,
        todayBorder: BorderSide(color: t.brand),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: t.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
      ),

      // ── Progress / scroll ─────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.brand,
        linearTrackColor: t.surfaceAlt,
        circularTrackColor: AppColors.transparent,
        linearMinHeight: 6,
        borderRadius: AppRadius.brPill,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(AppRadius.pill),
        thumbColor: WidgetStatePropertyAll(
          t.outlineStrong.withValues(alpha: 0.5),
        ),
      ),
      iconTheme: IconThemeData(color: t.text, size: AppSizes.iconLg),
    );
  }
}
