import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/goals/application/goal_providers.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';

/// Zen line: "Day 42 of 100" (or "Day 42" for open-ended).
/// TODO (Phase 7 — Zen Mode): Wire GoalZenLine into Focus Zen and Writing Zen screens.
/// See decisions.md D21 for implementation details.
class GoalZenLine extends ConsumerWidget {
  const GoalZenLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(goalClockProvider);
    if (clock == null || clock.phase == GoalPhase.upcoming) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final text = clock.goal.kind == GoalKind.dated && clock.totalDays != null
        ? 'Day ${clock.dayNumber} of ${clock.totalDays}'
        : 'Day ${clock.dayNumber}';

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: colors.textMuted.withAlpha(153),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
