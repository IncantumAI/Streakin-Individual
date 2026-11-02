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

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/features/goals/goals_module.dart' show GoalZenLine;
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/notes_module.dart'
    show noteRepositoryStateProvider;
import 'package:streakin/features/settings/application/settings_providers.dart'
    show reducedMotionProvider;

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
      appBar: AppBar(title: const Text('Zen'), backgroundColor: colors.surface),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GoalZenLine(),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(AppIcons.editNote),
                  label: const Text('Writing Zen'),
                  onPressed: () => _startWriting(context, ref),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(AppIcons.selfImprovement),
                  label: const Text('Focus Zen'),
                  onPressed: () => context.push('/zen/focus'),
                ),
              ],
            ),
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
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoalZenLine(),
                  const SizedBox(height: 16),
                  Text(
                    habit?.name ?? 'Nothing left to focus on',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 32),
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
                                ? (reduced ? '' : breathLabel(_breath.value))
                                : _fmt(_left),
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in [5, 10, 25])
                        ChoiceChip(
                          label: Text('$m min'),
                          selected: _timer == Duration(minutes: m),
                          onSelected: (_) => _startTimer(Duration(minutes: m)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (habit != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _index++),
                          child: const Text('Skip'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          icon: const Icon(AppIcons.check),
                          label: const Text('Done'),
                          onPressed: () async {
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
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Exit',
                icon: Icon(AppIcons.close, color: colors.textMuted),
                onPressed: () => context.pop(),
              ),
            ),
          ],
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
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(BreathingPainter old) =>
      old.scale != scale || old.color != color;
}
