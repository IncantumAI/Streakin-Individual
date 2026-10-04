// lib/features/calendar/presentation/calendar_screen.dart
// Spec §4.5: Month/Week/Day/Agenda views with layer toggles (Habits on by default).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showHabits = true;
  bool _showTodos = false;   // Phase 4
  bool _showNotes = false;   // Phase 3

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    _selectedDay ??= _focusedDay;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          // Layer toggles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _LayerChip(
                  label: 'Habits',
                  color: colors.brand,
                  selected: _showHabits,
                  onTap: () => setState(() => _showHabits = !_showHabits),
                ),
                const SizedBox(width: 8),
                _LayerChip(
                  label: 'Tasks',
                  color: colors.warning,
                  selected: _showTodos,
                  onTap: () => setState(() => _showTodos = !_showTodos),
                ),
                const SizedBox(width: 8),
                _LayerChip(
                  label: 'Notes',
                  color: colors.success,
                  selected: _showNotes,
                  onTap: () => setState(() => _showNotes = !_showNotes),
                ),
              ],
            ),
          ),
          // Calendar
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _showDaySheet(context, LocalDate.fromDateTime(selected));
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: colors.brand, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.3), shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: _showHabits ? _buildHabitMarker : null,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Tap a day to see habits & events',
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildHabitMarker(BuildContext context, DateTime day, List<Object?> events) {
    return const SizedBox.shrink();
  }

  void _showDaySheet(BuildContext context, LocalDate date) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _DaySheet(date: date),
    );
  }
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.date});
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.watch(habitRepositoryProvider);

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: FutureBuilder<List<Habit>>(
          future: ref.read(habitRepositoryProvider).watchActiveForDate(date).first,
          builder: (context, snap) {
            final habits = snap.data ?? [];
            return ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: colors.text),
                  ),
                ),
                const SizedBox(height: 16),
                if (habits.isEmpty)
                  Text('No habits scheduled',
                      style: TextStyle(color: colors.textMuted))
                else
                  ...habits.map((h) => FutureBuilder<HabitLog?>(
                        future: repo.getLog(h.id, date),
                        builder: (_, logSnap) {
                          final log = logSnap.data;
                          final isDone = log?.isDone == true;
                          return ListTile(
                            leading: Icon(
                              AppIcons.habitIcons[h.iconIndex % AppIcons.habitIcons.length],
                              color: AppColors.habitAccents[h.accentIndex % 8],
                            ),
                            title: Text(h.name),
                            trailing: isDone
                                ? Icon(AppIcons.check, color: colors.success)
                                : Icon(AppIcons.todoCircle, color: colors.outline),
                          );
                        },
                      )),
                const SizedBox(height: 16),
                Text('Tasks & note events — Phase 4',
                    style: TextStyle(fontSize: 12, color: colors.textMuted)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? color : color.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}
