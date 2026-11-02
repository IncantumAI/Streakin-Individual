// lib/shared/widgets/pressable_scale.dart
//
// Micro-interaction: subtle press-down scale for tappable surfaces.
// Instant (no scale) when motion is reduced.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/motion.dart';

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _set(bool v) {
    if (!_interactive || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = isMotionReduced(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !reduced ? widget.scale : 1,
        duration: AppDurations.press,
        curve: AppCurves.standard,
        child: widget.onTap == null && widget.onLongPress == null
            ? widget.child
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.enabled ? widget.onTap : null,
                onLongPress: widget.enabled ? widget.onLongPress : null,
                child: widget.child,
              ),
      ),
    );
  }
}
