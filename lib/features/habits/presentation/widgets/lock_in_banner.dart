// lib/features/habits/presentation/widgets/lock_in_banner.dart
// Shown when all habits for today are complete. Spec §4.2 FR-HAB-5.
// TODO(rive): replace CustomPainter padlock with Rive asset when available.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';

class LockInBanner extends StatelessWidget {
  const LockInBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.celebBrand.withValues(alpha: 0.15),
            AppColors.celebTeal.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.celebBrand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.lockFill, color: AppColors.celebBrand, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day locked in! 🎉',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                Text(
                  'All habits complete for today',
                  style: TextStyle(fontSize: 13, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
