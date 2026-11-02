// lib/features/habits/presentation/habit_form.dart
// Create / edit habit form. Spec §4.2 FR-HAB-1.
// Live preview header, grouped sections and a sticky save bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/shared/feedback/haptics.dart';
import 'package:streakin/shared/widgets/shake.dart';

class HabitForm extends ConsumerStatefulWidget {
  const HabitForm({this.existing, super.key});
  final Habit? existing;

  static Future<void> show(BuildContext context, {Habit? habit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      showDragHandle: false,
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
  bool _nameError = false;
  final _shake = ShakeController();

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
    _shake.dispose();
    super.dispose();
  }

  int get _maxRestTokens => _schedule.maxRestTokens;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = true);
      _shake.shake();
      ref.read(hapticsProvider).error();
      return;
    }
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
    ref.read(hapticsProvider).success();
    if (mounted) Navigator.pop(context);
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: Text(
      text.toUpperCase(),
      style: AppTypography.overline.copyWith(color: context.colors.textMuted),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = AppColors.habitAccents[_accentIndex];
    final d = resolvedDuration(context, AppDurations.base);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.md,
                  AppSpace.xl,
                  AppSpace.xl,
                ),
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineStrong.withValues(alpha: 0.6),
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),

                  // Live preview header
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: d,
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: AppRadius.brLg,
                        ),
                        child: AnimatedSwitcher(
                          duration: d,
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Icon(
                            AppIcons.habitIcons[_iconIndex],
                            key: ValueKey(_iconIndex),
                            size: 28,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.lg),
                      Expanded(
                        child: Text(
                          widget.existing == null ? 'New habit' : 'Edit habit',
                          style: context.text.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // Name
                  Shake(
                    controller: _shake,
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) {
                        if (_nameError) setState(() => _nameError = false);
                      },
                      decoration: InputDecoration(
                        labelText: 'Habit name',
                        hintText: 'e.g. Read 10 pages',
                        errorText: _nameError ? 'Give your habit a name' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // Icon picker
                  _label(context, 'Icon'),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppIcons.habitIcons.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpace.sm),
                      itemBuilder: (_, i) {
                        final selected = i == _iconIndex;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: 'Icon ${i + 1}',
                          child: GestureDetector(
                            onTap: () {
                              ref.read(hapticsProvider).selection();
                              setState(() => _iconIndex = i);
                            },
                            child: AnimatedContainer(
                              duration: d,
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: selected
                                    ? accent.withValues(alpha: 0.18)
                                    : colors.surfaceAlt,
                                borderRadius: AppRadius.brMd,
                                border: Border.all(
                                  color: selected
                                      ? accent
                                      : AppColors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                AppIcons.habitIcons[i],
                                size: 22,
                                color: selected ? accent : colors.textMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // Accent colour
                  _label(context, 'Colour'),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: List.generate(AppColors.habitAccents.length, (i) {
                      final selected = i == _accentIndex;
                      return Semantics(
                        button: true,
                        selected: selected,
                        label: 'Colour ${i + 1}',
                        child: GestureDetector(
                          onTap: () {
                            ref.read(hapticsProvider).selection();
                            setState(() => _accentIndex = i);
                          },
                          child: AnimatedContainer(
                            duration: d,
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.habitAccents[i]
                                    : AppColors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.habitAccents[i],
                                shape: BoxShape.circle,
                              ),
                              child: selected
                                  ? Icon(
                                      AppIcons.check,
                                      size: 16,
                                      color: colors.onBrand,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // Schedule — weekday toggles
                  _label(context, 'Schedule'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final bit = (1 << i);
                      final on = (_schedule.value & bit) != 0;
                      const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return Semantics(
                        button: true,
                        selected: on,
                        child: GestureDetector(
                          onTap: () {
                            ref.read(hapticsProvider).selection();
                            final newMask = on
                                ? _schedule.value & ~bit
                                : _schedule.value | bit;
                            setState(() {
                              _schedule = ScheduleMask(newMask.clamp(0, 127));
                              _restTokens = _restTokens.clamp(
                                0,
                                _schedule.maxRestTokens,
                              );
                            });
                          },
                          child: AnimatedContainer(
                            duration: d,
                            curve: AppCurves.emphasized,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: on ? colors.brand : colors.surfaceAlt,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: on ? colors.brand : colors.outline,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                labels[i],
                                style: context.text.labelLarge!.copyWith(
                                  color: on ? colors.onBrand : colors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    _schedule.value == 127
                        ? 'Every day'
                        : '${List.generate(7, (i) => (_schedule.value >> i) & 1).where((b) => b == 1).length} days a week',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // Rest tokens
                  if (_maxRestTokens > 0) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        AppSpace.sm,
                        AppSpace.sm,
                        AppSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: AppRadius.brMd,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.restToken,
                            size: AppSizes.iconMd,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rest tokens / week',
                                  style: context.text.titleSmall,
                                ),
                                Text(
                                  'Skip a day without breaking the streak',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<int>(
                            value: _restTokens.clamp(0, _maxRestTokens),
                            underline: const SizedBox.shrink(),
                            borderRadius: AppRadius.brMd,
                            items: List.generate(
                              _maxRestTokens + 1,
                              (i) =>
                                  DropdownMenuItem(value: i, child: Text('$i')),
                            ),
                            onChanged: (v) =>
                                setState(() => _restTokens = v ?? 0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                  ],

                  // Archive (edit only)
                  if (widget.existing != null &&
                      !widget.existing!.isArchived) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textMuted,
                      ),
                      onPressed: () async {
                        await ref
                            .read(habitUseCasesProvider)
                            .archiveHabit(widget.existing!.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(AppIcons.archive, size: AppSizes.iconMd),
                      label: const Text('Archive habit'),
                    ),
                  ],
                ],
              ),
            ),

            // Sticky save bar
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                AppSpace.md +
                    MediaQuery.viewInsetsOf(context).bottom +
                    MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                border: Border(top: BorderSide(color: colors.outline)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onBrand,
                          ),
                        )
                      : Text(
                          widget.existing == null
                              ? 'Add habit'
                              : 'Save changes',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
