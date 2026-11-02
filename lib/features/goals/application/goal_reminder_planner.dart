import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streakin/core/notifications/notification_reconciler.dart'
    show initNotifications;
import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_clock.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';
import 'package:timezone/timezone.dart' as tz;

const _maxPrecomputed = 30;

class GoalReminderSettings {
  const GoalReminderSettings({
    required this.cadence,
    required this.hour,
    required this.minute,
    required this.finalStretch,
    required this.milestoneAlerts,
    required this.completionAlert,
    required this.showTitle,
    required this.showAlignment,
    required this.suppressIfDone,
  });

  final String cadence; // 'off'|'daily'|'every2'|'every3'|'every5'|'weekly'|'milestones_only'
  final int hour;
  final int minute;
  final bool finalStretch;
  final bool milestoneAlerts;
  final bool completionAlert;
  final bool showTitle;
  final bool showAlignment;
  final bool suppressIfDone;

  static const defaults = GoalReminderSettings(
    cadence: 'daily',
    hour: 8,
    minute: 0,
    finalStretch: true,
    milestoneAlerts: true,
    completionAlert: true,
    showTitle: false,
    showAlignment: false,
    suppressIfDone: true,
  );

  static Future<GoalReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return GoalReminderSettings(
      cadence:
          prefs.getString(AppIdentifiers.prefGoalReminderCadence) ?? 'daily',
      hour: prefs.getInt(AppIdentifiers.prefGoalReminderHour) ?? 8,
      minute: prefs.getInt(AppIdentifiers.prefGoalReminderMinute) ?? 0,
      finalStretch: prefs.getBool(AppIdentifiers.prefGoalFinalStretch) ?? true,
      milestoneAlerts:
          prefs.getBool(AppIdentifiers.prefGoalMilestoneAlerts) ?? true,
      completionAlert:
          prefs.getBool(AppIdentifiers.prefGoalCompletionAlert) ?? true,
      showTitle: prefs.getBool(AppIdentifiers.prefGoalShowTitle) ?? false,
      showAlignment:
          prefs.getBool(AppIdentifiers.prefGoalShowAlignment) ?? false,
      suppressIfDone:
          prefs.getBool(AppIdentifiers.prefGoalSuppressIfDone) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppIdentifiers.prefGoalReminderCadence, cadence);
    await prefs.setInt(AppIdentifiers.prefGoalReminderHour, hour);
    await prefs.setInt(AppIdentifiers.prefGoalReminderMinute, minute);
    await prefs.setBool(AppIdentifiers.prefGoalFinalStretch, finalStretch);
    await prefs.setBool(
      AppIdentifiers.prefGoalMilestoneAlerts,
      milestoneAlerts,
    );
    await prefs.setBool(
      AppIdentifiers.prefGoalCompletionAlert,
      completionAlert,
    );
    await prefs.setBool(AppIdentifiers.prefGoalShowTitle, showTitle);
    await prefs.setBool(AppIdentifiers.prefGoalShowAlignment, showAlignment);
    await prefs.setBool(AppIdentifiers.prefGoalSuppressIfDone, suppressIfDone);
  }
}

class GoalReminderPlanner {
  GoalReminderPlanner({required this._goalRepo, required this._habitPort});

  final GoalRepository _goalRepo;
  final HabitCompletionPort _habitPort;
  final _plugin = FlutterLocalNotificationsPlugin();

  static int _idFor(String goalId, String kind, String date) =>
      ('goal_$goalId$kind$date').hashCode.abs() % 100000;

  Future<void> reconcile() async {
    try {
      await initNotifications();
      await _cancelAllGoalNotifications();
      final settings = await GoalReminderSettings.load();
      if (settings.cadence == 'off') return;

      final goal = await _goalRepo.getActive();
      if (goal == null) return;

      final today = LocalDate.today();
      final clock = GoalClock.compute(goal, today);

      if (clock.phase == GoalPhase.ended) {
        if (settings.completionAlert) {
          await _scheduleOnce(
            id: _idFor(goal.id, 'complete', today.toIso()),
            title: _buildTitle(goal, clock, settings),
            body: 'Goal complete! Check your summary.',
            daysFromNow: 0,
            hour: settings.hour,
            minute: settings.minute,
          );
        }
        return;
      }

      // Check suppress-if-done
      bool suppress = false;
      if (settings.suppressIfDone) {
        final links = await _goalRepo.getLinksForGoal(goal.id);
        final habitIds = links
            .where((l) => l.isOpen)
            .map((l) => l.habitId)
            .toList();
        if (habitIds.isNotEmpty) {
          final live = await _habitPort.todayLiveStats(
            habitIds: habitIds,
            today: today,
          );
          suppress = live.scheduled > 0 && live.done == live.scheduled;
        }
      }

      // Schedule upcoming occurrences
      final occurrences = _buildOccurrences(clock, settings, today);
      int count = 0;
      for (final day in occurrences) {
        if (count >= _maxPrecomputed) break;
        final isToday = day == today;
        if (isToday && suppress) continue;
        final dayNumber = day == today
            ? clock.dayNumber
            : _clockForDay(goal, day).dayNumber;
        final dayTotal = clock.totalDays;
        final body = dayTotal != null
            ? 'Day $dayNumber of $dayTotal'
            : 'Day $dayNumber';
        await _scheduleOnce(
          id: _idFor(goal.id, 'daily', day.toIso()),
          title: _buildTitleForDay(goal, settings, dayNumber, dayTotal),
          body: body,
          daysFromNow: _daysFrom(today, day),
          hour: settings.hour,
          minute: settings.minute,
        );
        count++;
      }

      // Tail fallback generic repeating
      if (count > 0) {
        // Precomputed window covers next ~30 occurrences; no tail needed for short goals
      }
    } catch (_) {}
  }

  List<LocalDate> _buildOccurrences(
    GoalClockState clock,
    GoalReminderSettings settings,
    LocalDate today,
  ) {
    final result = <LocalDate>[];
    if (settings.cadence == 'milestones_only') return result;

    final endDate = clock.goal.kind == GoalKind.dated
        ? clock.goal.endDate
        : today.addDays(365);

    final step = switch (settings.cadence) {
      'every2' => 2,
      'every3' => 3,
      'every5' => 5,
      'weekly' => 7,
      _ => 1, // daily
    };

    var d = today;
    while (endDate == null || d <= endDate) {
      if (result.length >= _maxPrecomputed) break;

      final isFinalStretch =
          clock.goal.kind == GoalKind.dated &&
          clock.daysLeft != null &&
          _daysFrom(today, d) <= 7 &&
          settings.finalStretch;

      if (isFinalStretch || step == 1) {
        result.add(d);
      } else if (_daysFrom(today, d) % step == 0) {
        result.add(d);
      }
      d = d.addDays(1);
    }
    return result;
  }

  String _buildTitle(
    Goal goal,
    GoalClockState clock,
    GoalReminderSettings settings,
  ) {
    if (settings.showTitle) return goal.title;
    return 'Goal countdown';
  }

  String _buildTitleForDay(
    Goal goal,
    GoalReminderSettings settings,
    int dayNumber,
    int? total,
  ) {
    if (settings.showTitle) return goal.title;
    if (total != null) return 'Day $dayNumber of $total';
    return 'Day $dayNumber';
  }

  GoalClockState _clockForDay(Goal goal, LocalDate day) =>
      GoalClock.compute(goal, day);

  int _daysFrom(LocalDate today, LocalDate other) {
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(other.year, other.month, other.day);
    return b.difference(a).inDays;
  }

  Future<void> _scheduleOnce({
    required int id,
    required String title,
    required String body,
    required int daysFromNow,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    scheduled = scheduled.add(Duration(days: daysFromNow));
    if (scheduled.isBefore(now)) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AppIdentifiers.channelGoalCountdown,
          'Goal Countdown',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _cancelAllGoalNotifications() async {
    // Cancel by prefix scan is not directly supported; we cancel all and
    // let other planners re-schedule during the same reconcile pass.
    // Each planner only cancels its own known IDs in a real impl;
    // here we rely on the full reconciler cancelling all first.
  }
}
