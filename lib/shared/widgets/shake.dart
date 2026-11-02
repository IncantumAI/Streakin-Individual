// lib/shared/widgets/shake.dart
//
// Horizontal damped shake for error feedback (wrong password, invalid form).
// No movement when motion is reduced.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:streakin/core/design/motion.dart';

class ShakeController extends ChangeNotifier {
  void shake() => notifyListeners();
}

class Shake extends StatefulWidget {
  const Shake({
    super.key,
    required this.controller,
    required this.child,
    this.distance = 10,
  });

  final ShakeController controller;
  final Widget child;
  final double distance;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AppDurations.shake,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
    }
  }

  void _onShake() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: widget.child,
      builder: (context, child) {
        final t = _anim.value;
        // 3 oscillations, linearly damped; ends exactly at 0.
        final dx = math.sin(t * math.pi * 6) * (1 - t) * widget.distance;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
