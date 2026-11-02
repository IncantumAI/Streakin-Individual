import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/application/goal_providers.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';
import 'package:streakin/features/goals/presentation/goal_create_sheet.dart';
import 'package:streakin/shared/widgets/widgets.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({required this.goalId, super.key});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final clockState = ref.watch(goalClockProvider);
    final goalAsync = ref.watch(activeGoalProvider);
    final alignAsync = ref.watch(goalAlignmentProvider);
    final liveAsync = ref.watch(goalTodayLiveProvider);
    final linksAsync = ref.watch(activeGoalLinksProvider);

    return goalAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(),
        body: const SkeletonList(count: 3, showLeading: false),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(),
        body: ErrorState(
          error: e,
          stackTrace: st,
          onRetry: () => ref.invalidate(activeGoalProvider),
        ),
      ),
      data: (goal) {
        if (goal == null || goal.id != goalId) {
          return _ArchivedGoalDetail(goalId: goalId);
        }
        final clock = clockState;
        if (clock == null) return const SizedBox.shrink();

        final sections = <Widget>[
          _CountdownHeader(clock: clock, colors: colors),
          const SizedBox(height: AppSpace.md),
          AppCard(
            child: goal.kind == GoalKind.dated
                ? _TimelineBar(clock: clock, colors: colors)
                : _MilestoneTrack(clock: clock, colors: colors),
          ),
          const SizedBox(height: AppSpace.md),
          _AlignmentSection(
            alignAsync: alignAsync,
            liveAsync: liveAsync,
            colors: colors,
          ),
          const SectionHeader('Linked habits'),
          linksAsync.when(
            loading: () => const SkeletonCard(height: 80),
            error: (e, st) => ErrorState.inline(error: e, stackTrace: st),
            data: (links) =>
                _LinkedHabitsSection(links: links, goal: goal, colors: colors),
          ),
          const SectionHeader('Actions'),
          _ActionsSection(goal: goal, colors: colors),
          const SizedBox(height: AppSpace.sm),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colors.textMuted),
              onPressed: () => context.push('/goals/history'),
              icon: const Icon(AppIcons.archive, size: AppSizes.iconSm),
              label: const Text('Past goals'),
            ),
          ),
        ];

        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            title: Text(goal.title),
            actions: [
              IconButton(
                icon: const Icon(AppIcons.edit),
                tooltip: 'Edit goal',
                onPressed: () => showGoalCreateSheet(context, existing: goal),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
          ),
          body: ReadableListView(
            children: [
              for (var i = 0; i < sections.length; i++)
                StaggeredEntrance(index: i, child: sections[i]),
            ],
          ),
        );
      },
    );
  }
}

String _fmtDate(LocalDate d) =>
    DateFormat('d MMM yyyy').format(DateTime(d.year, d.month, d.day));

class _CountdownHeader extends StatelessWidget {
  const _CountdownHeader({required this.clock, required this.colors});
  final GoalClockState clock;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    final countdown =
        clock.goal.kind == GoalKind.dated &&
        clock.phase == GoalPhase.active &&
        clock.daysLeft != null;
    final value = countdown ? clock.daysLeft! : clock.dayNumber;
    return AppCard(
      variant: AppCardVariant.brand,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusPill(
                clock.caption,
                tone: clock.isFinalStretch ? PillTone.warning : PillTone.brand,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCounter(
                value: value,
                semanticsLabel: '$value ${countdown ? 'days left' : 'days in'}',
                style: AppTypography.numeric.copyWith(
                  fontSize: 64,
                  color: colors.text,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                clock.goal.kind == GoalKind.dated &&
                        clock.phase == GoalPhase.active
                    ? 'days left'
                    : 'days in',
                style: context.text.titleMedium!.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          if (clock.goal.why != null && clock.goal.why!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md),
              child: Text(
                '“${clock.goal.why!}”',
                style: context.text.bodyMedium!.copyWith(
                  color: colors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated rounded progress bar.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.colors});
  final double value;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: resolvedDuration(context, AppDurations.chartDrawIn),
      curve: AppCurves.emphasized,
      builder: (_, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: 10,
        backgroundColor: colors.surfaceAlt,
        color: colors.brand,
      ),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({required this.clock, required this.colors});
  final GoalClockState clock;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    final progress = clock.progress ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Timeline', style: context.text.titleSmall)),
            Text(
              '${(progress * 100).round()}%',
              style: context.text.labelLarge!.copyWith(
                color: colors.brandText,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        _Bar(value: progress, colors: colors),
        const SizedBox(height: AppSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmtDate(clock.goal.startDate), style: context.text.bodySmall),
            if (clock.goal.endDate != null)
              Text(
                _fmtDate(clock.goal.endDate!),
                style: context.text.bodySmall,
              ),
          ],
        ),
      ],
    );
  }
}

class _MilestoneTrack extends StatelessWidget {
  const _MilestoneTrack({required this.clock, required this.colors});
  final GoalClockState clock;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    final next = clock.nextMilestone ?? 0;
    final progress = clock.progressToNextMilestone ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              AppIcons.milestone,
              size: AppSizes.iconMd,
              color: colors.brandText,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                'Progress to day $next',
                style: context.text.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        _Bar(value: progress, colors: colors),
        const SizedBox(height: AppSpace.sm),
        Text(
          '${clock.daysToNextMilestone ?? 0} days to go',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _AlignmentSection extends StatelessWidget {
  const _AlignmentSection({
    required this.alignAsync,
    required this.liveAsync,
    required this.colors,
  });
  final AsyncValue<AlignmentStats?> alignAsync;
  final AsyncValue<({int done, int scheduled})> liveAsync;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    final stats = alignAsync.value;
    final live = liveAsync.value;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alignment', style: context.text.titleSmall),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              _StatTile(
                label: 'Overall',
                value: stats?.alignmentPct != null
                    ? '${stats!.alignmentPct}%'
                    : '—',
                colors: colors,
              ),
              _StatTile(
                label: 'Perfect days',
                value: '${stats?.perfectDays ?? 0}',
                colors: colors,
              ),
              _StatTile(
                label: 'Best streak',
                value: '${stats?.bestStreak ?? 0}d',
                colors: colors,
              ),
            ],
          ),
          if (live != null && live.scheduled > 0) ...[
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                StatusPill(
                  'Today ${live.done}/${live.scheduled}',
                  tone: live.done == live.scheduled
                      ? PillTone.success
                      : PillTone.neutral,
                  icon: AppIcons.check,
                ),
                const SizedBox(width: AppSpace.sm),
                Text('linked habits done', style: context.text.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.colors,
  });
  final String label;
  final String value;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.numeric.copyWith(
              fontSize: 24,
              color: colors.text,
            ),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            label,
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LinkedHabitsSection extends ConsumerWidget {
  const _LinkedHabitsSection({
    required this.links,
    required this.goal,
    required this.colors,
  });
  final List<GoalHabitLink> links;
  final Goal goal;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openLinks = links.where((l) => l.isOpen).toList();
    if (openLinks.isEmpty) {
      return AppCard(
        variant: AppCardVariant.filled,
        child: EmptyState(
          compact: true,
          icon: AppIcons.link,
          title: 'No habits linked',
          message: 'Link habits so they count towards this goal.',
          action: OutlinedButton(
            onPressed: () => showGoalCreateSheet(context, existing: goal),
            child: const Text('Link habits'),
          ),
        ),
      );
    }
    return SettingsGroup(
      children: [
        for (final link in openLinks)
          _LinkedHabitTile(link: link, goal: goal, colors: colors),
      ],
    );
  }
}

class _LinkedHabitTile extends ConsumerWidget {
  const _LinkedHabitTile({
    required this.link,
    required this.goal,
    required this.colors,
  });
  final GoalHabitLink link;
  final Goal goal;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(habitCompletionPortStateProvider);
    return FutureBuilder<List<HabitRef>>(
      future: port?.watchHabits({link.habitId}).first,
      builder: (_, snap) {
        final name = snap.data?.firstOrNull?.name ?? '…';
        return SettingsTile(
          icon: AppIcons.link,
          title: name,
          trailing: TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.textMuted),
            onPressed: () async {
              final svc = ref.read(goalLifecycleServiceProvider);
              if (svc != null) await svc.unlinkHabit(goal, link.habitId);
            },
            child: const Text('Unlink'),
          ),
        );
      },
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({required this.goal, required this.colors});
  final Goal goal;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      children: [
        SettingsTile.nav(
          icon: AppIcons.edit,
          title: 'Edit goal',
          onTap: () => showGoalCreateSheet(context, existing: goal),
        ),
        SettingsTile(
          icon: AppIcons.checkCircleOutline,
          title: 'Complete early',
          subtitle: 'Archive as completed',
          onTap: () async {
            final confirm = await showConfirmDialog(
              context,
              title: 'Complete early?',
              message: 'This will archive the goal as completed early.',
              confirmLabel: 'Complete',
            );
            if (!confirm) return;
            final svc = ref.read(goalLifecycleServiceProvider);
            if (svc != null) await svc.completeEarly(goal);
            if (context.mounted) {
              context.celebrate(CelebrationKind.goalDone);
              context.pop();
            }
          },
        ),
        SettingsTile(
          icon: AppIcons.cancelOutlined,
          title: 'Abandon',
          subtitle: 'Archive without completing',
          destructive: true,
          onTap: () async {
            final confirm = await showConfirmDialog(
              context,
              title: 'Abandon goal?',
              message: 'This will archive the goal as abandoned.',
              confirmLabel: 'Abandon',
              destructive: true,
            );
            if (!confirm) return;
            final svc = ref.read(goalLifecycleServiceProvider);
            if (svc != null) await svc.abandon(goal);
            if (context.mounted) context.pop();
          },
        ),
      ],
    );
  }
}

// ── Archived goal detail ──────────────────────────────────────────────────────

class _ArchivedGoalDetail extends ConsumerWidget {
  const _ArchivedGoalDetail({required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.watch(goalRepositoryStateProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Goal summary')),
      body: FutureBuilder<GoalSummary?>(
        future: repo?.getSummary(goalId),
        builder: (_, snap) {
          final summary = snap.data;
          if (summary == null) {
            return const SkeletonList(count: 3, showLeading: false);
          }
          return _SummaryView(summary: summary, colors: colors);
        },
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary, required this.colors});
  final GoalSummary summary;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return ReadableListView(
      children: [
        const SizedBox(height: AppSpace.lg),
        AppCard(
          variant: AppCardVariant.brand,
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            children: [
              Text(
                '${summary.elapsedDays}',
                style: AppTypography.numeric.copyWith(
                  fontSize: 56,
                  color: colors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'days of ${summary.totalDays}',
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        SettingsGroup(
          children: [
            _SummaryRow(
              label: 'Alignment',
              value: summary.alignmentPct != null
                  ? '${summary.alignmentPct}%'
                  : '—',
              colors: colors,
            ),
            _SummaryRow(
              label: 'Perfect days',
              value: '${summary.perfectDays}',
              colors: colors,
            ),
            _SummaryRow(
              label: 'Best streak',
              value: '${summary.bestStreak} days',
              colors: colors,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        FilledButton.icon(
          onPressed: () => showGoalCreateSheet(context),
          icon: const Icon(AppIcons.add, size: AppSizes.iconMd),
          label: const Text('Set your next goal'),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.colors,
  });
  final String label;
  final String value;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: label,
      trailing: Text(
        value,
        style: context.text.titleSmall!.copyWith(
          fontFeatures: AppTypography.tabular,
        ),
      ),
    );
  }
}
