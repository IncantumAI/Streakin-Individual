// lib/features/habits/presentation/widgets/habit_check_button.dart
// Spring-animated check button. Spec §5.5: ring stroke + scale 0.9→1.1→1, 250ms.
// Checking fills the circle with the habit accent, draws the tick in and
// emits a fading ripple ring; unchecking is a quick 150ms reverse.
// 48px hit area around the 32px visual (spec §5.6 touch targets).

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/shared/feedback/haptics.dart';

class HabitCheckButton extends ConsumerStatefulWidget {
  const HabitCheckButton({
    required this.isDone,
    required this.isRest,
    required this.accentColor,
    required this.onTap,
    super.key,
  });
  final bool isDone;
  final bool isRest;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  ConsumerState<HabitCheckButton> createState() => _HabitCheckButtonState();
}

class _HabitCheckButtonState extends ConsumerState<HabitCheckButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _ripple;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppDurations.habitCheck);
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ripple = CurvedAnimation(parent: _ctrl, curve: AppCurves.enter);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final reduced = isMotionReduced(context);
    final haptics = ref.read(hapticsProvider);
    if (widget.isDone) {
      haptics.tap();
    } else {
      haptics.success();
      if (!reduced) _ctrl.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = widget.isDone || widget.isRest;
    final ringColor = active ? widget.accentColor : c.outlineStrong;
    final d = resolvedDuration(
      context,
      widget.isDone ? AppDurations.habitCheck : AppDurations.habitUncheck,
    );

    return Semantics(
      button: true,
      checked: widget.isDone,
      label: widget.isDone ? 'Mark not done' : 'Mark done',
      child: InkResponse(
        onTap: _handleTap,
        radius: 24,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  final r = _ripple.value;
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (_ctrl.isAnimating)
                        Container(
                          width: 32 + 18 * r,
                          height: 32 + 18 * r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.accentColor.withValues(
                                alpha: (1 - r) * 0.6,
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                      Transform.scale(scale: _scale.value, child: child),
                    ],
                  );
                },
                child: AnimatedContainer(
                  duration: d,
                  curve: AppCurves.enter,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor,
                      width: widget.isDone ? 0 : 2,
                    ),
                    color: widget.isDone
                        ? widget.accentColor
                        : widget.isRest
                        ? widget.accentColor.withValues(alpha: 0.15)
                        : AppColors.transparent,
                  ),
                  child: widget.isRest && !widget.isDone
                      ? Icon(AppIcons.coffee, size: 16, color: ringColor)
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: widget.isDone ? 1 : 0),
                          duration: d,
                          curve: AppCurves.emphasized,
                          builder: (context, t, _) => CustomPaint(
                            painter: _TickPainter(
                              progress: t,
                              color: c.onBrand,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a check mark progressively (stroke draw-in).
class _TickPainter extends CustomPainter {
  _TickPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final p1 = Offset(w * 0.28, h * 0.52);
    final p2 = Offset(w * 0.44, h * 0.67);
    final p3 = Offset(w * 0.73, h * 0.36);
    final first = (p2 - p1).distance;
    final second = (p3 - p2).distance;
    final len = (first + second) * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (len <= first) {
      final t = len / first;
      path.lineTo(lerpDouble(p1.dx, p2.dx, t)!, lerpDouble(p1.dy, p2.dy, t)!);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (len - first) / second;
      path.lineTo(lerpDouble(p2.dx, p3.dx, t)!, lerpDouble(p2.dy, p3.dy, t)!);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.progress != progress || old.color != color;
}
