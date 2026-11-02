// lib/shared/widgets/app_card.dart
//
// The one card surface used across the app. Spec §5.1: thin outlines instead
// of heavy shadows; soft elevation only for floating elements.
// Tappable cards get press-scale, ink ripple, hover outline (desktop) and an
// optional secondary-click handler for context menus.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/elevation.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/shared/widgets/pressable_scale.dart';

enum AppCardVariant {
  /// Surface + hairline outline (default).
  outlined,

  /// Subtle filled surface, no outline (nested / secondary content).
  filled,

  /// Brand-tinted hero surface.
  brand,

  /// Floating surface with soft shadow.
  raised,
}

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.margin = EdgeInsets.zero,
    this.variant = AppCardVariant.outlined,
    this.borderRadius = AppRadius.brLg,
    this.color,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final AppCardVariant variant;
  final BorderRadius borderRadius;

  /// Overrides the variant's background.
  final Color? color;

  /// Overrides the variant's border.
  final Color? borderColor;
  final String? semanticLabel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  bool get _tappable => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (
      Color bg,
      Color? border,
      List<BoxShadow> shadow,
    ) = switch (widget.variant) {
      AppCardVariant.outlined => (c.surface, c.outline, AppElevation.none),
      AppCardVariant.filled => (c.surfaceAlt, null, AppElevation.none),
      AppCardVariant.brand => (
        c.brandSubtle,
        c.brand.withValues(alpha: 0.35),
        AppElevation.none,
      ),
      AppCardVariant.raised => (
        c.surfaceRaised,
        c.outline,
        AppElevation.floating(c),
      ),
    };

    final effectiveBorder = widget.borderColor ?? border;
    final hoverBorder = _tappable && _hovered
        ? (widget.variant == AppCardVariant.brand
              ? c.brand
              : c.outlineStrong.withValues(alpha: 0.6))
        : effectiveBorder;

    Widget content = Padding(padding: widget.padding, child: widget.child);

    if (_tappable || widget.onSecondaryTapDown != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          onHover: (h) => setState(() => _hovered = h),
          child: content,
        ),
      );
    }

    Widget card = AnimatedContainer(
      duration: resolvedDuration(context, AppDurations.fast),
      curve: AppCurves.standard,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.color ?? bg,
        borderRadius: widget.borderRadius,
        border: hoverBorder == null ? null : Border.all(color: hoverBorder),
        boxShadow: shadow,
      ),
      child: ClipRRect(borderRadius: widget.borderRadius, child: content),
    );

    if (_tappable) {
      card = PressableScale(scale: 0.985, child: card);
    }

    if (widget.semanticLabel != null) {
      card = Semantics(
        label: widget.semanticLabel,
        button: _tappable,
        child: card,
      );
    }
    return card;
  }
}
