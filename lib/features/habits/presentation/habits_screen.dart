// lib/features/habits/presentation/habits_screen.dart
// Tab container for Today / Week / Month views.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/features/habits/presentation/today_view.dart';
import 'package:streakin/features/habits/presentation/week_view.dart';
import 'package:streakin/features/habits/presentation/month_view.dart';
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
    _tab = TabController(length: 3, vsync: this);
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
        bottom: TabBar(
          controller: _tab,
          labelColor: colors.brand,
          unselectedLabelColor: colors.textMuted,
          indicatorColor: colors.brand,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Week'),
            Tab(text: 'Month'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.add),
            tooltip: 'Add habit',
            onPressed: () => HabitForm.show(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: const [TodayView(), WeekView(), MonthView()],
      ),
    );
  }
}
