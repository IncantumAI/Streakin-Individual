import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/notes_module.dart'
    show notesDateMentionsByDateProvider, noteRepositoryStateProvider;
import 'package:streakin/features/todos/application/todo_providers.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/features/todos/presentation/todos_screen.dart'
    show showAddTaskSheet;
import 'package:uuid/uuid.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showHabits = true;
  bool _showTodos = true;
  bool _showNotes = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateRange get _monthRange {
    final d = _focusedDay;
    final start = LocalDate(d.year, d.month, 1);
    final end = LocalDate(
      d.year,
      d.month,
      DateTime(d.year, d.month + 1, 0).day,
    );
    return DateRange(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    _selectedDay ??= _focusedDay;

    final noteMentions = _showNotes
        ? (ref.watch(notesDateMentionsByDateProvider(_monthRange)).value ?? {})
        : <String, List<String>>{};

    final todoEntries = _showTodos
        ? (ref.watch(todoCalendarEntriesForMonth(_monthRange)).value ?? [])
        : <_TodoMarker>[];

    final todoDates = <String>{for (final t in todoEntries) t.isoDate};

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Calendar'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.brand,
          unselectedLabelColor: colors.textMuted,
          indicatorColor: colors.brand,
          tabs: const [
            Tab(text: 'Month'),
            Tab(text: 'Agenda'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MonthView(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay!,
                  noteMentions: noteMentions,
                  todoDates: todoDates,
                  showHabits: _showHabits,
                  showNotes: _showNotes,
                  showTodos: _showTodos,
                  colors: colors,
                  onDaySelected: (sel, foc) {
                    setState(() {
                      _selectedDay = sel;
                      _focusedDay = foc;
                    });
                    _showDaySheet(context, LocalDate.fromDateTime(sel));
                  },
                  onPageChanged: (d) => setState(() => _focusedDay = d),
                ),
                _AgendaView(
                  range: DateRange(
                    start: LocalDate.today(),
                    end: LocalDate.today().addDays(30),
                  ),
                  showHabits: _showHabits,
                  showTodos: _showTodos,
                  showNotes: _showNotes,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
        tooltip: 'Create',
        onPressed: () => _showCreateMenu(context),
        child: const Icon(AppIcons.add),
      ),
    );
  }

  void _showCreateMenu(BuildContext context) {
    final colors = context.colors;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(AppIcons.habits, color: colors.brand),
              title: const Text('Add task'),
              subtitle: Text(
                _selectedDay != null
                    ? 'Due ${LocalDate.fromDateTime(_selectedDay!).toIso()}'
                    : 'No due date',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              onTap: () {
                Navigator.of(context).pop();
                showAddTaskSheet(
                  context,
                  initialDueDate: _selectedDay == null
                      ? null
                      : LocalDate.fromDateTime(_selectedDay!),
                );
              },
            ),
            ListTile(
              leading: Icon(AppIcons.articleOutlined, color: colors.success),
              title: const Text('New note'),
              onTap: () async {
                Navigator.of(context).pop();
                await _createNote(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNote(BuildContext context) async {
    final repo = ref.read(noteRepositoryStateProvider);
    if (repo == null) return;
    final id = const Uuid().v4();
    final now = DateTime.now();
    await repo.saveNote(
      Note(
        id: id,
        title: '',
        // Pre-filled with an @date chip for the tapped day (FR-CAL-4).
        body: NoteDocument([
          NoteBlock(
            id: const Uuid().v4(),
            kind: NoteBlockKind.paragraph,
            text: _selectedDay == null
                ? ''
                : '@${LocalDate.fromDateTime(_selectedDay!).toIso()} ',
          ),
        ]).toJson(),
        createdAt: now,
        updatedAt: now,
        hlc: Hlc.now().toIso(),
      ),
    );
    if (context.mounted) await context.push('/notes/$id');
  }

  void _showDaySheet(BuildContext context, LocalDate date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DaySheet(
        date: date,
        showHabits: _showHabits,
        showTodos: _showTodos,
        showNotes: _showNotes,
      ),
    );
  }
}

// ── Month view ────────────────────────────────────────────────────────────────

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.focusedDay,
    required this.selectedDay,
    required this.noteMentions,
    required this.todoDates,
    required this.showHabits,
    required this.showNotes,
    required this.showTodos,
    required this.colors,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<String, List<String>> noteMentions;
  final Set<String> todoDates;
  final bool showHabits, showNotes, showTodos;
  final AppColorTokens colors;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: focusedDay,
      selectedDayPredicate: (d) => isSameDay(d, selectedDay),
      headerStyle: const HeaderStyle(formatButtonVisible: false),
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: colors.brand,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: colors.brand.withAlpha(60),
          shape: BoxShape.circle,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (ctx, day, _) {
          final iso = LocalDate.fromDateTime(day).toIso();
          final dots = <Widget>[];
          if (showNotes && noteMentions.containsKey(iso)) {
            dots.add(_dot(colors.success));
          }
          if (showTodos && todoDates.contains(iso)) {
            dots.add(_dot(colors.warning));
          }
          if (dots.isEmpty) return null;
          return Positioned(
            bottom: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: dots),
          );
        },
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── Agenda view ───────────────────────────────────────────────────────────────

class _AgendaView extends ConsumerWidget {
  const _AgendaView({
    required this.range,
    required this.showHabits,
    required this.showTodos,
    required this.showNotes,
  });

  final DateRange range;
  final bool showHabits, showTodos, showNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final todoAsync = showTodos
        ? ref.watch(todoCalendarEntriesForMonth(range))
        : const AsyncData(<_TodoMarker>[]);
    final noteMap = showNotes
        ? (ref.watch(notesDateMentionsByDateProvider(range)).value ?? {})
        : <String, List<String>>{};

    final todos = todoAsync.value ?? [];
    final days = range.dates.toList();

    final entries = <_AgendaEntry>[];
    for (final day in days) {
      final iso = day.toIso();
      for (final t in todos.where((x) => x.isoDate == iso)) {
        entries.add(
          _AgendaEntry(date: day, kind: _Kind.todo, label: t.title, id: t.id),
        );
      }
      for (final nid in noteMap[iso] ?? <String>[]) {
        entries.add(
          _AgendaEntry(date: day, kind: _Kind.note, label: nid, id: nid),
        );
      }
    }

    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Nothing upcoming in the next 30 days',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final e = entries[i];
        final (icon, color) = switch (e.kind) {
          _Kind.todo => (AppIcons.habits, colors.warning),
          _Kind.note => (AppIcons.articleOutlined, colors.success),
        };
        return ListTile(
          leading: Icon(icon, color: color, size: 20),
          title: e.kind == _Kind.note
              ? _NoteEntryTitle(noteId: e.id)
              : Text(
                  e.label,
                  style: TextStyle(color: colors.text, fontSize: 14),
                ),
          subtitle: Text(
            e.date.toIso(),
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          onTap: e.kind == _Kind.note ? () => ctx.push('/notes/${e.id}') : null,
        );
      },
    );
  }
}

enum _Kind { todo, note }

class _AgendaEntry {
  const _AgendaEntry({
    required this.date,
    required this.kind,
    required this.label,
    required this.id,
  });
  final LocalDate date;
  final _Kind kind;
  final String label;
  final String id;
}

// ── Todo calendar markers provider ───────────────────────────────────────────

class _TodoMarker {
  const _TodoMarker({
    required this.isoDate,
    required this.title,
    required this.id,
  });
  final String isoDate;
  final String title;
  final String id;
}

final todoCalendarEntriesForMonth =
    StreamProvider.family<List<_TodoMarker>, DateRange>((ref, range) {
      final repo = ref.watch(todoRepositoryStateProvider);
      if (repo == null) return const Stream.empty();

      return repo.watchToday().asyncMap((_) async {
        final today = await repo.watchToday().first;
        final upcoming = await repo.watchUpcoming().first;
        final done = await repo.watchDone().first;
        final all = [...today, ...upcoming, ...done];
        return all
            .where(
              (t) =>
                  t.dueDate != null &&
                  range.contains(LocalDate.parse(t.dueDate!)),
            )
            .map(
              (t) => _TodoMarker(isoDate: t.dueDate!, title: t.title, id: t.id),
            )
            .toList();
      });
    });

// ── Day bottom sheet ──────────────────────────────────────────────────────────

class _DaySheet extends ConsumerWidget {
  const _DaySheet({
    required this.date,
    required this.showHabits,
    required this.showTodos,
    required this.showNotes,
  });
  final LocalDate date;
  final bool showHabits, showTodos, showNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${date.day} / ${date.month} / ${date.year}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (showHabits) _HabitDaySection(date: date),
            if (showTodos) _TodoDaySection(date: date),
            if (showNotes) _NoteDaySection(date: date),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _HabitDaySection extends ConsumerWidget {
  const _HabitDaySection({required this.date});
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.watch(habitRepositoryStateProvider);
    if (repo == null) return const SizedBox.shrink();
    return FutureBuilder<List<Habit>>(
      future: repo.watchActiveForDate(date).first,
      builder: (_, snap) {
        final habits = snap.data ?? [];
        if (habits.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Habits',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            ...habits.map(
              (h) => FutureBuilder<HabitLog?>(
                future: repo.getLog(h.id, date),
                builder: (_, logSnap) {
                  final isDone = logSnap.data?.isDone == true;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      AppIcons.habitIcons[h.iconIndex %
                          AppIcons.habitIcons.length],
                      color: AppColors.habitAccents[h.accentIndex % 8],
                      size: 20,
                    ),
                    title: Text(
                      h.name,
                      style: TextStyle(color: colors.text, fontSize: 14),
                    ),
                    trailing: isDone
                        ? Icon(AppIcons.check, color: colors.success)
                        : Icon(AppIcons.todoCircle, color: colors.outline),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _TodoDaySection extends ConsumerWidget {
  const _TodoDaySection({required this.date});
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.watch(todoRepositoryStateProvider);
    if (repo == null) return const SizedBox.shrink();

    return FutureBuilder<List<Todo>>(
      future: Future.wait([repo.watchToday().first, repo.watchUpcoming().first])
          .then((lists) => [...lists[0], ...lists[1]]),
      builder: (_, snap) {
        final forDay = (snap.data ?? [])
            .where((t) => t.dueDate != null && t.isDueOn(date))
            .toList();
        if (forDay.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tasks',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            ...forDay.map(
              (t) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: GestureDetector(
                  onTap: () async {
                    if (t.isDone) {
                      await repo.uncomplete(t.id);
                    } else {
                      await repo.complete(t.id);
                    }
                  },
                  child: Icon(
                    t.isDone ? AppIcons.todoChecked : AppIcons.todoCircle,
                    color: t.isDone ? colors.success : colors.outline,
                    size: 20,
                  ),
                ),
                title: Text(
                  t.title,
                  style: TextStyle(
                    color: t.isDone ? colors.textMuted : colors.text,
                    fontSize: 14,
                    decoration: t.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _NoteDaySection extends ConsumerWidget {
  const _NoteDaySection({required this.date});
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final monthRange = DateRange(
      start: LocalDate(date.year, date.month, 1),
      end: LocalDate(
        date.year,
        date.month,
        DateTime(date.year, date.month + 1, 0).day,
      ),
    );
    final mentionsAsync = ref.watch(
      notesDateMentionsByDateProvider(monthRange),
    );

    return mentionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (map) {
        final noteIds = map[date.toIso()] ?? [];
        if (noteIds.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            ...noteIds.map((id) => _NoteEntryTile(noteId: id)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _NoteEntryTile extends ConsumerWidget {
  const _NoteEntryTile({required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final titleAsync = ref.watch(_noteTitleProvider(noteId));
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(AppIcons.articleOutlined, size: 18, color: colors.success),
      title: Text(
        titleAsync.value ?? 'Note',
        style: TextStyle(fontSize: 14, color: colors.text),
      ),
      onTap: () => context.push('/notes/$noteId'),
    );
  }
}

class _NoteEntryTitle extends ConsumerWidget {
  const _NoteEntryTitle({required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final titleAsync = ref.watch(_noteTitleProvider(noteId));
    return Text(
      titleAsync.value ?? 'Note',
      style: TextStyle(color: colors.text, fontSize: 14),
    );
  }
}

final _noteTitleProvider = FutureProvider.family<String, String>((
  ref,
  noteId,
) async {
  final repo = ref.watch(noteRepositoryStateProvider);
  if (repo == null) return 'Note';
  final note = await repo.getById(noteId);
  if (note == null) return 'Note';
  return note.title.isEmpty ? 'Untitled' : note.title;
});

class _LayerChip extends StatelessWidget {
  const _LayerChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
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
          color: selected ? color.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? color : color.withAlpha(153),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
