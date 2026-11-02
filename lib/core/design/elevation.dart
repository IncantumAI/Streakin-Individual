// lib/core/design/elevation.dart
//
// Spec §5.1: thin outlines instead of heavy shadows; soft elevation only for
// floating elements. Shadows derive from the theme's `shadow` token.

import 'package:flutter/painting.dart';
import 'package:streakin/core/design/tokens.dart';

class AppElevation {
  AppElevation._();

  /// Cards and inline surfaces: no shadow, outline only.
  static const List<BoxShadow> none = [];

  /// FAB, nav bar, floating buttons.
  static List<BoxShadow> floating(AppColorTokens t) => [
    BoxShadow(color: t.shadow, blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(color: t.shadow, blurRadius: 2, offset: const Offset(0, 1)),
  ];

  /// Dialogs, menus, popovers.
  static List<BoxShadow> overlay(AppColorTokens t) => [
    BoxShadow(color: t.shadow, blurRadius: 32, offset: const Offset(0, 12)),
    BoxShadow(color: t.shadow, blurRadius: 4, offset: const Offset(0, 2)),
  ];

  /// Soft coloured glow for brand / celebration elements.
  static List<BoxShadow> glow(Color color, {double strength = 0.35}) => [
    BoxShadow(
      color: color.withValues(alpha: strength),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
