// lib/features/todos/presentation/todos_screen.dart
// Spec §4.3: To-do list with Today / Upcoming / Anytime / Done views.

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/settings/application/settings_providers.dart'
    show countTodosForLockInProvider;
import 'package:streakin/features/notes/notes_module.dart'
    show noteSourceRemovedProvider;
import 'package:streakin/features/todos/application/todo_providers.dart';
import 'package:streakin/features/todos/domain/todo.dart';

// ── TodosScreen ───────────────────────────────────────────────────────────

class TodosScreen extends ConsumerStatefulWidget {
  const TodosScreen({super.key});

  @override
  ConsumerState<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends ConsumerState<TodosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _tabs = ['Today', 'Upcoming', 'Anytime', 'Done'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
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
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Tasks',
          style: TextStyle(
            color: colors.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: colors.brand,
          unselectedLabelColor: colors.textMuted,
          indicatorColor: colors.brand,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TodayView(),
          _UpcomingView(),
          _AnytimeView(),
          _DoneView(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
        onPressed: () => _openAddSheet(context),
        tooltip: 'Add task',
        child: const Icon(AppIcons.add),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TaskFormSheet(),
    );
  }
}

// ── Today view ────────────────────────────────────────────────────────────

class _TodayView extends ConsumerWidget {
  const _TodayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todosTodayProvider);
    return async.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorState(error: e),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.checkCircleOutline,
              message: 'Nothing due today — enjoy your day!',
            )
          : _TodoList(todos: todos, showDate: false),
    );
  }
}

// ── Upcoming view ─────────────────────────────────────────────────────────

class _UpcomingView extends ConsumerWidget {
  const _UpcomingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todosUpcomingProvider);
    return async.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorState(error: e),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.eventOutlined,
              message: 'No upcoming tasks.',
            )
          : _TodoList(todos: todos, showDate: true),
    );
  }
}

// ── Anytime view ──────────────────────────────────────────────────────────

class _AnytimeView extends ConsumerWidget {
  const _AnytimeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todosAnytimeProvider);
    return async.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorState(error: e),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.inboxOutlined,
              message: 'No tasks without a due date.',
            )
          : _TodoList(todos: todos, showDate: false),
    );
  }
}

// ── Done view ─────────────────────────────────────────────────────────────

class _DoneView extends ConsumerWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todosDoneProvider);
    return async.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorState(error: e),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.doneAll,
              message: 'No completed tasks yet.',
            )
          : _TodoList(todos: todos, showDate: true, isDoneList: true),
    );
  }
}

// ── Generic todo list ─────────────────────────────────────────────────────

class _TodoList extends ConsumerWidget {
  const _TodoList({
    required this.todos,
    required this.showDate,
    this.isDoneList = false,
  });

  final List<Todo> todos;
  final bool showDate;
  final bool isDoneList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: todos.length,
      itemBuilder: (context, i) =>
          _TodoTile(todo: todos[i], showDate: showDate, isDoneList: isDoneList),
    );
  }
}

// ── Todo tile ─────────────────────────────────────────────────────────────

class _TodoTile extends ConsumerWidget {
  const _TodoTile({
    required this.todo,
    required this.showDate,
    required this.isDoneList,
  });

  final Todo todo;
  final bool showDate;
  final bool isDoneList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final useCases = ref.read(todoUseCasesProvider);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colors.danger,
        child: const Icon(AppIcons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await useCases.deleteTodo(todo.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Task deleted'),
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  // Restore by saving the original todo without deletedAt.
                  await ref
                      .read(todoRepositoryProvider)
                      .save(todo.copyWith(deletedAt: () => null));
                },
              ),
            ),
          );
        }
      },
      child: Semantics(
        container: true,
        label: _a11ySummary(),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Semantics(
            label: todo.isDone ? 'Mark task pending' : 'Mark task done',
            child: GestureDetector(
              onTap: () async {
                if (todo.isDone) {
                  await useCases.uncompleteTodo(todo.id);
                } else {
                  await useCases.completeTodo(todo.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Task completed'),
                        duration: const Duration(seconds: 10),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => useCases.uncompleteTodo(todo.id),
                        ),
                      ),
                    );
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: todo.isDone ? colors.success : colors.outline,
                    width: 2,
                  ),
                  color: todo.isDone ? colors.success : Colors.transparent,
                ),
                child: todo.isDone
                    ? const Icon(AppIcons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              color: todo.isDone ? colors.textMuted : colors.text,
              decoration: todo.isDone ? TextDecoration.lineThrough : null,
              fontSize: 15,
            ),
          ),
          subtitle: _buildSubtitle(context, ref, colors),
          trailing: _buildPriorityDot(colors),
          onTap: () => _openEditSheet(context, ref),
        ),
      ),
    );
  }

  String _a11ySummary() {
    final b = StringBuffer(todo.title)
      ..write(', ')
      ..write(todo.isDone ? 'done' : 'pending');
    if (todo.priority != TodoPriority.none) {
      b.write(', ${todo.priority.name} priority');
    }
    if (todo.dueDate != null) {
      b.write(', due ${todo.dueDate}');
      if (todo.dueTime != null) b.write(' at ${todo.dueTime}');
    }
    return b.toString();
  }

  Widget? _buildSubtitle(
    BuildContext context,
    WidgetRef ref,
    AppColorTokens colors,
  ) {
    final parts = <String>[];

    if (showDate && todo.dueDate != null) {
      final date = LocalDate.parse(todo.dueDate!);
      final today = LocalDate.today();
      final tomorrow = today.addDays(1);
      String label;
      if (date == today) {
        label = 'Today';
      } else if (date == tomorrow) {
        label = 'Tomorrow';
      } else {
        final dt = DateTime(date.year, date.month, date.day);
        label = DateFormat('d MMM').format(dt);
      }
      if (todo.dueTime != null) label += ' · ${todo.dueTime}';
      parts.add(label);
    } else if (todo.dueTime != null) {
      parts.add(todo.dueTime!);
    }

    if (todo.hasSourceNote) {
      final removed =
          ref
              .watch(
                noteSourceRemovedProvider((
                  noteId: todo.sourceNoteId!,
                  blockId: todo.sourceBlockId!,
                )),
              )
              .value ??
          false;
      parts.add(removed ? 'Source removed' : 'From note');
    }

    if (parts.isEmpty) return null;

    final isOverdue =
        !todo.isDone &&
        todo.dueDate != null &&
        LocalDate.parse(todo.dueDate!) < LocalDate.today();

    return Text(
      parts.join(' · '),
      style: TextStyle(
        color: isOverdue ? colors.danger : colors.textMuted,
        fontSize: 12,
      ),
    );
  }

  Widget? _buildPriorityDot(AppColorTokens colors) {
    final color = switch (todo.priority) {
      TodoPriority.high => colors.danger,
      TodoPriority.medium => colors.warning,
      TodoPriority.none => null,
    };
    if (color == null) return null;
    return Semantics(
      label: 'Priority: ${todo.priority.name}',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskFormSheet(existing: todo),
    );
  }
}

// ── Task form sheet (Add / Edit) ──────────────────────────────────────────

class _TaskFormSheet extends ConsumerStatefulWidget {
  const _TaskFormSheet({this.existing, this.initialDueDate});
  final Todo? existing;

  /// Pre-fills the due date for new tasks (e.g. created from the calendar).
  final LocalDate? initialDueDate;

  @override
  ConsumerState<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<_TaskFormSheet> {
  final _titleCtrl = TextEditingController();
  LocalDate? _dueDate;
  TimeOfDay? _dueTime;
  TodoPriority _priority = TodoPriority.none;
  bool _countsForLockin = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _titleCtrl.text = t.title;
      if (t.dueDate != null) _dueDate = LocalDate.parse(t.dueDate!);
      if (t.dueTime != null) {
        final parts = t.dueTime!.split(':');
        _dueTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      _priority = t.priority;
      _countsForLockin = t.countsForLockin;
    } else {
      _dueDate = widget.initialDueDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                isEdit ? 'Edit task' : 'New task',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isEdit)
                IconButton(
                  icon: Icon(AppIcons.delete, color: colors.danger),
                  tooltip: 'Delete task',
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Title ────────────────────────────────────────────────────────
          TextField(
            controller: _titleCtrl,
            autofocus: !isEdit,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: colors.text, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Task title',
              hintStyle: TextStyle(color: colors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.brand, width: 2),
              ),
              filled: true,
              fillColor: colors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Due date + time row ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _FieldButton(
                  icon: AppIcons.calendarTodayOutlined,
                  label: _dueDate != null ? _formatDate(_dueDate!) : 'Due date',
                  hasValue: _dueDate != null,
                  onTap: _pickDate,
                  onClear: () => setState(() => _dueDate = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FieldButton(
                  icon: AppIcons.scheduleOutlined,
                  label: _dueTime != null ? _dueTime!.format(context) : 'Time',
                  hasValue: _dueTime != null,
                  onTap: _pickTime,
                  onClear: () => setState(() => _dueTime = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Priority row ──────────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Priority',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              const SizedBox(width: 12),
              ...TodoPriority.values.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PriorityChip(
                    priority: p,
                    selected: _priority == p,
                    onTap: () => setState(() => _priority = p),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Counts for lock-in toggle (only when the global setting is on) ─
          if (ref.watch(countTodosForLockInProvider))
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Counts for lock-in',
                    style: TextStyle(color: colors.text, fontSize: 14),
                  ),
                ),
                Switch.adaptive(
                  value: _countsForLockin,
                  activeThumbColor: colors.brand,
                  onChanged: (v) => setState(() => _countsForLockin = v),
                ),
              ],
            ),
          const SizedBox(height: 20),

          // ── Save button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.onBrand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Text(
                isEdit ? 'Save changes' : 'Add task',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(LocalDate d) {
    final today = LocalDate.today();
    if (d == today) return 'Today';
    if (d == today.addDays(1)) return 'Tomorrow';
    final dt = DateTime(d.year, d.month, d.day);
    return DateFormat('d MMM').format(dt);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate != null
          ? DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day)
          : now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(
        () => _dueDate = LocalDate(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  String? get _dueDateIso => _dueDate?.toIso();
  String? get _dueTimeStr => _dueTime != null
      ? '${_dueTime!.hour.toString().padLeft(2, '0')}:'
            '${_dueTime!.minute.toString().padLeft(2, '0')}'
      : null;

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      final useCases = ref.read(todoUseCasesProvider);
      if (widget.existing == null) {
        await useCases.addTodo(
          title: title,
          dueDate: _dueDateIso,
          dueTime: _dueTimeStr,
          priority: _priority,
          countsForLockin: _countsForLockin,
        );
      } else {
        final updated = widget.existing!.copyWith(
          title: title,
          dueDate: () => _dueDateIso,
          dueTime: () => _dueTimeStr,
          priority: _priority,
          countsForLockin: _countsForLockin,
        );
        await useCases.updateTodo(updated);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await ref.read(todoUseCasesProvider).deleteTodo(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }
}

// ── Priority chip ─────────────────────────────────────────────────────────

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TodoPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = switch (priority) {
      TodoPriority.none => ('None', colors.textMuted),
      TodoPriority.medium => ('Medium', colors.warning),
      TodoPriority.high => ('High', colors.danger),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : Colors.transparent,
          border: Border.all(
            color: selected ? color : colors.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : colors.textMuted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Field button (date / time picker trigger) ─────────────────────────────

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasValue ? colors.text : colors.textMuted,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasValue)
              GestureDetector(
                onTap: onClear,
                child: Icon(AppIcons.close, size: 14, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared states ─────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Text('Error: $error', style: TextStyle(color: colors.danger)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: colors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Public helper — shows the full Add Task sheet from anywhere in the app.
/// Used by the Dashboard quick action.
void showAddTaskSheet(
  BuildContext context, {
  Todo? existing,
  LocalDate? initialDueDate,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _TaskFormSheet(existing: existing, initialDueDate: initialDueDate),
  );
}
