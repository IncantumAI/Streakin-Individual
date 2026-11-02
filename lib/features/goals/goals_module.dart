// lib/features/goals/goals_module.dart
// Public surface for the Goals feature. Other features ONLY import this file.

export 'application/goal_providers.dart'
    show
        goalRepositoryStateProvider,
        habitCompletionPortStateProvider,
        goalLifecycleServiceProvider,
        activeGoalProvider,
        goalClockProvider,
        goalAlignmentProvider,
        goalTodayLiveProvider,
        activeGoalLinksProvider,
        goalHistoryProvider,
        heroPromptDismissedProvider,
        dayTickerProvider;

export 'domain/goal.dart';
export 'domain/goal_clock.dart' show GoalClockState, GoalClock;
export 'domain/goal_repository.dart'
    show
        GoalRepository,
        HabitCompletionPort,
        HabitLinkWindow,
        AlignmentStats,
        PerHabitStats,
        HabitRef;

export 'presentation/goal_hero_card.dart' show GoalHeroCard;
export 'presentation/goal_zen_line.dart' show GoalZenLine;
export 'presentation/goal_create_sheet.dart' show showGoalCreateSheet;
export 'presentation/goal_detail_screen.dart' show GoalDetailScreen;
export 'presentation/goal_history_screen.dart' show GoalHistoryScreen;
