// lib/shared/feedback/haptics.dart
//
// Single entry point for haptic feedback. Spec §4.10 (haptics on/off) and
// §5.6 (mobile: haptics). All widgets go through [AppHaptics] so the user's
// Haptics setting is honoured everywhere.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';

final hapticsProvider = Provider<AppHaptics>(
  (ref) => AppHaptics(enabled: ref.watch(hapticsEnabledProvider)),
);

class AppHaptics {
  const AppHaptics({required this.enabled});

  final bool enabled;

  bool get _active {
    if (!enabled) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Generic light tap (buttons, toggles, uncheck).
  void tap() {
    if (_active) HapticFeedback.lightImpact();
  }

  /// Tab / segment / picker change.
  void selection() {
    if (_active) HapticFeedback.selectionClick();
  }

  /// Completing something (habit check, todo done).
  void success() {
    if (_active) HapticFeedback.mediumImpact();
  }

  /// Soft warning (destructive confirmation shown).
  void warning() {
    if (_active) HapticFeedback.lightImpact();
  }

  /// Failure (wrong password, validation error).
  void error() {
    if (_active) HapticFeedback.heavyImpact();
  }

  /// Celebration (lock-in, milestone): double pulse on consecutive frames.
  void celebrate() {
    if (!_active) return;
    HapticFeedback.mediumImpact();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.lightImpact();
    });
  }
}
