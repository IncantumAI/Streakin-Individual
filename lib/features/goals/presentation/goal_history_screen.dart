import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/features/goals/application/goal_providers.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/shared/widgets/widgets.dart';

class GoalHistoryScreen extends ConsumerWidget {
  const GoalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final historyAsync = ref.watch(goalHistoryProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Past goals')),
      body: historyAsync.when(
        loading: () => const SkeletonList(count: 4, showLeading: false),
        error: (e, st) => ErrorState(
          error: e,
          stackTrace: st,
          title: 'Could not load history',
          onRetry: () => ref.invalidate(goalHistoryProvider),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return const EmptyState(
              icon: AppIcons.trackChangesOutlined,
              title: 'No past goals yet',
              message: 'Completed and archived goals will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpace.lg),
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
            itemBuilder: (ctx, i) => StaggeredEntrance(
              index: i,
              child: _GoalHistoryTile(goal: goals[i], colors: colors),
            ),
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
        return AppCard(
          onTap: () => context.push('/goals/${goal.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(goal.title, style: context.text.titleMedium),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  _ReasonChip(reason: goal.archiveReason, colors: colors),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${goal.startDate.toIso()} → ${goal.endDate?.toIso() ?? 'open-ended'}',
                style: context.text.bodySmall!.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    StatusPill('${summary.elapsedDays} days'),
                    StatusPill(
                      summary.alignmentPct != null
                          ? '${summary.alignmentPct}% aligned'
                          : 'No alignment data',
                    ),
                    StatusPill('${summary.perfectDays} perfect days'),
                  ],
                ),
              ],
            ],
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
    final (label, tone) = switch (reason) {
      GoalArchiveReason.completed => ('Completed', PillTone.success),
      GoalArchiveReason.completedEarly => ('Completed early', PillTone.success),
      GoalArchiveReason.abandoned => ('Abandoned', PillTone.danger),
      GoalArchiveReason.replaced => ('Replaced', PillTone.neutral),
      null => ('Archived', PillTone.neutral),
    };
    return StatusPill(label, tone: tone);
  }
}
