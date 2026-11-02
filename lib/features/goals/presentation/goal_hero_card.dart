import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class GoalHeroCard extends ConsumerWidget {
  const GoalHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final goalAsync = ref.watch(activeGoalProvider);
    final clockState = ref.watch(goalClockProvider);
    final dismissedAsync = ref.watch(heroPromptDismissedProvider);
    final isDismissed = dismissedAsync.value ?? false;

    return goalAsync.when(
      loading: () => const SkeletonCard(height: 132),
      error: (_, _) => const SizedBox.shrink(),
      data: (goal) {
        if (goal == null) {
          if (isDismissed) return const SizedBox.shrink();
          return _NoGoalCard(colors: colors);
        }
        if (clockState == null) return const SizedBox.shrink();
        return _ActiveGoalCard(clock: clockState, colors: colors);
      },
    );
  }
}

// ── No-goal empty state ───────────────────────────────────────────────────────

class _NoGoalCard extends ConsumerWidget {
  const _NoGoalCard({required this.colors});
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      variant: AppCardVariant.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.brand,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(
                  AppIcons.trackChangesOutlined,
                  color: colors.onBrand,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRIMARY GOAL',
                      style: AppTypography.overline.copyWith(
                        color: colors.brandText,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      'What are you working towards?',
                      style: context.text.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Set a primary goal to get a countdown, see how your daily habits contribute to it, and get milestone notifications.',
            style: context.text.bodySmall!.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showGoalCreateSheet(context),
                  icon: const Icon(AppIcons.add, size: AppSizes.iconMd),
                  label: const Text('Set my goal'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.textMuted),
                onPressed: () async {
                  final repo = ref.read(goalRepositoryStateProvider);
                  if (repo == null) return;
                  await repo.setHeroPromptDismissed(
                    LocalDate.today().addDays(7),
                  );
                  ref.invalidate(heroPromptDismissedProvider);
                },
                child: const Text('Later'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Active goal card ──────────────────────────────────────────────────────────

class _ActiveGoalCard extends ConsumerWidget {
  const _ActiveGoalCard({required this.clock, required this.colors});
  final GoalClockState clock;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alignAsync = ref.watch(goalAlignmentProvider);
    final liveAsync = ref.watch(goalTodayLiveProvider);
    final alignment = alignAsync.value;
    final live = liveAsync.value;
    final reducedMotion = isMotionReduced(context);

    // Combine closed-day alignment with today's live stats for the chip
    final int? displayPct = _combinedPct(alignment, live);

    return AppCard(
      onTap: () => context.push('/goals/${clock.goal.id}'),
      onLongPress: () => _showQuickActions(context, ref),
      onSecondaryTapDown: (_) => _showQuickActions(context, ref),
      semanticLabel: 'Primary goal: ${clock.goal.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(
                AppIcons.trackChangesOutlined,
                size: AppSizes.iconSm,
                color: colors.brandText,
              ),
              const SizedBox(width: AppSpace.xs + 2),
              Expanded(
                child: Text(
                  clock.goal.title,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (clock.isFinalStretch)
                const StatusPill('Final week', tone: PillTone.warning),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          // Main content row
          Row(
            children: [
              // Ring + number
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _GoalRing(
                      progress: clock.progress ?? 0.0,
                      color: colors.brand,
                      track: colors.surfaceAlt,
                      reducedMotion: reducedMotion,
                    ),
                    _DayNumeral(
                      clock: clock,
                      colors: colors,
                      reducedMotion: reducedMotion,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              // Right side info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clock.caption,
                      style: context.text.bodyMedium!.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (displayPct != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      _AlignmentChip(pct: displayPct, colors: colors),
                    ],
                    if (live != null && live.scheduled > 0) ...[
                      const SizedBox(height: AppSpace.sm),
                      _LiveDots(
                        done: live.done,
                        total: live.scheduled,
                        colors: colors,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, color: colors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  int? _combinedPct(AlignmentStats? closed, ({int done, int scheduled})? live) {
    final closedSched = closed?.scheduled ?? 0;
    final closedDone = closed?.done ?? 0;
    final liveSched = live?.scheduled ?? 0;
    final liveDone = live?.done ?? 0;
    final totalSched = closedSched + liveSched;
    final totalDone = closedDone + liveDone;
    if (totalSched == 0) return null;
    return (100 * totalDone / totalSched).round();
  }

  void _showQuickActions(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    showAppBottomSheet<void>(
      context,
      title: clock.goal.title,
      isScrollControlled: false,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(AppIcons.edit, color: colors.brandText),
              title: const Text('Edit goal'),
              onTap: () {
                Navigator.of(context).pop();
                showGoalCreateSheet(context, existing: clock.goal);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.checkCircleOutline, color: colors.success),
              title: const Text('Complete early'),
              onTap: () async {
                Navigator.of(context).pop();
                final svc = ref.read(goalLifecycleServiceProvider);
                if (svc != null) {
                  await svc.completeEarly(clock.goal);
                  if (context.mounted) {
                    context.celebrate(CelebrationKind.goalDone);
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(AppIcons.cancelOutlined, color: colors.danger),
              title: Text('Abandon', style: TextStyle(color: colors.danger)),
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await showConfirmDialog(
                  context,
                  title: 'Abandon this goal?',
                  message:
                      'It moves to your goal history. Habits stay as they are.',
                  confirmLabel: 'Abandon',
                  destructive: true,
                );
                if (!ok) return;
                final svc = ref.read(goalLifecycleServiceProvider);
                if (svc != null) await svc.abandon(clock.goal);
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.progress,
    required this.color,
    required this.track,
    required this.reducedMotion,
  });
  final double progress;
  final Color color;
  final Color track;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return ProgressRing(
      value: progress,
      size: 80,
      stroke: 7,
      color: color,
      trackColor: track,
      duration: reducedMotion ? Duration.zero : AppDurations.progressRing,
    );
  }
}

class _DayNumeral extends StatelessWidget {
  const _DayNumeral({
    required this.clock,
    required this.colors,
    required this.reducedMotion,
  });
  final GoalClockState clock;
  final AppColorTokens colors;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    if (clock.phase == GoalPhase.finalDay) {
      return Text(
        '!',
        style: AppTypography.numeric.copyWith(
          fontSize: 26,
          color: colors.brandText,
        ),
      );
    }
    if (clock.phase == GoalPhase.ended) {
      return Icon(AppIcons.check, color: colors.brandText, size: 28);
    }
    final countdown =
        clock.goal.kind == GoalKind.dated &&
        clock.daysLeft != null &&
        clock.phase == GoalPhase.active;
    final value = countdown ? clock.daysLeft! : clock.dayNumber;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedCounter(
          value: value,
          duration: reducedMotion ? Duration.zero : AppDurations.streakCounter,
          style: AppTypography.numeric.copyWith(
            fontSize: 22,
            color: colors.text,
          ),
        ),
        Text(
          countdown ? 'days left' : 'day',
          style: context.text.labelMedium!.copyWith(
            fontSize: 10,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _AlignmentChip extends StatelessWidget {
  const _AlignmentChip({required this.pct, required this.colors});
  final int pct;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      'Aligned $pct%',
      tone: PillTone.brand,
      icon: AppIcons.trackChangesOutlined,
    );
  }
}

class _LiveDots extends StatelessWidget {
  const _LiveDots({
    required this.done,
    required this.total,
    required this.colors,
  });
  final int done;
  final int total;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$done of $total habits done today',
      child: Wrap(
        spacing: AppSpace.xs,
        runSpacing: AppSpace.xs,
        children: List.generate(total, (i) {
          final filled = i < done;
          return AnimatedContainer(
            duration: resolvedDuration(context, AppDurations.base),
            curve: AppCurves.emphasized,
            width: filled ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: AppRadius.brPill,
              color: filled ? colors.brand : colors.outline,
            ),
          );
        }),
      ),
    );
  }
}
