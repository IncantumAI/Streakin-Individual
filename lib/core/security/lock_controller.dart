// lib/core/security/lock_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/core/logging/app_logger.dart';
import 'package:streakin/core/security/key_vault.dart';

final _log = AppLogger.get('LockController');

enum LockState { locked, unlocked }

class LockController extends Notifier<LockState> with WidgetsBindingObserver {
  static final provider =
      NotifierProvider<LockController, LockState>(LockController.new);

  Duration _backgroundTimeout = const Duration(seconds: 30);

  @override
  LockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return LockState.locked;
  }

  bool get isLocked => state == LockState.locked;
  bool get isUnlocked => state == LockState.unlocked;

  void onUnlocked() {
    state = LockState.unlocked;
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
      case AppLifecycleState.inactive:
        Future.delayed(
            _backgroundTimeout,
            () => _executeLockSequence(reason: 'background_timeout'));
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
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
