// lib/shared/widgets/celebration_overlay.dart
//
// Spec §5.5 "joyful wins": lock-in confetti (≤1 s, ≤120 particles), milestone
// and goal-complete celebrations. Mounted once above the Navigator (app.dart)
// so any screen can call `context.celebrate(...)`.
//
// Reduced motion: no particles; a static toast + haptic only.

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/core/design/elevation.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/shared/feedback/haptics.dart';

enum CelebrationKind {
  lockIn('Day locked in', 'Every habit done today'),
  milestone('Milestone reached', 'Keep the streak going'),
  goalDone('Goal complete', 'You did it');

  const CelebrationKind(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

extension CelebrateContext on BuildContext {
  /// Fires a celebration if a [CelebrationOverlay] is mounted above.
  void celebrate(CelebrationKind kind, {String? title, String? subtitle}) {
    findAncestorStateOfType<_CelebrationOverlayState>()?._fire(
      kind,
      title: title,
      subtitle: subtitle,
    );
  }
}

class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 700),
  );

  /// Drives the toast: fade in (0–10 %), hold, fade out (85–100 %).
  late final AnimationController _toast = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final Animation<double> _toastOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 10),
    TweenSequenceItem(tween: ConstantTween(1), weight: 75),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 15),
  ]).animate(_toast);

  String _title = '';
  String _subtitle = '';

  void _fire(CelebrationKind kind, {String? title, String? subtitle}) {
    if (!mounted) return;
    ref.read(hapticsProvider).celebrate();
    setState(() {
      _title = title ?? kind.title;
      _subtitle = subtitle ?? kind.subtitle;
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!reduced) _confetti.play();
    _toast.forward(from: 0);
  }

  @override
  void dispose() {
    _confetti.dispose();
    _toast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  blastDirection: math.pi / 2,
                  emissionFrequency: 0.08,
                  numberOfParticles: 24,
                  maxBlastForce: 28,
                  minBlastForce: 10,
                  gravity: 0.25,
                  particleDrag: 0.06,
                  colors: AppColors.celebration,
                  strokeColor: AppColors.transparent,
                  minimumSize: const Size(8, 5),
                  maximumSize: const Size(14, 8),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _toast,
                builder: (context, child) {
                  final v = _toastOpacity.value;
                  if (v == 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, (1 - v) * -12),
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg,
                        vertical: AppSpace.md,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: c.brand.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          ...AppElevation.overlay(c),
                          ...AppElevation.glow(c.brand, strength: 0.25),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_title, style: context.text.titleSmall),
                          Text(_subtitle, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
