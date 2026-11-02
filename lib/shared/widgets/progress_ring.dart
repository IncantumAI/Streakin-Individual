// lib/shared/widgets/progress_ring.dart
//
// Spec §5.5: progress ring animates 400 ms between values. Instant when
// motion is reduced.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/tokens.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 6,
    this.color,
    this.trackColor,
    this.center,
    this.duration = AppDurations.progressRing,
    this.semanticsLabel,
  });

  /// 0.0 – 1.0.
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? center;
  final Duration duration;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final target = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: '${(target * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: resolvedDuration(context, duration),
          curve: AppCurves.emphasized,
          builder: (context, v, child) => CustomPaint(
            painter: _RingPainter(
              progress: v,
              color: color ?? c.brand,
              track: trackColor ?? c.surfaceAlt,
              stroke: stroke,
            ),
            child: child,
          ),
          child: center == null ? null : Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
