// lib/features/zen/presentation/zen_screen.dart
// Spec §4.9: Zen entry (choose Writing or Focus) and Focus Zen — one habit at
// a time with a breathing circle (inhale 4 s / exhale 6 s) and an optional
// countdown. Reduced motion → a barely-moving static pulse.

import 'package:streakin/core/design/icons.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/features/goals/goals_module.dart' show GoalZenLine;
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/notes_module.dart'
    show noteRepositoryStateProvider;
import 'package:streakin/features/settings/application/settings_providers.dart'
    show reducedMotionProvider;
import 'package:streakin/shared/feedback/haptics.dart';
import 'package:streakin/shared/widgets/widgets.dart';

/// Breathing rhythm (Spec §4.9).
const Duration kInhale = Duration(seconds: 4);
const Duration kExhale = Duration(seconds: 6);

/// Reduced-motion pulse: scale 1.0 → 1.03 → 1.0, slow.
const double kReducedPulseScale = 1.03;
const Duration kReducedPulsePeriod = Duration(seconds: 10);

class ZenScreen extends ConsumerWidget {
  const ZenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Zen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              Text('Find your focus', style: context.text.displaySmall),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Distraction-free space for one thing at a time.',
                style: context.text.bodyLarge!.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              const GoalZenLine(),
              const SizedBox(height: AppSpace.xl),
              StaggeredEntrance(
                index: 0,
                child: _ZenModeCard(
                  icon: AppIcons.editNote,
                  title: 'Writing Zen',
                  description: 'A blank page, full screen. No toolbars, no noise. Just write.',
                  accent: AppColors.celebBrand,
                  onTap: () => _startWriting(context, ref),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              StaggeredEntrance(
                index: 1,
                child: _ZenModeCard(
                  icon: AppIcons.selfImprovement,
                  title: 'Focus Zen',
                  description: 'One habit at a time with a guided breathing circle and optional timer.',
                  accent: AppColors.celebTeal,
                  onTap: () => context.push('/zen/focus'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startWriting(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(noteRepositoryStateProvider);
    if (repo == null) return;
    final now = DateTime.now();
    final id = const Uuid().v4();
    await repo.saveNote(
      Note(
        id: id,
        title: '',
        body: '[]',
        createdAt: now,
        updatedAt: now,
        hlc: Hlc.now().toIso(),
      ),
    );
    if (context.mounted) unawaited(context.push('/notes/$id?zen=1'));
  }
}

class _ZenModeCard extends StatelessWidget {
  const _ZenModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: AppRadius.brLg,
            ),
            child: Icon(icon, size: 28, color: c.text),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(description, style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Icon(AppIcons.chevronRight, color: c.textMuted),
        ],
      ),
    );
  }
}

// ── Focus Zen ────────────────────────────────────────────────────────────────

class FocusZenScreen extends ConsumerStatefulWidget {
  const FocusZenScreen({this.habitId, super.key});
  final String? habitId;

  @override
  ConsumerState<FocusZenScreen> createState() => _FocusZenScreenState();
}

class _FocusZenScreenState extends ConsumerState<FocusZenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  int _index = 0;
  Duration? _timer; // chosen countdown
  Duration _left = Duration.zero;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: kInhale + kExhale);
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _breath.dispose();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _startTimer(Duration d) {
    _tick?.cancel();
    setState(() {
      _timer = d;
      _left = d;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left.inSeconds <= 1) {
        t.cancel();
        setState(() => _left = Duration.zero);
      } else {
        setState(() => _left -= const Duration(seconds: 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduced =
        ref.watch(reducedMotionProvider) ||
        MediaQuery.disableAnimationsOf(context);
    final habits =
        ref.watch(habitsForAllTodayProvider).value ?? const <Habit>[];
    final logs = ref.watch(todayLogsProvider).value ?? const {};

    // The tapped habit first, otherwise the next incomplete one.
    final queue = [
      if (widget.habitId != null)
        ...habits.where((h) => h.id == widget.habitId),
      ...habits.where(
        (h) =>
            h.id != widget.habitId && logs[h.id]?.status != HabitLogStatus.done,
      ),
    ];
    final habit = queue.isEmpty ? null : queue[_index % queue.length];

    if (reduced) {
      if (_breath.isAnimating || _breath.duration != kReducedPulsePeriod) {
        _breath
          ..stop()
          ..duration = kReducedPulsePeriod
          ..repeat();
      }
    } else if (_breath.duration != kInhale + kExhale || !_breath.isAnimating) {
      _breath
        ..stop()
        ..duration = kInhale + kExhale
        ..repeat();
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.1),
            radius: 1.0,
            colors: [AppColors.celebTeal.withValues(alpha: 0.08), colors.bg],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GoalZenLine(),
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        habit == null ? 'All clear' : 'FOCUS ON',
                        style: AppTypography.overline.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        child: Text(
                          habit?.name ?? 'Nothing left to focus on',
                          key: ValueKey(habit?.id),
                          textAlign: TextAlign.center,
                          style: context.text.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      AnimatedBuilder(
                        animation: _breath,
                        builder: (_, _) => CustomPaint(
                          size: const Size(260, 260),
                          painter: BreathingPainter(
                            scale: breathScale(_breath.value, reduced: reduced),
                            color: colors.brand,
                          ),
                          child: SizedBox(
                            width: 260,
                            height: 260,
                            child: Center(
                              child: Text(
                                _timer == null
                                    ? (reduced
                                          ? ''
                                          : breathLabel(_breath.value))
                                    : _fmt(_left),
                                style: context.text.headlineLarge!.copyWith(
                                  fontWeight: _timer == null
                                      ? FontWeight.w400
                                      : FontWeight.w300,
                                  fontSize: _timer == null ? 22 : 40,
                                  fontFeatures: AppTypography.tabular,
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      Wrap(
                        spacing: AppSpace.sm,
                        children: [
                          for (final m in [5, 10, 25])
                            ChoiceChip(
                              label: Text('$m min'),
                              selected: _timer == Duration(minutes: m),
                              onSelected: (_) =>
                                  _startTimer(Duration(minutes: m)),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xl),
                      if (habit != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: colors.textMuted,
                              ),
                              onPressed: () => setState(() => _index++),
                              child: const Text('Skip'),
                            ),
                            const SizedBox(width: AppSpace.md),
                            FilledButton.icon(
                              icon: const Icon(AppIcons.check),
                              label: const Text('Done'),
                              onPressed: () async {
                                ref.read(hapticsProvider).success();
                                await ref
                                    .read(habitUseCasesProvider)
                                    .checkHabit(habit.id);
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: AppSpace.xs,
                right: AppSpace.xs,
                child: IconButton(
                  tooltip: 'Exit',
                  icon: Icon(AppIcons.close, color: colors.textMuted),
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Circle scale for a cycle position [t] ∈ [0,1): inhale (expand) for the
/// first 4/10 of the cycle, exhale (contract) for the remaining 6/10.
/// Reduced motion: a tiny 1.0 → 1.03 → 1.0 pulse.
double breathScale(double t, {bool reduced = false}) {
  if (reduced) return 1 + (kReducedPulseScale - 1) * sin(t * pi);
  final inhaleShare =
      kInhale.inMilliseconds / (kInhale + kExhale).inMilliseconds;
  if (t < inhaleShare) {
    return 0.6 + 0.4 * Curves.easeInOut.transform(t / inhaleShare);
  }
  return 1.0 -
      0.4 * Curves.easeInOut.transform((t - inhaleShare) / (1 - inhaleShare));
}

String breathLabel(double t) {
  final inhaleShare =
      kInhale.inMilliseconds / (kInhale + kExhale).inMilliseconds;
  return t < inhaleShare ? 'Breathe in' : 'Breathe out';
}

class BreathingPainter extends CustomPainter {
  BreathingPainter({required this.scale, required this.color});
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * scale;
    // Soft outer glow, layered fill, crisp rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.05), color.withValues(alpha: 0.2)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(BreathingPainter old) =>
      old.scale != scale || old.color != color;
}
