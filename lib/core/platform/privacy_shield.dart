// lib/core/platform/privacy_shield.dart
// Spec §8.5: when the app is inactive/backgrounded, cover the UI immediately
// (before the OS snapshots it for the app switcher). Clears on resume.

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';

class PrivacyShield extends StatefulWidget {
  const PrivacyShield({required this.child, super.key});
  final Widget child;

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cover =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (cover != _covered) setState(() => _covered = cover);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_covered)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(child: Icon(AppIcons.lock, size: 48)),
            ),
          ),
      ],
    );
  }
}
