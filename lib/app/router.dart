// lib/app/router.dart

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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _RouterListenable(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // While onboarding status is loading, stay on splash (spinner).
      final onboardingAsync = ref.read(onboardingDoneProvider);
      if (onboardingAsync.isLoading) {
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
        builder: (_, _) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
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
        builder: (_, _) => const SettingsScreen(),
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
            GoRoute(path: AppRoutes.home, builder: (_, _) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.habits, builder: (_, _) => const HabitsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.notes, builder: (_, _) => const NotesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.calendar, builder: (_, _) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.tasks, builder: (_, _) => const TodosScreen()),
          ]),
        ],
      ),
    ],
  );
});

/// Shown while onboarding status loads from SharedPreferences.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

/// Listens to both LockController and onboardingDoneProvider so the
/// router refreshes when either changes.
class _RouterListenable extends ChangeNotifier {
  _RouterListenable(Ref ref) {
    ref.listen(LockController.provider, (_, _) => notifyListeners());
    ref.listen(onboardingDoneProvider, (_, _) => notifyListeners());
  }
}
