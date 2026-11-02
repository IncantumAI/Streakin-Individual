// lib/features/habits/presentation/widgets/lock_in_banner.dart
// Shown when all habits for today are complete. Spec §4.2 FR-HAB-5.
// Enters with a scale + fade and the padlock "clicks" shut.
// TODO(rive): replace CustomPainter padlock with Rive asset when available.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/typography.dart';

class LockInBanner extends StatelessWidget {
  const LockInBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: resolvedDuration(context, AppDurations.lockIn),
      curve: AppCurves.emphasized,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.sm,
        ),
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.celebBrand.withValues(alpha: 0.18),
              AppColors.celebAmber.withValues(alpha: 0.10),
              AppColors.celebTeal.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: AppRadius.brLg,
          border: Border.all(
            color: AppColors.celebBrand.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.brand,
                borderRadius: AppRadius.brMd,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: resolvedDuration(context, AppDurations.lockIn),
                curve: const Interval(0.45, 1, curve: Curves.elasticOut),
                builder: (context, t, _) => Transform.translate(
                  offset: Offset(0, -3 * (1 - t)),
                  child: Icon(
                    t > 0.5 ? AppIcons.lockFill : AppIcons.lockOpen,
                    color: colors.onBrand,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day locked in', style: context.text.titleMedium),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    'All habits complete for today',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
