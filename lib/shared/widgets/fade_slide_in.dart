// lib/shared/widgets/fade_slide_in.dart
//
// Entrance animations. One controller per widget, delays expressed as an
// Interval on that controller (no Timers, so widget tests never see pending
// timers). Instant when motion is reduced.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:streakin/core/design/motion.dart';

/// Fades + slides [child] up into place once, after an optional [delay].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppDurations.slow,
    this.offset = 8,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Vertical start offset in logical pixels.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    final begin = total.inMicroseconds == 0
        ? 0.0
        : widget.delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1, curve: AppCurves.emphasized),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}

/// List-item entrance: delay grows with [index], capped at
/// [AppDurations.staggerMax].
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ms = math.min(
      index * AppDurations.stagger.inMilliseconds,
      AppDurations.staggerMax.inMilliseconds,
    );
    return FadeSlideIn(
      delay: Duration(milliseconds: ms),
      offset: 12,
      child: child,
    );
  }
}
