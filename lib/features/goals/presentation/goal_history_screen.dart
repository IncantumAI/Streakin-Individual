import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/goals/application/goal_providers.dart';
import 'package:streakin/features/goals/domain/goal.dart';

class GoalHistoryScreen extends ConsumerWidget {
  const GoalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final historyAsync = ref.watch(goalHistoryProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Past Goals')),
      body: historyAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (_, _) => const Center(child: Text('Could not load history')),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Text(
                'No past goals yet.',
                style: TextStyle(color: colors.textMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) =>
                _GoalHistoryTile(goal: goals[i], colors: colors),
          );
        },
      ),
    );
  }
}

class _GoalHistoryTile extends ConsumerWidget {
  const _GoalHistoryTile({required this.goal, required this.colors});
  final Goal goal;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(goalRepositoryStateProvider);
    return FutureBuilder<GoalSummary?>(
      future: repo?.getSummary(goal.id),
      builder: (_, snap) {
        final summary = snap.data;
        return InkWell(
          onTap: () => context.push('/goals/${goal.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                    _ReasonChip(reason: goal.archiveReason, colors: colors),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${goal.startDate.toIso()} → ${goal.endDate?.toIso() ?? 'open-ended'}',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${summary.elapsedDays} days · ${summary.alignmentPct != null ? '${summary.alignmentPct}% aligned' : 'No alignment data'} · ${summary.perfectDays} perfect days',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason, required this.colors});
  final GoalArchiveReason? reason;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (reason) {
      GoalArchiveReason.completed => ('Completed', colors.success),
      GoalArchiveReason.completedEarly => ('Completed early', colors.success),
      GoalArchiveReason.abandoned => ('Abandoned', colors.danger),
      GoalArchiveReason.replaced => ('Replaced', colors.textMuted),
      null => ('Archived', colors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
