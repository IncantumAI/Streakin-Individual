// lib/shared/widgets/skeleton.dart
//
// Skeleton loading placeholders. A single [Shimmer] drives every skeleton
// below it; it is static when motion is reduced (so pumpAndSettle never hangs
// under reduced motion and the UI stays calm).

import 'package:flutter/material.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final dx = _controller.value * 3 - 1; // -1 → 2
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(dx - 1, 0),
            end: Alignment(dx, 0),
            colors: [c.surfaceAlt, c.surfaceRaised, c.surfaceAlt],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// A single grey placeholder block.
class Skeleton extends StatelessWidget {
  const Skeleton.box({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.md,
  }) : _circle = false;

  const Skeleton.line({super.key, this.width, this.height = 12})
    : radius = AppRadius.xs,
      _circle = false;

  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 0,
      _circle = true;

  final double? width;
  final double height;
  final double radius;
  final bool _circle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        shape: _circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: _circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Generic list skeleton: avatar + two text lines per row.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.showLeading = true,
  });

  final int count;
  final EdgeInsetsGeometry padding;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.outline),
            borderRadius: AppRadius.brLg,
          ),
          child: Row(
            children: [
              if (showLeading) ...[
                const Skeleton.circle(size: 36),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: i.isEven ? 0.6 : 0.45,
                      child: const Skeleton.line(height: 14),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    FractionallySizedBox(
                      widthFactor: i.isEven ? 0.35 : 0.5,
                      child: const Skeleton.line(height: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder sized like a card while its data loads.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Skeleton.box(height: height, radius: AppRadius.lg),
    );
  }
}
