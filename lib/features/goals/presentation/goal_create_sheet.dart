import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/application/goal_lifecycle_service.dart';
import 'package:streakin/features/goals/application/goal_providers.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';

void showGoalCreateSheet(BuildContext context, {Goal? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _GoalCreateSheet(existing: existing),
  );
}

class _GoalCreateSheet extends ConsumerStatefulWidget {
  const _GoalCreateSheet({this.existing});
  final Goal? existing;

  @override
  ConsumerState<_GoalCreateSheet> createState() => _GoalCreateSheetState();
}

class _GoalCreateSheetState extends ConsumerState<_GoalCreateSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _whyCtrl;
  late GoalKind _kind;
  late LocalDate _startDate;
  LocalDate? _endDate;
  int _durationDays = 90;
  bool _useDuration = true;
  int _accentIndex = 0;
  late bool _countFromStart;
  final List<String> _linkedHabitIds = [];
  bool _saving = false;
  int _step = 0; // 0=goal, 1=time, 2=habits, 3=reminders, 4=confirm

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _titleCtrl = TextEditingController(text: g?.title ?? '');
    _whyCtrl = TextEditingController(text: g?.why ?? '');
    _kind = g?.kind ?? GoalKind.dated;
    _startDate = g?.startDate ?? LocalDate.today();
    _endDate = g?.endDate;
    _accentIndex = g?.accentIndex ?? 0;
    _countFromStart = true; // default; loaded async below
    _loadCountFromStart();
    if (g != null && g.endDate != null) {
      final days = _daysBetween(g.startDate, g.endDate!) + 1;
      _durationDays = days;
      _useDuration = false;
    }
  }

  Future<void> _loadCountFromStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _countFromStart =
            prefs.getBool(AppIdentifiers.prefGoalCountFromStart) ?? true;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _whyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Handle(),
            _StepIndicator(step: _step, total: 5, colors: colors),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _buildStep(colors),
              ),
            ),
            _NavButtons(
              step: _step,
              total: 5,
              canAdvance: _canAdvance,
              saving: _saving,
              onBack: () => setState(() => _step--),
              onNext: _step < 4 ? () => setState(() => _step++) : _save,
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(AppColorTokens colors) {
    return switch (_step) {
      0 => _StepGoal(
        titleCtrl: _titleCtrl,
        whyCtrl: _whyCtrl,
        kind: _kind,
        accentIndex: _accentIndex,
        onKindChanged: (k) => setState(() => _kind = k),
        onAccentChanged: (a) => setState(() => _accentIndex = a),
        colors: colors,
      ),
      1 => _StepTime(
        kind: _kind,
        startDate: _startDate,
        endDate: _endDate,
        durationDays: _durationDays,
        useDuration: _useDuration,
        onStartChanged: (d) => setState(() => _startDate = d),
        onEndChanged: (d) => setState(() {
          _endDate = d;
          _useDuration = false;
        }),
        onDurationChanged: (n) => setState(() {
          _durationDays = n;
          _useDuration = true;
          _endDate = _startDate.addDays(n - 1);
        }),
        colors: colors,
      ),
      2 => _StepHabits(
        linkedIds: _linkedHabitIds,
        countFromStart: _countFromStart,
        onToggle: (id) => setState(() {
          if (_linkedHabitIds.contains(id)) {
            _linkedHabitIds.remove(id);
          } else {
            _linkedHabitIds.add(id);
          }
        }),
        onCountFromStartChanged: (v) => setState(() => _countFromStart = v),
        colors: colors,
      ),
      3 => _StepReminders(colors: colors),
      4 => _StepConfirm(
        title: _titleCtrl.text.trim(),
        kind: _kind,
        startDate: _startDate,
        endDate: _endDate,
        linkedCount: _linkedHabitIds.length,
        existing: widget.existing,
        colors: colors,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  bool get _canAdvance {
    if (_step == 0) return _titleCtrl.text.trim().isNotEmpty;
    if (_step == 1 && _kind == GoalKind.dated) return _endDate != null;
    return true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = ref.read(goalLifecycleServiceProvider);
      if (svc == null) return;
      final draft = GoalDraft(
        title: _titleCtrl.text.trim(),
        why: _whyCtrl.text.trim().isEmpty ? null : _whyCtrl.text.trim(),
        kind: _kind,
        startDate: _startDate,
        endDate: _kind == GoalKind.dated ? _endDate : null,
        accentIndex: _accentIndex,
      );
      if (widget.existing == null) {
        await svc.setPrimaryGoal(
          draft,
          habitIds: _linkedHabitIds,
          countFromStart: _countFromStart,
        );
      } else {
        await svc.editGoal(widget.existing!, draft);
        for (final id in _linkedHabitIds) {
          await svc.linkHabit(
            widget.existing!,
            id,
            countFromStart: _countFromStart,
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static int _daysBetween(LocalDate from, LocalDate to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}

// ── Step widgets ──────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colors.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.total,
    required this.colors,
  });
  final int step;
  final int total;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i <= step ? colors.brand : colors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  const _NavButtons({
    required this.step,
    required this.total,
    required this.canAdvance,
    required this.saving,
    required this.onBack,
    required this.onNext,
    required this.colors,
  });
  final int step;
  final int total;
  final bool canAdvance;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
            ),
          if (step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: canAdvance && !saving ? onNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.onBrand,
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(step < total - 1 ? 'Next' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepGoal extends StatelessWidget {
  const _StepGoal({
    required this.titleCtrl,
    required this.whyCtrl,
    required this.kind,
    required this.accentIndex,
    required this.onKindChanged,
    required this.onAccentChanged,
    required this.colors,
  });
  final TextEditingController titleCtrl;
  final TextEditingController whyCtrl;
  final GoalKind kind;
  final int accentIndex;
  final ValueChanged<GoalKind> onKindChanged;
  final ValueChanged<int> onAccentChanged;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are you working toward?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleCtrl,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Goal title',
            counterText: '',
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: whyCtrl,
          maxLength: 280,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Why does this matter? (optional)',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _KindChip(
              label: 'Dated',
              selected: kind == GoalKind.dated,
              onTap: () => onKindChanged(GoalKind.dated),
              colors: colors,
            ),
            const SizedBox(width: 8),
            _KindChip(
              label: 'Open-ended',
              selected: kind == GoalKind.open,
              onTap: () => onKindChanged(GoalKind.open),
              colors: colors,
            ),
          ],
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.brand.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.brand : colors.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.brand : colors.textMuted,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StepTime extends StatelessWidget {
  const _StepTime({
    required this.kind,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.useDuration,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onDurationChanged,
    required this.colors,
  });
  final GoalKind kind;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int durationDays;
  final bool useDuration;
  final ValueChanged<LocalDate> onStartChanged;
  final ValueChanged<LocalDate?> onEndChanged;
  final ValueChanged<int> onDurationChanged;
  final AppColorTokens colors;

  static const _chips = [30, 60, 90, 100, 180, 365];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When does it start?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 12),
        _DateRow(
          label: 'Start date',
          date: startDate,
          onChanged: (d) {
            if (d != null) onStartChanged(d);
          },
          colors: colors,
        ),
        if (kind == GoalKind.dated) ...[
          const SizedBox(height: 16),
          Text(
            'How long?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chips
                .map(
                  (n) => _DurationChip(
                    days: n,
                    selected: useDuration && durationDays == n,
                    onTap: () => onDurationChanged(n),
                    colors: colors,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _DateRow(
            label: endDate != null
                ? 'Ends ${endDate!.toIso()}'
                : 'Pick end date',
            date: endDate,
            onChanged: onEndChanged,
            colors: colors,
          ),
          if (endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _preview(startDate, endDate!),
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ),
        ],
      ],
    );
  }

  String _preview(LocalDate start, LocalDate end) {
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    final days = b.difference(a).inDays + 1;
    return 'Ends ${end.toIso()} · $days days';
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.onChanged,
    required this.colors,
  });
  final String label;
  final LocalDate? date;
  final ValueChanged<LocalDate?> onChanged;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = date != null
            ? DateTime(date!.year, date!.month, date!.day)
            : DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (picked != null) {
          onChanged(LocalDate.fromDateTime(picked));
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.calendarTodayOutlined,
              size: 16,
              color: colors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: colors.text, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.days,
    required this.selected,
    required this.onTap,
    required this.colors,
  });
  final int days;
  final bool selected;
  final VoidCallback onTap;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colors.brand : colors.outline),
        ),
        child: Text(
          '$days days',
          style: TextStyle(
            color: selected ? colors.onBrand : colors.textMuted,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StepHabits extends ConsumerWidget {
  const _StepHabits({
    required this.linkedIds,
    required this.countFromStart,
    required this.onToggle,
    required this.onCountFromStartChanged,
    required this.colors,
  });
  final List<String> linkedIds;
  final bool countFromStart;
  final ValueChanged<String> onToggle;
  final ValueChanged<bool> onCountFromStartChanged;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(allHabitsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Link habits',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Linked habits contribute to goal alignment.',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 16),
        habitsAsync.when(
          loading: () => const CircularProgressIndicator.adaptive(),
          error: (_, _) => const SizedBox.shrink(),
          data: (habits) {
            final active = habits.where((h) => h.isActive).toList();
            if (active.isEmpty) {
              return Text(
                'No habits yet',
                style: TextStyle(color: colors.textMuted),
              );
            }
            return Column(
              children: active
                  .map(
                    (h) => CheckboxListTile(
                      dense: true,
                      value: linkedIds.contains(h.id),
                      onChanged: (_) => onToggle(h.id),
                      title: Text(
                        h.name,
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                      activeColor: colors.brand,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          value: countFromStart,
          onChanged: onCountFromStartChanged,
          activeThumbColor: colors.brand,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Count from goal start',
            style: TextStyle(fontSize: 14, color: colors.text),
          ),
          subtitle: Text(
            'Include existing logs since the goal start date',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _StepReminders extends StatelessWidget {
  const _StepReminders({required this.colors});
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminders',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure detailed reminder settings in Settings → Goals after creating the goal.',
          style: TextStyle(fontSize: 13, color: colors.textMuted),
        ),
      ],
    );
  }
}

class _StepConfirm extends ConsumerWidget {
  const _StepConfirm({
    required this.title,
    required this.kind,
    required this.startDate,
    required this.endDate,
    required this.linkedCount,
    required this.existing,
    required this.colors,
  });
  final String title;
  final GoalKind kind;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int linkedCount;
  final Goal? existing;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGoal = ref.watch(activeGoalProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 16),
        _ConfirmRow(label: 'Title', value: title, colors: colors),
        _ConfirmRow(
          label: 'Type',
          value: kind == GoalKind.dated ? 'Dated' : 'Open-ended',
          colors: colors,
        ),
        _ConfirmRow(label: 'Start', value: startDate.toIso(), colors: colors),
        if (endDate != null)
          _ConfirmRow(label: 'End', value: endDate!.toIso(), colors: colors),
        _ConfirmRow(
          label: 'Linked habits',
          value: '$linkedCount habit${linkedCount == 1 ? '' : 's'}',
          colors: colors,
        ),
        if (activeGoal != null && existing == null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.warning.withAlpha(80)),
            ),
            child: Text(
              '"${activeGoal.title}" will be archived as Replaced.',
              style: TextStyle(fontSize: 13, color: colors.text),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.label,
    required this.value,
    required this.colors,
  });
  final String label;
  final String value;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
