// lib/features/dashboard/presentation/dashboard_screen.dart
// Spec §4.6: Today ring, streak card, consistency chart, weekly bars,
// heat strip, top-3 at risk, upcoming, quick actions.
//
// Layout (spec §5.6): hero (goal, today ring + streak) → quick actions →
// "Needs attention" → "Insights" → "Notes". Two columns at ≥ 900 px.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/habits/domain/streak_engine.dart';
import 'package:streakin/features/habits/presentation/habit_form.dart';
import 'package:streakin/features/habits/presentation/habit_heatmap.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/notes_module.dart'
    show
        recentNotesProvider,
        pinnedNotesProvider,
        notesDateMentionsByDateProvider,
        showNewNoteFlow;
import 'package:streakin/features/todos/application/todo_providers.dart';
import 'package:streakin/features/todos/presentation/todos_screen.dart'
    show showAddTaskSheet;
import 'package:streakin/features/goals/goals_module.dart' show GoalHeroCard;
import 'package:streakin/shared/widgets/widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(now), style: context.text.titleLarge),
            Text(
              DateFormat('EEEE, d MMMM').format(now),
              style: context.text.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final gutter = AppSpace.pagePadding(w);
          final twoCol = w >= 900;

          const hero = <Widget>[
            GoalHeroCard(),
            SizedBox(height: AppSpace.md),
            _TodayAndStreakRow(),
          ];
          const attention = <Widget>[
            SectionHeader('Needs attention'),
            _AtRiskHabitsCard(),
            SizedBox(height: AppSpace.md),
            _UpcomingCard(),
          ];
          const insights = <Widget>[
            SectionHeader('Insights'),
            _ConsistencyChartCard(),
            SizedBox(height: AppSpace.md),
            _HeatmapCard(),
          ];
          const notes = <Widget>[
            SectionHeader('Notes'),
            _RecentNotesCard(),
            _PinnedNotesCard(),
          ];

          List<Widget> staggered(List<Widget> items, int offset) => [
            for (var i = 0; i < items.length; i++)
              StaggeredEntrance(index: offset + i, child: items[i]),
          ];

          if (!twoCol) {
            return ListView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                AppSpace.sm,
                gutter,
                AppSpace.xxxl,
              ),
              children: staggered([
                ...hero,
                const SizedBox(height: AppSpace.lg),
                const _QuickActionsRow(),
                ...attention,
                ...insights,
                ...notes,
              ], 0),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpace.sm,
              gutter,
              AppSpace.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...staggered(hero, 0),
                    const SizedBox(height: AppSpace.lg),
                    const StaggeredEntrance(
                      index: 3,
                      child: _QuickActionsRow(),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: staggered([...attention, ...notes], 4),
                          ),
                        ),
                        const SizedBox(width: AppSpace.xl),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: staggered(insights, 5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Today ring and streak side by side (stacked on narrow / large text).
class _TodayAndStreakRow extends StatelessWidget {
  const _TodayAndStreakRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = constraints.maxWidth < 520 || scale > 1.3;
        if (stacked) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TodayRingCard(),
              SizedBox(height: AppSpace.md),
              _StreakCard(),
            ],
          );
        }
        return const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _TodayRingCard()),
              SizedBox(width: AppSpace.md),
              Expanded(child: _StreakCard()),
            ],
          ),
        );
      },
    );
  }
}

/// Card heading with optional trailing action.
class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.icon, this.action, this.trailing});
  final String title;
  final IconData? icon;
  final (String, VoidCallback)? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppSizes.iconMd, color: colors.textMuted),
          const SizedBox(width: AppSpace.sm),
        ],
        Expanded(child: Text(title, style: context.text.titleMedium)),
        ?trailing,
        if (action != null)
          TextButton(
            onPressed: action!.$2,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            ),
            child: Text(action!.$1),
          ),
      ],
    );
  }
}

// ── Today Ring ────────────────────────────────────────────────────────────────

class _TodayRingCard extends ConsumerWidget {
  const _TodayRingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final habitsAsync = ref.watch(habitsForTodayProvider);
    final logsAsync = ref.watch(todayLogsProvider);
    final lockedIn = ref.watch(lockedInTodayProvider);

    final total = habitsAsync.value?.length ?? 0;
    final done =
        logsAsync.value?.values
            .where((l) => l != null && (l.isDone || l.isRest))
            .length ??
        0;
    final fraction = total == 0 ? 0.0 : done / total;

    final locked = lockedIn.value == true;
    final remaining = total - done;

    return AppCard(
      onTap: () => context.go('/habits'),
      semanticLabel: 'Today: $done of $total habits done',
      variant: locked ? AppCardVariant.brand : AppCardVariant.outlined,
      child: Row(
        children: [
          RepaintBoundary(
            child: ProgressRing(
              value: fraction,
              size: 76,
              stroke: 8,
              color: locked ? colors.success : colors.brand,
              center: Text(
                '$done/$total',
                style: AppTypography.numeric.copyWith(
                  fontSize: 18,
                  color: colors.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  locked ? 'Day locked in' : 'Today',
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  total == 0
                      ? 'No habits scheduled'
                      : done == total
                      ? 'All habits complete'
                      : '$remaining habit${remaining == 1 ? '' : 's'} remaining',
                  style: context.text.bodySmall,
                ),
                if (locked) ...[
                  const SizedBox(height: AppSpace.sm),
                  const StatusPill(
                    'Locked in',
                    tone: PillTone.success,
                    icon: AppIcons.lockFill,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streak Card ───────────────────────────────────────────────────────────────

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final today = ref.watch(todayProvider);
    final habitsAsync = ref.watch(allHabitsProvider);
    final repo = ref.watch(habitRepositoryStateProvider);
    final engine = ref.watch(streakEngineProvider);
    if (repo == null) return const SkeletonCard(height: 108);

    return AppCard(
      child: FutureBuilder(
        future: _computeStreak(habitsAsync.value ?? [], repo, engine, today),
        builder: (context, snap) {
          final streak = snap.data ?? 0;
          final nextMilestone = StreakEngine.milestones.firstWhere(
            (m) => m > streak,
            orElse: () => 0,
          );
          final prevMilestone = StreakEngine.milestones.lastWhere(
            (m) => m <= streak,
            orElse: () => 0,
          );
          final toNext = nextMilestone == 0
              ? 1.0
              : (streak - prevMilestone) / (nextMilestone - prevMilestone);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.streak.withValues(alpha: 0.14),
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Icon(
                      AppIcons.streakFill,
                      color: colors.streak,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            AnimatedCounter(
                              value: streak,
                              semanticsLabel: '$streak day streak',
                              style: AppTypography.numeric.copyWith(
                                fontSize: 28,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(width: AppSpace.xs),
                            Text('day streak', style: context.text.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (nextMilestone > 0) ...[
                const SizedBox(height: AppSpace.md),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: toNext.clamp(0.0, 1.0)),
                  duration: resolvedDuration(
                    context,
                    AppDurations.progressRing,
                  ),
                  curve: AppCurves.emphasized,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: colors.streak,
                    backgroundColor: colors.surfaceAlt,
                  ),
                ),
                const SizedBox(height: AppSpace.xs + 2),
                Text(
                  '${nextMilestone - streak} days to the $nextMilestone-day milestone',
                  style: context.text.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<int> _computeStreak(
    List<Habit> habits,
    HabitRepository repo,
    StreakEngine engine,
    LocalDate today,
  ) async {
    if (habits.isEmpty) return 0;
    final ids = habits.where((h) => h.isActive).map((h) => h.id).toList();
    if (ids.isEmpty) return 0;
    final range = DateRange(start: today.subtractDays(365), end: today);
    final logMap = await repo.fetchLogsForHabits(ids, range);
    final dayLocks = <DayLock>[];
    for (int i = 0; i <= 365; i++) {
      final d = today.subtractDays(i);
      // Approximate: use lock-in check per day rather than stored DayLocks.
      final scheduled = habits.where(
        (h) => h.isActive && h.scheduleMask.isScheduled(d),
      );
      if (scheduled.isEmpty) continue;
      final allDone = scheduled.every((h) {
        final l = logMap[h.id]?.firstWhere(
          (x) => x.localDate == d,
          orElse: () => HabitLog(
            id: '',
            habitId: h.id,
            localDate: d,
            status: HabitLogStatus.skipped,
            hlc: '',
          ),
        );
        return l?.isDone == true || l?.isRest == true;
      });
      if (allDone) {
        dayLocks.add(DayLock(localDate: d, lockedAt: DateTime.now()));
      }
    }
    return engine.lockInStreak(
      habits.where((h) => h.isActive).toList(),
      logMap,
      dayLocks,
      today,
    );
  }
}

// ── Consistency Chart ─────────────────────────────────────────────────────────

class _ConsistencyChartCard extends ConsumerStatefulWidget {
  const _ConsistencyChartCard();
  @override
  ConsumerState<_ConsistencyChartCard> createState() =>
      _ConsistencyChartCardState();
}

class _ConsistencyChartCardState extends ConsumerState<_ConsistencyChartCard> {
  int _days = 30;

  // Spots are cached per (habits, day, range) so rebuilds don't refetch or
  // restart the chart animation.
  Future<List<FlSpot>>? _spots;
  Object? _spotsKey;

  Future<List<FlSpot>> _spotsFor(List<Habit> habits, LocalDate today) {
    final key = (habits, today, _days);
    if (_spots == null || _spotsKey != key) {
      _spotsKey = key;
      _spots = _buildSpots(habits, today, _days, ref);
    }
    return _spots!;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(todayProvider);
    final habitsAsync = ref.watch(allHabitsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            'Consistency',
            trailing: SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                minimumSize: WidgetStatePropertyAll(Size(0, 32)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_days},
              onSelectionChanged: (v) => setState(() => _days = v.first),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            height: 140,
            child: habitsAsync.when(
              loading: () => const SkeletonCard(height: 140),
              error: (e, st) => ErrorState.inline(error: e, stackTrace: st),
              data: (habits) => FutureBuilder<List<FlSpot>>(
                future: _spotsFor(habits, today),
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SkeletonCard(height: 140);
                  }
                  final spots = snap.data ?? [];
                  if (spots.isEmpty) {
                    return Center(
                      child: Text(
                        'Check in for a few days to see your trend.',
                        style: context.text.bodySmall,
                      ),
                    );
                  }
                  return RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: colors.outline,
                            strokeWidth: 1,
                            dashArray: const [4, 4],
                          ),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => colors.inverseSurface,
                            tooltipBorderRadius: AppRadius.brSm,
                            getTooltipItems: (spots) => [
                              for (final s in spots)
                                LineTooltipItem(
                                  '${s.y.round()}%',
                                  context.text.labelMedium!.copyWith(
                                    color: colors.onInverse,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            barWidth: 2.5,
                            color: colors.brand,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colors.brand.withValues(alpha: 0.22),
                                  colors.brand.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: resolvedDuration(
                        context,
                        AppDurations.chartDrawIn,
                      ),
                      curve: AppCurves.emphasized,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<FlSpot>> _buildSpots(
    List<Habit> habits,
    LocalDate today,
    int days,
    WidgetRef ref,
  ) async {
    if (habits.isEmpty) return [];
    final repo = ref.read(habitRepositoryStateProvider);
    if (repo == null) return [];
    final active = habits.where((h) => h.isActive).toList();
    final ids = active.map((h) => h.id).toList();
    final range = DateRange(start: today.subtractDays(days - 1), end: today);
    final logMap = await repo.fetchLogsForHabits(ids, range);
    final spots = <FlSpot>[];
    for (int i = 0; i < days; i++) {
      final d = today.subtractDays(days - 1 - i);
      final scheduled = active
          .where((h) => h.scheduleMask.isScheduled(d))
          .length;
      if (scheduled == 0) continue;
      final done = active.where((h) {
        final l = logMap[h.id];
        return l?.any((x) => x.localDate == d && (x.isDone || x.isRest)) ==
            true;
      }).length;
      spots.add(FlSpot(i.toDouble(), (done / scheduled * 100)));
    }
    return spots;
  }
}

// ── At Risk Habits ────────────────────────────────────────────────────────────

class _HeatmapCard extends ConsumerWidget {
  const _HeatmapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final habits = (ref.watch(allHabitsProvider).value ?? const <Habit>[])
        .where((h) => h.isActive)
        .toList();
    final data = ref.watch(
      habitHeatmapProvider([for (final h in habits) h.id]),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            'Activity',
            action: ('See all', () => context.push('/habits/heatmaps')),
          ),
          const SizedBox(height: AppSpace.md),
          data.when(
            loading: () => const SkeletonCard(),
            error: (e, st) => ErrorState.inline(error: e, stackTrace: st),
            data: (values) => HeatmapGrid(
              values: values,
              today: ref.watch(todayProvider),
              color: colors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _AtRiskHabitsCard extends ConsumerWidget {
  const _AtRiskHabitsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final habitsAsync = ref.watch(habitsForTodayProvider);
    final logsAsync = ref.watch(todayLogsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            'At risk today',
            action: ('Check in', () => context.go('/habits')),
          ),
          const SizedBox(height: AppSpace.sm),
          habitsAsync.when(
            loading: () => const Shimmer(
              child: Column(
                children: [
                  Skeleton.line(height: 14),
                  SizedBox(height: AppSpace.md),
                  Skeleton.line(height: 14),
                ],
              ),
            ),
            error: (e, st) => ErrorState.inline(error: e, stackTrace: st),
            data: (habits) {
              final logs = logsAsync.value ?? {};
              final atRisk = habits
                  .where(
                    (h) =>
                        !(logs[h.id]?.isDone == true) &&
                        !(logs[h.id]?.isRest == true),
                  )
                  .take(3)
                  .toList();
              if (atRisk.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.checkCircleOutlined,
                        size: AppSizes.iconMd,
                        color: colors.success,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        'All caught up',
                        style: context.text.bodyMedium!.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: atRisk.map((h) {
                  final accent = AppColors.habitAccents[h.accentIndex % 8];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brSm,
                          ),
                          child: Icon(
                            AppIcons.habitIcons[h.iconIndex %
                                AppIcons.habitIcons.length],
                            size: 18,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text(
                            h.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium!.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(
                          AppIcons.streakFill,
                          size: AppSizes.iconSm,
                          color: colors.streak,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Upcoming ──────────────────────────────────────────────────────────────────

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final today = LocalDate.today();
    final range = DateRange(start: today, end: today.addDays(7));

    final todosAsync = ref.watch(todosUpcomingProvider);
    final noteMentionsAsync = ref.watch(notesDateMentionsByDateProvider(range));

    final todos = todosAsync.value ?? [];
    final noteMentions = noteMentionsAsync.value ?? {};

    final items = <_UpcomingItem>[];
    for (final t in todos.where((x) => x.dueDate != null).take(5)) {
      items.add(
        _UpcomingItem(
          label: t.title,
          isoDate: t.dueDate!,
          icon: AppIcons.habits,
          color: colors.warning,
          onTap: () => context.go('/tasks'),
        ),
      );
    }
    for (final entry in noteMentions.entries) {
      for (final nid in entry.value.take(2)) {
        items.add(
          _UpcomingItem(
            label: nid,
            isoDate: entry.key,
            icon: AppIcons.articleOutlined,
            color: colors.success,
            isNoteId: true,
            onTap: () => context.push('/notes/$nid'),
          ),
        );
      }
    }

    items.sort((a, b) => a.isoDate.compareTo(b.isoDate));
    final top = items.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Upcoming'),
          const SizedBox(height: AppSpace.xs),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Text(
                'Nothing in the next 7 days',
                style: context.text.bodySmall,
              ),
            )
          else
            ...top.map((item) => _UpcomingTile(item: item)),
        ],
      ),
    );
  }
}

class _UpcomingItem {
  const _UpcomingItem({
    required this.label,
    required this.isoDate,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isNoteId = false,
  });
  final String label;
  final String isoDate;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isNoteId;
}

class _UpcomingTile extends ConsumerWidget {
  const _UpcomingTile({required this.item});
  final _UpcomingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = LocalDate.today();
    final itemDate = LocalDate.parse(item.isoDate);
    final diff = DateTime(
      itemDate.year,
      itemDate.month,
      itemDate.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final dateLabel = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Tomorrow'
        : DateFormat('EEE d MMM')
              .format(DateTime(itemDate.year, itemDate.month, itemDate.day));

    return InkWell(
      onTap: item.onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.14),
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: item.isNoteId
                  ? _NoteTitle(noteId: item.label)
                  : Text(
                      item.label,
                      style: context.text.bodyMedium!.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const SizedBox(width: AppSpace.sm),
            StatusPill(
              dateLabel,
              tone: diff == 0 ? PillTone.brand : PillTone.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTitle extends ConsumerWidget {
  const _NoteTitle({required this.noteId});
  final String noteId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(noteRepositoryStateProvider);
    if (repo == null) {
      return Text('Note', style: context.text.bodyMedium);
    }
    return FutureBuilder<Note?>(
      future: repo.getById(noteId),
      builder: (_, snap) {
        final title = snap.data?.title;
        return Text(
          (title == null || title.isEmpty) ? 'Untitled' : title,
          style: context.text.bodyMedium!.copyWith(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

// ── Recent Notes ──────────────────────────────────────────────────────────────

class _RecentNotesCard extends ConsumerWidget {
  const _RecentNotesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentNotesProvider(5));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Recent', action: ('See all', () => context.go('/notes'))),
          const SizedBox(height: AppSpace.xs),
          recentAsync.when(
            loading: () => const Shimmer(
              child: Column(
                children: [
                  Skeleton.line(height: 14),
                  SizedBox(height: AppSpace.md),
                  Skeleton.line(height: 14),
                  SizedBox(height: AppSpace.md),
                  Skeleton.line(height: 14),
                ],
              ),
            ),
            error: (e, st) => ErrorState.inline(
              error: e,
              stackTrace: st,
              title: 'Couldn’t load notes',
              onRetry: () => ref.invalidate(recentNotesProvider(5)),
            ),
            data: (notes) {
              if (notes.isEmpty) {
                return EmptyState(
                  compact: true,
                  icon: AppIcons.emptyNotes,
                  title: 'No notes yet',
                  message: 'Capture a thought or start a page.',
                  action: OutlinedButton.icon(
                    onPressed: () => showNewNoteFlow(context, ref),
                    icon: const Icon(AppIcons.add, size: AppSizes.iconMd),
                    label: const Text('New note'),
                  ),
                );
              }
              return Column(
                children: notes
                    .map(
                      (n) => _NoteRow(
                        id: n.id,
                        title: n.title,
                        subtitle: _ago(n.updatedAt),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Pinned Notes ──────────────────────────────────────────────────────────────

class _PinnedNotesCard extends ConsumerWidget {
  const _PinnedNotesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedNotesProvider);

    return pinnedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (notes) {
        if (notes.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle('Pinned', icon: AppIcons.pinFill),
                const SizedBox(height: AppSpace.xs),
                ...notes.map((n) => _NoteRow(id: n.id, title: n.title)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Note row helper ───────────────────────────────────────────────────────────

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.id, required this.title, this.subtitle});
  final String id;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => context.push('/notes/$id'),
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(
                AppIcons.articleOutlined,
                size: 18,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: AppSizes.iconMd,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: AppIcons.check,
        label: 'Check-in',
        primary: true,
        onTap: () => context.go('/habits'),
      ),
      _QuickAction(
        icon: AppIcons.edit,
        label: 'Quick capture',
        onTap: () => _quickCapture(context, ref),
      ),
      _QuickAction(
        icon: AppIcons.note,
        label: 'New note',
        onTap: () => showNewNoteFlow(context, ref),
      ),
      _QuickAction(
        icon: AppIcons.todoCircle,
        label: 'Add task',
        onTap: () => _showAddTaskSheet(context),
      ),
      _QuickAction(
        icon: AppIcons.add,
        label: 'Add habit',
        onTap: () => HabitForm.show(context),
      ),
      _QuickAction(
        icon: AppIcons.zen,
        label: 'Zen',
        onTap: () => context.push('/zen'),
      ),
    ];
    return SizedBox(
      height: AppSizes.minTap,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (_, i) => actions[i],
      ),
    );
  }

  /// Minimal single-field sheet → creates a note in the Inbox (no folder).
  Future<void> _quickCapture(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final text = await showAppBottomSheet<String>(
      context,
      title: 'Quick capture',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Capture a thought…'),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                child: const Text('Save to Inbox'),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    final title = text?.trim() ?? '';
    if (title.isEmpty) return;
    final repo = ref.read(noteRepositoryStateProvider);
    if (repo == null) return;
    final now = DateTime.now();
    await repo.saveNote(
      Note(
        id: const Uuid().v4(),
        title: title,
        body: '[]',
        createdAt: now,
        updatedAt: now,
        hlc: Hlc.now().toIso(),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to Inbox')));
    }
  }

  void _showAddTaskSheet(BuildContext context) {
    showAddTaskSheet(context);
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = primary ? colors.onBrand : colors.text;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        child: Material(
          color: primary ? colors.brand : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.brPill,
            side: primary ? BorderSide.none : BorderSide(color: colors.outline),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: primary ? colors.onBrand : colors.brandText,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    label,
                    style: context.text.labelLarge!.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dashboard add-task sheet removed — now uses showAddTaskSheet() from todos_screen.dart
