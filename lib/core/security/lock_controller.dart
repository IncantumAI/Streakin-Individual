// lib/core/security/lock_controller.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/core/logging/app_logger.dart';
import 'package:streakin/core/security/key_vault.dart';

final _log = AppLogger.get('LockController');

enum LockState { locked, unlocked }

class LockController extends Notifier<LockState> with WidgetsBindingObserver {
  static final provider =
      NotifierProvider<LockController, LockState>(LockController.new);

  // Default: 5 minutes. Short enough for security, long enough that normal
  // use (keyboard appearing, notification shade, system dialogs) never trips it.
  Duration _backgroundTimeout = const Duration(minutes: 5);

  Timer? _lockTimer;
  DateTime? _backgroundedAt;

  @override
  LockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _lockTimer?.cancel();
    });
    return LockState.locked;
  }

  bool get isLocked => state == LockState.locked;
  bool get isUnlocked => state == LockState.unlocked;

  void onUnlocked() {
    state = LockState.unlocked;
    _lockTimer?.cancel();
    _lockTimer = null;
    _backgroundedAt = null;
    _log.info('App unlocked');
  }

  Future<void> lock() => _executeLockSequence(reason: 'manual');

  void updateTimeouts({Duration? background}) {
    if (background != null) _backgroundTimeout = background;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // Truly backgrounded — start the timer now.
        _backgroundedAt = DateTime.now();
        _lockTimer?.cancel();
        _lockTimer = Timer(_backgroundTimeout,
            () => _executeLockSequence(reason: 'background_timeout'));

      case AppLifecycleState.inactive:
        // Keyboard, notification shade, split-screen resize, etc.
        // Do NOT start a timer here — this fires constantly during normal use.
        // The timer is only started on 'paused' (truly backgrounded).
        break;

      case AppLifecycleState.resumed:
        // App came back to foreground — cancel any pending lock timer.
        // If we were backgrounded long enough, lock immediately.
        final backgrounded = _backgroundedAt;
        _lockTimer?.cancel();
        _lockTimer = null;

        if (backgrounded != null && isUnlocked) {
          final elapsed = DateTime.now().difference(backgrounded);
          if (elapsed >= _backgroundTimeout) {
            _executeLockSequence(reason: 'background_timeout_on_resume');
          }
        }
        _backgroundedAt = null;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _lockTimer?.cancel();
        _executeLockSequence(reason: 'detached');
    }
  }

  @override
  void didHaveMemoryPressure() {
    _log.warning('Memory pressure — clearing image caches');
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> _executeLockSequence({required String reason}) async {
    if (isLocked) return;
    _log.info('Lock sequence: $reason');
    _lockTimer?.cancel();
    _lockTimer = null;
    try {
      ref.read(keyVaultProvider).dispose();
    } catch (_) {}
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    state = LockState.locked;
    _log.info('Lock sequence complete');
  }
}

final keyVaultProvider = Provider<KeyVault>((ref) {
  final vault = KeyVault();
  ref.onDispose(vault.dispose);
  return vault;
});
