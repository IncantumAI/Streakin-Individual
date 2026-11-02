// lib/features/habits/presentation/habits_screen.dart
// Tab container for Today / Week views (segmented pill tabs).

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:streakin/core/design/elevation.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/habits/presentation/today_view.dart';
import 'package:streakin/features/habits/presentation/week_view.dart';
import 'package:streakin/features/habits/presentation/habit_form.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});
  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.calendarActive),
            tooltip: 'Heatmaps',
            onPressed: () => context.push('/habits/heatmaps'),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(AppSpace.xs),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: AppRadius.brMd,
              ),
              child: TabBar(
                controller: _tab,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: colors.outline),
                  boxShadow: AppElevation.floating(colors),
                ),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Week'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [TodayView(), WeekView()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => HabitForm.show(context),
        tooltip: 'Add habit',
        icon: const Icon(AppIcons.add),
        label: const Text('New habit'),
      ),
    );
  }
}
