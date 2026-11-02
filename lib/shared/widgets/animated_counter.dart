// lib/shared/widgets/animated_counter.dart
//
// Spec §5.5 digit roll (350 ms): the number slides up when it grows and down
// when it shrinks. Tabular figures avoid width jitter. Instant when reduced.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/typography.dart';

class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = AppDurations.streakCounter,
    this.semanticsLabel,
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final String? semanticsLabel;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> {
  bool _up = true;

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _up = widget.value > oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: AppTypography.tabular,
    );
    return Semantics(
      label: widget.semanticsLabel,
      excludeSemantics: widget.semanticsLabel != null,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: resolvedDuration(context, widget.duration),
          switchInCurve: AppCurves.enter,
          switchOutCurve: AppCurves.exit,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(widget.value);
            final dir = _up ? 1.0 : -1.0;
            final begin = Offset(0, (incoming ? 0.6 : -0.6) * dir);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: begin,
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          child: Text(
            '${widget.prefix}${widget.value}${widget.suffix}',
            key: ValueKey(widget.value),
            style: style,
          ),
        ),
      ),
    );
  }
}
