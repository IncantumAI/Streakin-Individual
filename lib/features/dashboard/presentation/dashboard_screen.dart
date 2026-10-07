// lib/features/dashboard/presentation/dashboard_screen.dart
// Spec §4.6: Today ring, streak card, consistency chart, weekly bars,
// heat strip, top-3 at risk, upcoming (stub), quick actions.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/habits/domain/streak_engine.dart';
import 'package:streakin/features/habits/presentation/habit_form.dart';
import 'package:streakin/features/notes/notes_module.dart'
    show recentNotesProvider, pinnedNotesProvider;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TodayRingCard(),
          SizedBox(height: 12),
          _StreakCard(),
          SizedBox(height: 12),
          _ConsistencyChartCard(),
          SizedBox(height: 12),
          _AtRiskHabitsCard(),
          SizedBox(height: 12),
          _RecentNotesCard(),
          SizedBox(height: 12),
          _PinnedNotesCard(),
          SizedBox(height: 12),
          _QuickActionsCard(),
          SizedBox(height: 24),
        ],
      ),
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
    final done = logsAsync.value?.values
            .where((l) => l != null && (l.isDone || l.isRest))
            .length ??
        0;
    final fraction = total == 0 ? 0.0 : done / total;

    return _DashCard(
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 80,
            height: 80,
            child: RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, _) => CustomPaint(
                  painter: _RingPainter(
                    fraction: value,
                    color: lockedIn.value == true
                        ? colors.success
                        : colors.brand,
                    background: colors.outline,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$done/$total',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.text)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lockedIn.value == true ? 'Day locked in! 🔒' : 'Today',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'No habits scheduled'
                      : done == total
                          ? 'All habits complete!'
                          : '${total - done} habit${total - done == 1 ? '' : 's'} remaining',
                  style: TextStyle(fontSize: 14, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.fraction,
      required this.color,
      required this.background});
  final double fraction;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.width / 2 - stroke / 2);
    final bgPaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.2832, false, bgPaint);
    if (fraction > 0) {
      canvas.drawArc(rect, -1.5708, 6.2832 * fraction, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ── Streak Card ───────────────────────────────────────────────────────────────

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final today = ref.watch(todayProvider);
    final habitsAsync = ref.watch(allHabitsProvider);
    final repo = ref.watch(habitRepositoryProvider);
    final engine = ref.watch(streakEngineProvider);

    return _DashCard(
      child: FutureBuilder(
        future: _computeStreak(habitsAsync.value ?? [], repo, engine, today),
        builder: (context, snap) {
          final streak = snap.data ?? 0;
          final nextMilestone =
              StreakEngine.milestones.firstWhere((m) => m > streak, orElse: () => 0);
          return Row(
            children: [
              const Icon(AppIcons.streakFill, color: AppColors.streakLight, size: 36),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$streak day streak',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.streakLight)),
                  if (nextMilestone > 0)
                    Text('Next milestone: $nextMilestone days',
                        style:
                            TextStyle(fontSize: 13, color: colors.textMuted)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<int> _computeStreak(List<Habit> habits, HabitRepository repo,
      StreakEngine engine, LocalDate today) async {
    if (habits.isEmpty) return 0;
    final ids = habits.where((h) => h.isActive).map((h) => h.id).toList();
    if (ids.isEmpty) return 0;
    final range = DateRange(start: today.subtractDays(365), end: today);
    final logMap = await repo.fetchLogsForHabits(ids, range);
    final dayLocks = <DayLock>[];
    for (int i = 0; i <= 365; i++) {
      final d = today.subtractDays(i);
      // Approximate: use lock-in check per day rather than stored DayLocks.
      final scheduled =
          habits.where((h) => h.isActive && h.scheduleMask.isScheduled(d));
      if (scheduled.isEmpty) continue;
      final allDone = scheduled.every((h) {
        final l = logMap[h.id]?.firstWhere((x) => x.localDate == d,
            orElse: () => HabitLog(
                id: '', habitId: h.id, localDate: d,
                status: HabitLogStatus.skipped, hlc: ''));
        return l?.isDone == true || l?.isRest == true;
      });
      if (allDone) dayLocks.add(DayLock(localDate: d, lockedAt: DateTime.now()));
    }
    return engine.lockInStreak(
        habits.where((h) => h.isActive).toList(), logMap, dayLocks, today);
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
  bool _animated = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(todayProvider);
    final habitsAsync = ref.watch(allHabitsProvider);

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Consistency',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text)),
              const Spacer(),
              _Chip(label: '7d', selected: _days == 7, onTap: () => setState(() => _days = 7)),
              const SizedBox(width: 6),
              _Chip(label: '30d', selected: _days == 30, onTap: () => setState(() => _days = 30)),
              const SizedBox(width: 6),
              _Chip(label: '90d', selected: _days == 90, onTap: () => setState(() => _days = 90)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: habitsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
              data: (habits) => FutureBuilder<List<FlSpot>>(
                future: _buildSpots(habits, today, _days, ref),
                builder: (_, snap) {
                  final spots = snap.data ?? [];
                  if (spots.isEmpty) return const SizedBox.shrink();
                  return RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: colors.brand,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: colors.brand.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                      duration: _animated
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
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

  Future<List<FlSpot>> _buildSpots(List<Habit> habits, LocalDate today,
      int days, WidgetRef ref) async {
    if (habits.isEmpty) return [];
    setState(() => _animated = true);
    final repo = ref.read(habitRepositoryProvider);
    final active = habits.where((h) => h.isActive).toList();
    final ids = active.map((h) => h.id).toList();
    final range =
        DateRange(start: today.subtractDays(days - 1), end: today);
    final logMap = await repo.fetchLogsForHabits(ids, range);
    final spots = <FlSpot>[];
    for (int i = 0; i < days; i++) {
      final d = today.subtractDays(days - 1 - i);
      final scheduled = active.where((h) => h.scheduleMask.isScheduled(d)).length;
      if (scheduled == 0) continue;
      final done = active.where((h) {
        final l = logMap[h.id];
        return l?.any((x) => x.localDate == d && (x.isDone || x.isRest)) == true;
      }).length;
      spots.add(FlSpot(i.toDouble(), (done / scheduled * 100)));
    }
    return spots;
  }
}

// ── At Risk Habits ────────────────────────────────────────────────────────────

class _AtRiskHabitsCard extends ConsumerWidget {
  const _AtRiskHabitsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final habitsAsync = ref.watch(habitsForTodayProvider);
    final logsAsync = ref.watch(todayLogsProvider);

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('At risk today',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text)),
          const SizedBox(height: 12),
          habitsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (habits) {
              final logs = logsAsync.value ?? {};
              final atRisk = habits
                  .where((h) =>
                      !(logs[h.id]?.isDone == true) &&
                      !(logs[h.id]?.isRest == true))
                  .take(3)
                  .toList();
              if (atRisk.isEmpty) {
                return Text('All caught up! ✓',
                    style: TextStyle(color: colors.success));
              }
              return Column(
                children: atRisk.map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(AppIcons.habitIcons[h.iconIndex % AppIcons.habitIcons.length],
                        size: 20,
                        color: AppColors.habitAccents[h.accentIndex % 8]),
                    const SizedBox(width: 10),
                    Expanded(child: Text(h.name, style: TextStyle(color: colors.text))),
                    const Icon(AppIcons.streakFill, size: 16, color: AppColors.streakLight),
                  ]),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Recent Notes ──────────────────────────────────────────────────────────────

class _RecentNotesCard extends ConsumerWidget {
  const _RecentNotesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final recentAsync = ref.watch(recentNotesProvider(5));

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recent Notes',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.text)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/notes'),
                child: Text('See all',
                    style: TextStyle(fontSize: 13, color: colors.brand)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          recentAsync.when(
            loading: () => const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, _) => Text('Could not load notes',
                style: TextStyle(fontSize: 13, color: colors.textMuted)),
            data: (notes) {
              if (notes.isEmpty) {
                return Text('No notes yet — tap Notes to create one.',
                    style: TextStyle(fontSize: 13, color: colors.textMuted));
              }
              return Column(
                children: notes
                    .map((n) => _NoteRow(
                          id: n.id,
                          title: n.title,
                          subtitle: _ago(n.updatedAt),
                        ))
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
    final colors = context.colors;
    final pinnedAsync = ref.watch(pinnedNotesProvider);

    return pinnedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (notes) {
        if (notes.isEmpty) return const SizedBox.shrink();
        return _DashCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pinned',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.text)),
              const SizedBox(height: 12),
              ...notes.map((n) => _NoteRow(id: n.id, title: n.title)),
            ],
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.article_outlined, size: 18, color: colors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.text),
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 12, color: colors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.outline),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActionsCard extends ConsumerWidget {
  const _QuickActionsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickAction(
                icon: AppIcons.add,
                label: 'Add habit',
                onTap: () => HabitForm.show(context),
              ),
              _QuickAction(
                icon: AppIcons.note,
                label: 'New note',
                onTap: () {}, // Phase 3
              ),
              _QuickAction(
                icon: AppIcons.todoCircle,
                label: 'Add task',
                onTap: () {}, // Phase 4
              ),
              _QuickAction(
                icon: AppIcons.zen,
                label: 'Zen',
                onTap: () {}, // Phase 7
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colors.brand),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: colors.text)),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  const _DashCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline),
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colors.brand : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? colors.onBrand : colors.textMuted)),
      ),
    );
  }
}
