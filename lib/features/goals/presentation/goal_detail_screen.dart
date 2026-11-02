import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/goals/application/goal_providers.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';
import 'package:streakin/features/goals/presentation/goal_create_sheet.dart';

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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => const Scaffold(body: Center(child: Text('Error'))),
      data: (goal) {
        if (goal == null || goal.id != goalId) {
          return _ArchivedGoalDetail(goalId: goalId);
        }
        final clock = clockState;
        if (clock == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            title: Text(
              goal.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(AppIcons.edit),
                onPressed: () => showGoalCreateSheet(context, existing: goal),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CountdownHeader(clock: clock, colors: colors),
              const SizedBox(height: 16),
              if (goal.kind == GoalKind.dated)
                _TimelineBar(clock: clock, colors: colors)
              else
                _MilestoneTrack(clock: clock, colors: colors),
              const SizedBox(height: 16),
              _AlignmentSection(
                alignAsync: alignAsync,
                liveAsync: liveAsync,
                colors: colors,
              ),
              const SizedBox(height: 16),
              linksAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (links) => _LinkedHabitsSection(
                  links: links,
                  goal: goal,
                  colors: colors,
                ),
              ),
              const SizedBox(height: 16),
              _ActionsSection(goal: goal, colors: colors),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/goals/history'),
                child: Text(
                  'Past goals',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _CountdownHeader extends StatelessWidget {
  const _CountdownHeader({required this.clock, required this.colors});
  final GoalClockState clock;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          Text(
            clock.caption,
            style: TextStyle(fontSize: 14, color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                clock.goal.kind == GoalKind.dated &&
                        clock.phase == GoalPhase.active &&
                        clock.daysLeft != null
                    ? '${clock.daysLeft}'
                    : '${clock.dayNumber}',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: colors.brand,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                clock.goal.kind == GoalKind.dated &&
                        clock.phase == GoalPhase.active
                    ? 'days left'
                    : 'days in',
                style: TextStyle(fontSize: 16, color: colors.textMuted),
              ),
            ],
          ),
          if (clock.goal.why != null && clock.goal.why!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                clock.goal.why!,
                style: TextStyle(
                  fontSize: 13,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              clock.goal.startDate.toIso(),
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
            if (clock.goal.endDate != null)
              Text(
                clock.goal.endDate!.toIso(),
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: colors.brand.withAlpha(30),
            valueColor: AlwaysStoppedAnimation(colors.brand),
          ),
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
        Text(
          'Progress to Day $next',
          style: TextStyle(fontSize: 13, color: colors.textMuted),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: colors.brand.withAlpha(30),
            valueColor: AlwaysStoppedAnimation(colors.brand),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${clock.daysToNextMilestone ?? 0} days to go',
          style: TextStyle(fontSize: 11, color: colors.textMuted),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alignment',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            Text(
              'Today: ${live.done}/${live.scheduled} linked habits done',
              style: TextStyle(fontSize: 13, color: colors.textMuted),
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.brand,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: colors.textMuted)),
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
      return Text(
        'No habits linked. Tap Edit to link habits.',
        style: TextStyle(color: colors.textMuted, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Linked habits',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        ...openLinks.map(
          (link) => _LinkedHabitTile(link: link, goal: goal, colors: colors),
        ),
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
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.link, size: 18, color: colors.brand),
          title: Text(name, style: TextStyle(fontSize: 14, color: colors.text)),
          trailing: TextButton(
            onPressed: () async {
              final svc = ref.read(goalLifecycleServiceProvider);
              if (svc != null) await svc.unlinkHabit(goal, link.habitId);
            },
            child: Text(
              'Unlink',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
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
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => showGoalCreateSheet(context, existing: goal),
          icon: const Icon(AppIcons.edit, size: 16),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final confirm = await _confirm(
              context,
              'Complete early?',
              'This will archive the goal as completed early.',
            );
            if (!confirm) return;
            final svc = ref.read(goalLifecycleServiceProvider);
            if (svc != null) await svc.completeEarly(goal);
            if (context.mounted) context.pop();
          },
          icon: Icon(
            AppIcons.checkCircleOutline,
            size: 16,
            color: colors.success,
          ),
          label: const Text('Complete early'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final confirm = await _confirm(
              context,
              'Abandon goal?',
              'This will archive the goal as abandoned.',
            );
            if (!confirm) return;
            final svc = ref.read(goalLifecycleServiceProvider);
            if (svc != null) await svc.abandon(goal);
            if (context.mounted) context.pop();
          },
          icon: Icon(AppIcons.cancelOutlined, size: 16, color: colors.danger),
          label: const Text('Abandon'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.danger,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
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
      appBar: AppBar(title: const Text('Goal Summary')),
      body: FutureBuilder<GoalSummary?>(
        future: repo?.getSummary(goalId),
        builder: (_, snap) {
          final summary = snap.data;
          if (summary == null) {
            return const Center(child: CircularProgressIndicator.adaptive());
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${summary.elapsedDays} days',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: colors.brand,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'of ${summary.totalDays} total',
          style: TextStyle(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => showGoalCreateSheet(context),
          style: FilledButton.styleFrom(
            backgroundColor: colors.brand,
            foregroundColor: colors.onBrand,
          ),
          child: const Text('Set your next goal'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.textMuted)),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.text),
          ),
        ],
      ),
    );
  }
}
