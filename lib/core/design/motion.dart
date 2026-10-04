// lib/core/design/motion.dart
//
// Motion tokens and reduced-motion helper.
// Spec §5.5: every animation honours MediaQuery.disableAnimationsOf + in-app Motion setting.

import 'package:flutter/material.dart';

/// Duration tokens (spec §5.5).
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration celebrate = Duration(milliseconds: 900);

  // Named durations for specific animations
  static const Duration habitCheck = Duration(milliseconds: 250);
  static const Duration habitUncheck = Duration(milliseconds: 150);
  static const Duration progressRing = Duration(milliseconds: 400);
  static const Duration streakCounter = Duration(milliseconds: 350);
  static const Duration lockIn = Duration(milliseconds: 900);
  static const Duration milestone = Duration(milliseconds: 1200);
  static const Duration chartDrawIn = Duration(milliseconds: 600);
  static const Duration vaultMorph = Duration(milliseconds: 400);
  static const Duration themeSwitch = Duration(milliseconds: 250);
  static const Duration pageTransition = Duration(milliseconds: 300);
}

/// Curve tokens (spec §5.5).
class AppCurves {
  AppCurves._();

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// Spring for habit check animation.
  static const SpringDescription habitSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 20,
  );
}

/// Returns [Duration.zero] when reduced motion is requested (OS or in-app setting).
/// Pass [context] to read MediaQuery; pass [inAppReduced] from the settings provider.
Duration resolvedDuration(
  BuildContext context,
  Duration full, {
  bool inAppReduced = false,
}) {
  final osReduced = MediaQuery.disableAnimationsOf(context);
  return (osReduced || inAppReduced) ? Duration.zero : full;
}

/// True when any motion reduction is active.
bool isMotionReduced(BuildContext context, {bool inAppReduced = false}) {
  return MediaQuery.disableAnimationsOf(context) || inAppReduced;
}
