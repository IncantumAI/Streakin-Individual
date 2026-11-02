// lib/features/habits/presentation/widgets/habit_check_button.dart
// Spring-animated check button. Spec §5.5: ring stroke + scale 0.9→1.1→1, 250ms.

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:streakin/core/design/motion.dart';

class HabitCheckButton extends StatefulWidget {
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
  State<HabitCheckButton> createState() => _HabitCheckButtonState();
}

class _HabitCheckButtonState extends State<HabitCheckButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppDurations.habitCheck);
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final reduced = isMotionReduced(context);
    if (!reduced) {
      _ctrl.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDone || widget.isRest
        ? widget.accentColor
        : Theme.of(context).colorScheme.outline;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: RepaintBoundary(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              color: widget.isDone
                  ? color.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: widget.isDone
                ? Icon(AppIcons.check, size: 18, color: color)
                : widget.isRest
                ? Icon(AppIcons.coffee, size: 16, color: color)
                : null,
          ),
        ),
      ),
    );
  }
}
