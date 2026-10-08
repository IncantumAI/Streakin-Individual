// lib/app/router.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streakin/core/security/lock_controller.dart';
import 'package:streakin/features/calendar/presentation/calendar_screen.dart';
import 'package:streakin/features/dashboard/presentation/dashboard_screen.dart';
import 'package:streakin/features/habits/presentation/habits_screen.dart';
import 'package:streakin/features/notes/presentation/notes_screen.dart';
import 'package:streakin/features/notes/presentation/note_editor_screen.dart';
import 'package:streakin/features/onboarding/presentation/lock_screen.dart';
import 'package:streakin/features/onboarding/presentation/onboarding_screen.dart';
import 'package:streakin/features/settings/presentation/settings_screen.dart';
import 'package:streakin/features/todos/presentation/todos_screen.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';
import 'package:streakin/app/shell/app_shell.dart';
import 'package:streakin/core/storage/session_scope.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const lock = '/lock';
  static const home = '/home';
  static const habits = '/habits';
  static const notes = '/notes';
  static const calendar = '/calendar';
  static const tasks = '/tasks';
  static const settings = '/settings';
}

// ── Splash animation minimum duration ──────────────────────────────────────────
final splashAnimationProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(milliseconds: 1800));
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _RouterListenable(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // While onboarding status or splash animation is loading, stay on splash.
      final onboardingAsync = ref.read(onboardingDoneProvider);
      final splashAnimAsync = ref.read(splashAnimationProvider);
      if (onboardingAsync.isLoading || splashAnimAsync.isLoading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final onboardingDone = onboardingAsync.value ?? false;
      final isLocked = ref.read(LockController.provider.notifier).isLocked;

      // Not set up yet — always go to onboarding.
      if (!onboardingDone) {
        return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      // Set up, but locked — go to lock screen (except public routes).
      if (isLocked) {
        if (loc == AppRoutes.lock || loc == AppRoutes.onboarding) return null;
        final returnTo = Uri.encodeComponent(loc == AppRoutes.splash ? AppRoutes.home : loc);
        return '${AppRoutes.lock}?from=$returnTo';
      }

      // Set up + unlocked — redirect away from splash/lock/onboarding to home.
      if (loc == AppRoutes.splash ||
          loc == AppRoutes.lock ||
          loc == AppRoutes.onboarding) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['from'];
          return LockScreen(returnTo: returnTo);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notes/:noteId',
        name: 'note-editor',
        builder: (context, state) => NoteEditorScreen(
          noteId: state.pathParameters['noteId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => SessionScope(child: AppShell(shell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.habits, builder: (_, __) => const HabitsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.notes, builder: (_, __) => const NotesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.calendar, builder: (_, __) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.tasks, builder: (_, __) => const TodosScreen()),
          ]),
        ],
      ),
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Animated splash screen
// ─────────────────────────────────────────────────────────────────────────────

/// Animated splash screen shown while onboarding status loads.
///
/// Features:
///  • Radial-gradient purple background (top-centre bright → deep dark).
///  • App icon fades + scales in with an easeOutBack spring.
///  • A ring of 12 orbit dots continuously rotates with a comet-shimmer.
///  • The entire icon+text block subtly pulses once the fade-in completes.
///  • Three bouncing loading dots appear below the tagline.
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _orbitCtrl;
  late final AnimationController _shimmerCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // 1. Fade + scale-in (700 ms, easeOutBack for a spring feel).
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack),
    );

    // 2. Pulse — starts after fade-in, loops 1.0 ↔ 1.06.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // 3. Orbit ring rotation — full 360° every 3 s.
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // 4. Comet shimmer sweeps at a different speed (2.2 s).
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _fadeCtrl.forward().then((_) {
      if (mounted) _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandPurple     = Color(0xFF6E56CF);
    const brandPurpleMid  = Color(0xFF5244B0);
    const brandPurpleDark = Color(0xFF2D1F6E);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.35,
            colors: [brandPurple, brandPurpleMid, brandPurpleDark],
            stops: [0.0, 0.40, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: child,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Icon with orbit ring ─────────────────────────────
                      SizedBox(
                        width: 144,
                        height: 144,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Rotating orbit ring with comet shimmer.
                            AnimatedBuilder(
                              animation: Listenable.merge(
                                  [_orbitCtrl, _shimmerCtrl]),
                              builder: (_, __) => Transform.rotate(
                                angle: _orbitCtrl.value * 2 * math.pi,
                                child: CustomPaint(
                                  size: const Size(144, 144),
                                  painter: _OrbitRingPainter(
                                    shimmerAngle:
                                        _shimmerCtrl.value * 2 * math.pi,
                                  ),
                                ),
                              ),
                            ),
                            // App icon.
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(22),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withAlpha(65),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(55),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: brandPurple.withAlpha(130),
                                    blurRadius: 40,
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.asset(
                                  'assets/icon.png',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  // Fallback in case the asset somehow fails.
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.bolt_rounded,
                                    size: 56,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // ── App name ─────────────────────────────────────────
                      const Text(
                        'Streakin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your private space to grow',
                        style: TextStyle(
                          color: Colors.white.withAlpha(178),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 48),
                      // ── Bouncing loading dots ─────────────────────────────
                      _LoadingDots(controller: _orbitCtrl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints 12 dots arranged in a circle. A bright "comet head" at
/// [shimmerAngle] fades out in a trailing arc giving a shooting-star effect.
class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({required this.shimmerAngle});
  final double shimmerAngle;

  static const _dotCount  = 12;
  static const _dotRadius = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = size.width  / 2 - 5.0;

    for (int i = 0; i < _dotCount; i++) {
      final angle = (i / _dotCount) * 2 * math.pi;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);

      // Angular distance from the shimmer head — normalise to [0, π].
      double delta = (angle - shimmerAngle) % (2 * math.pi);
      if (delta < 0) delta += 2 * math.pi;
      final normalised = delta < math.pi ? delta : 2 * math.pi - delta;

      // Brightness peaks at the comet head, falls off over half a circle.
      final brightness = (1.0 - normalised / math.pi).clamp(0.0, 1.0);
      final alpha      = (55 + brightness * 200).round().clamp(0, 255);

      canvas.drawCircle(
        Offset(x, y),
        _dotRadius,
        Paint()..color = Colors.white.withAlpha(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter old) =>
      old.shimmerAngle != shimmerAngle;
}

/// Three dots that bounce with a sinusoidal wave, offset by 120° each.
class _LoadingDots extends AnimatedWidget {
  const _LoadingDots({required AnimationController controller})
      : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as AnimationController).value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase  = (t + i / 3.0) % 1.0;
        final bounce = math.sin(phase * math.pi); // 0 → 1 → 0
        final alpha  = (100 + bounce * 155).round();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.translate(
            offset: Offset(0, -bounce * 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(alpha),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Listens to both LockController and onboardingDoneProvider so the
/// router refreshes when either changes.
class _RouterListenable extends ChangeNotifier {
  _RouterListenable(Ref ref) {
    ref.listen(LockController.provider, (_, __) => notifyListeners());
    ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
    ref.listen(splashAnimationProvider, (_, __) => notifyListeners());
  }
}
