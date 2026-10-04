// lib/features/habits/presentation/habit_form.dart
// Create / edit habit form. Spec §4.2 FR-HAB-1.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';

class HabitForm extends ConsumerStatefulWidget {
  const HabitForm({this.existing, super.key});
  final Habit? existing;

  static Future<void> show(BuildContext context, {Habit? habit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitForm(existing: habit),
    );
  }

  @override
  ConsumerState<HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<HabitForm> {
  static const _uuid = Uuid();

  final _nameCtrl = TextEditingController();
  int _iconIndex = 0;
  int _accentIndex = 0;
  ScheduleMask _schedule = ScheduleMask.every;
  int _restTokens = 0;
  String? _reminderTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    if (h != null) {
      _nameCtrl.text = h.name;
      _iconIndex = h.iconIndex;
      _accentIndex = h.accentIndex;
      _schedule = h.scheduleMask;
      _restTokens = h.restTokensPerWeek;
      _reminderTime = h.reminderTime;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _maxRestTokens => _schedule.maxRestTokens;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final habit = Habit(
      id: widget.existing?.id ?? _uuid.v4(),
      name: name,
      iconIndex: _iconIndex,
      accentIndex: _accentIndex,
      scheduleMask: _schedule,
      reminderTime: _reminderTime,
      startDate: widget.existing?.startDate ?? LocalDate.today(),
      archivedAt: widget.existing?.archivedAt,
      sortOrder: widget.existing?.sortOrder ?? 0,
      restTokensPerWeek: _restTokens.clamp(0, _maxRestTokens),
      hlc: Hlc.now().toIso(),
      deletedAt: widget.existing?.deletedAt,
    );

    await ref.read(habitUseCasesProvider).saveHabit(habit);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? 'New habit' : 'Edit habit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Name
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Habit name'),
            ),
            const SizedBox(height: 20),

            // Icon picker
            Text('Icon', style: TextStyle(color: colors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppIcons.habitIcons.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = i == _iconIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _iconIndex = i),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.habitAccents[_accentIndex].withValues(alpha: 0.2)
                            : colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected
                                ? AppColors.habitAccents[_accentIndex]
                                : colors.outline),
                      ),
                      child: Icon(AppIcons.habitIcons[i],
                          size: 22,
                          color: selected
                              ? AppColors.habitAccents[_accentIndex]
                              : colors.textMuted),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Accent colour
            Text('Colour', style: TextStyle(color: colors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                AppColors.habitAccents.length,
                (i) => GestureDetector(
                  onTap: () => setState(() => _accentIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.habitAccents[i],
                      shape: BoxShape.circle,
                      border: i == _accentIndex
                          ? Border.all(color: colors.text, width: 2.5)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Schedule — weekday toggles
            Text('Schedule', style: TextStyle(color: colors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final bit = (1 << i);
                final on = (_schedule.value & bit) != 0;
                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return GestureDetector(
                  onTap: () {
                    final newMask = on
                        ? _schedule.value & ~bit
                        : _schedule.value | bit;
                    setState(() {
                      _schedule = ScheduleMask(newMask.clamp(0, 127));
                      _restTokens = _restTokens.clamp(0, _schedule.maxRestTokens);
                    });
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: on ? colors.brand : colors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: on ? colors.brand : colors.outline),
                    ),
                    child: Center(
                      child: Text(labels[i],
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: on ? colors.onBrand : colors.textMuted)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Rest tokens
            if (_maxRestTokens > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Text('Rest tokens / week',
                        style: TextStyle(color: colors.textMuted, fontSize: 13)),
                  ),
                  DropdownButton<int>(
                    value: _restTokens.clamp(0, _maxRestTokens),
                    items: List.generate(
                      _maxRestTokens + 1,
                      (i) => DropdownMenuItem(value: i, child: Text('$i')),
                    ),
                    onChanged: (v) => setState(() => _restTokens = v ?? 0),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.existing == null ? 'Add habit' : 'Save changes'),
              ),
            ),

            // Archive (edit only)
            if (widget.existing != null && !widget.existing!.isArchived) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(habitUseCasesProvider).archiveHabit(widget.existing!.id);
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Archive habit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
