// lib/features/todos/presentation/todos_screen.dart
// Spec §4.3: To-do list with Today / Upcoming / Anytime / Done views.

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:streakin/core/design/elevation.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/settings/application/settings_providers.dart'
    show countTodosForLockInProvider;
import 'package:streakin/features/notes/notes_module.dart'
    show noteSourceRemovedProvider;
import 'package:streakin/features/todos/application/todo_providers.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/shared/feedback/haptics.dart';
import 'package:streakin/shared/widgets/widgets.dart';

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
        title: const Text('Tasks'),
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
                labelPadding: EdgeInsets.zero,
                indicator: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: colors.outline),
                  boxShadow: AppElevation.floating(colors),
                ),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        tooltip: 'Add task',
        icon: const Icon(AppIcons.add),
        label: const Text('New task'),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      showDragHandle: false,
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
      error: (e, st) => _ErrorState(error: e, stackTrace: st),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.checkCircleOutline,
              title: 'Nothing due today',
              message: 'Enjoy your day, or plan something for later.',
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
      error: (e, st) => _ErrorState(error: e, stackTrace: st),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.eventOutlined,
              title: 'No upcoming tasks',
              message: 'Tasks with a future due date land here.',
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
      error: (e, st) => _ErrorState(error: e, stackTrace: st),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.inboxOutlined,
              title: 'Inbox zero',
              message: 'Tasks without a due date show up here.',
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
      error: (e, st) => _ErrorState(error: e, stackTrace: st),
      data: (todos) => todos.isEmpty
          ? const _EmptyState(
              icon: AppIcons.doneAll,
              title: 'No completed tasks yet',
              message: 'Finished tasks are kept here for reference.',
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        96,
      ),
      itemCount: todos.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
      itemBuilder: (context, i) => StaggeredEntrance(
        index: i,
        child: _TodoTile(
          todo: todos[i],
          showDate: showDate,
          isDoneList: isDoneList,
        ),
      ),
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

    final d = resolvedDuration(context, AppDurations.base);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.xl),
        decoration: BoxDecoration(
          color: colors.dangerSubtle,
          borderRadius: AppRadius.brLg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: context.text.labelLarge!.copyWith(color: colors.danger),
            ),
            const SizedBox(width: AppSpace.sm),
            Icon(AppIcons.delete, color: colors.danger),
          ],
        ),
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
        child: AppCard(
          onTap: () => _openEditSheet(context, ref),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xs,
            AppSpace.xs,
            AppSpace.lg,
            AppSpace.xs,
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                checked: todo.isDone,
                label: todo.isDone ? 'Mark task pending' : 'Mark task done',
                child: InkResponse(
                  radius: 24,
                  onTap: () async {
                    final haptics = ref.read(hapticsProvider);
                    if (todo.isDone) {
                      haptics.tap();
                      await useCases.uncompleteTodo(todo.id);
                    } else {
                      haptics.success();
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
                  child: SizedBox.square(
                    dimension: AppSizes.minTap,
                    child: Center(
                      child: AnimatedContainer(
                        duration: d,
                        curve: AppCurves.emphasized,
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: todo.isDone
                                ? colors.success
                                : colors.outlineStrong,
                            width: 2,
                          ),
                          color: todo.isDone
                              ? colors.success
                              : AppColors.transparent,
                        ),
                        child: AnimatedSwitcher(
                          duration: d,
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: todo.isDone
                              ? Icon(
                                  AppIcons.check,
                                  key: const ValueKey('done'),
                                  size: 14,
                                  color: colors.surface,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: d,
                        style: context.text.bodyLarge!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: todo.isDone ? colors.textMuted : colors.text,
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: colors.textMuted,
                        ),
                        child: Text(todo.title),
                      ),
                      ?_buildSubtitle(context, ref, colors),
                    ],
                  ),
                ),
              ),
              ?_buildPriorityDot(colors),
            ],
          ),
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

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xxs),
      child: Row(
        children: [
          if (isOverdue) ...[
            Icon(AppIcons.dueDate, size: 13, color: colors.danger),
            const SizedBox(width: AppSpace.xs),
          ],
          Flexible(
            child: Text(
              isOverdue ? 'Overdue · ${parts.join(' · ')}' : parts.join(' · '),
              style: context.text.bodySmall!.copyWith(
                color: isOverdue ? colors.danger : colors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
      child: StatusPill(
        todo.priority == TodoPriority.high ? 'High' : 'Medium',
        tone: todo.priority == TodoPriority.high
            ? PillTone.danger
            : PillTone.warning,
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      showDragHandle: false,
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
      margin: const EdgeInsets.fromLTRB(
        AppSpace.sm,
        0,
        AppSpace.sm,
        AppSpace.sm,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.xl,
        AppSpace.xl,
        AppSpace.xl + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: AppRadius.brXl,
        border: Border.all(color: colors.outline),
        boxShadow: AppElevation.overlay(colors),
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
                style: context.text.headlineSmall,
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
        duration: resolvedDuration(context, AppDurations.base),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppColors.transparent,
          border: Border.all(
            color: selected ? color : colors.outline,
            width: 1.5,
          ),
          borderRadius: AppRadius.brPill,
        ),
        child: Text(
          label,
          style: context.text.labelLarge!.copyWith(
            color: selected ? color : colors.textMuted,
            fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.md,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: hasValue
                ? colors.brand.withValues(alpha: 0.5)
                : colors.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: context.text.bodyMedium!.copyWith(
                  fontSize: 14,
                  color: hasValue ? colors.text : colors.textMuted,
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
  Widget build(BuildContext context) => const SkeletonList();
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, this.stackTrace});
  final Object error;
  final StackTrace? stackTrace;
  @override
  Widget build(BuildContext context) {
    return ErrorState(
      error: error,
      stackTrace: stackTrace,
      title: 'Couldn’t load tasks',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: icon, title: title, message: message);
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
    backgroundColor: AppColors.transparent,
    showDragHandle: false,
    builder: (_) =>
        _TaskFormSheet(existing: existing, initialDueDate: initialDueDate),
  );
}
