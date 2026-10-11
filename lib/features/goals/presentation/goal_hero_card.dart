import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/application/goal_providers.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';
import 'package:streakin/features/goals/presentation/goal_create_sheet.dart';
import 'package:streakin/features/settings/application/settings_providers.dart'
    show reducedMotionProvider;

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
      loading: () => const _GoalCardShell(child: _LoadingContent()),
      error: (_, __) => const SizedBox.shrink(),
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
    return _GoalCardShell(
      child: Row(
        children: [
          Icon(Icons.track_changes_outlined, color: colors.brand, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set your primary goal',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text)),
                const SizedBox(height: 4),
                Text('One goal. One clock. Everything else supports it.',
                    style:
                        TextStyle(fontSize: 12, color: colors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              FilledButton(
                onPressed: () => showGoalCreateSheet(context),
                style: FilledButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: colors.onBrand,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8)),
                child: const Text('Set goal', style: TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: () async {
                  final repo = ref.read(goalRepositoryStateProvider);
                  if (repo == null) return;
                  await repo.setHeroPromptDismissed(
                      LocalDate.today().addDays(7));
                  ref.invalidate(heroPromptDismissedProvider);
                },
                child: Text('Later',
                    style:
                        TextStyle(fontSize: 12, color: colors.textMuted)),
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
    final reducedMotion = ref.watch(reducedMotionProvider);

    return GestureDetector(
      onTap: () => context.push('/goals/${clock.goal.id}'),
      onLongPress: () => _showQuickActions(context, ref),
      child: _GoalCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    clock.goal.title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (clock.isFinalStretch)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.warning.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Final week',
                        style: TextStyle(
                            fontSize: 11, color: colors.warning)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Main content row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ring + number
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _GoalRing(
                        progress: clock.progress ?? 0.0,
                        color: colors.brand,
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
                const SizedBox(width: 16),
                // Right side info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clock.caption,
                        style: TextStyle(
                            fontSize: 13, color: colors.textMuted),
                      ),
                      if (alignment?.alignmentPct != null) ...[
                        const SizedBox(height: 6),
                        _AlignmentChip(
                            pct: alignment!.alignmentPct!, colors: colors),
                      ],
                      if (live != null && live.scheduled > 0) ...[
                        const SizedBox(height: 6),
                        _LiveDots(
                            done: live.done,
                            total: live.scheduled,
                            colors: colors),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: colors.brand),
              title: const Text('Edit goal'),
              onTap: () {
                Navigator.of(context).pop();
                showGoalCreateSheet(context, existing: clock.goal);
              },
            ),
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: colors.success),
              title: const Text('Complete early'),
              onTap: () async {
                Navigator.of(context).pop();
                final svc =
                    ref.read(goalLifecycleServiceProvider);
                if (svc != null) await svc.completeEarly(clock.goal);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: colors.danger),
              title: const Text('Abandon'),
              onTap: () async {
                Navigator.of(context).pop();
                final svc =
                    ref.read(goalLifecycleServiceProvider);
                if (svc != null) await svc.abandon(clock.goal);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GoalRing extends StatelessWidget {
  const _GoalRing(
      {required this.progress,
      required this.color,
      required this.reducedMotion});
  final double progress;
  final Color color;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion) {
      return CustomPaint(
          painter: _RingPainter(progress: progress, color: color),
          size: const Size(72, 72));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, v, __) => CustomPaint(
          painter: _RingPainter(progress: v, color: color),
          size: const Size(72, 72)),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bg = Paint()
      ..color = color.withAlpha(30)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final fg = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    final sweep = progress.clamp(0.0, 1.0) * 2 * 3.14159265;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159265 / 2,
        sweep,
        false,
        fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _DayNumeral extends StatelessWidget {
  const _DayNumeral(
      {required this.clock,
      required this.colors,
      required this.reducedMotion});
  final GoalClockState clock;
  final AppColorTokens colors;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    if (clock.phase == GoalPhase.finalDay) {
      return Text('!',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.brand));
    }
    if (clock.phase == GoalPhase.ended) {
      return Icon(Icons.check, color: colors.brand, size: 28);
    }
    final label = clock.goal.kind == GoalKind.dated &&
            clock.daysLeft != null &&
            clock.phase == GoalPhase.active
        ? '${clock.daysLeft}'
        : '${clock.dayNumber}';
    return Text(label,
        style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.brand));
  }
}

class _AlignmentChip extends StatelessWidget {
  const _AlignmentChip({required this.pct, required this.colors});
  final int pct;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.brand.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('Aligned $pct%',
          style:
              TextStyle(fontSize: 11, color: colors.brand)),
    );
  }
}

class _LiveDots extends StatelessWidget {
  const _LiveDots(
      {required this.done, required this.total, required this.colors});
  final int done;
  final int total;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i < done;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? colors.brand : colors.outline,
          ),
        );
      }),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator.adaptive()));
  }
}

class _GoalCardShell extends StatelessWidget {
  const _GoalCardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: child,
    );
  }
}
