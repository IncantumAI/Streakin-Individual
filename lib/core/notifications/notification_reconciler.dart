import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _initialised = false;

Future<void> initNotifications() async {
  if (_initialised) return;
  _initialised = true;
  tz.initializeTimeZones();
  try {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
  } catch (_) {}
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _plugin.initialize(
    settings: const InitializationSettings(android: android, iOS: ios),
  );
}

Future<void> _ensureChannels() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  await android.createNotificationChannel(const AndroidNotificationChannel(
    AppIdentifiers.channelHabitReminders,
    'Habit Reminders',
    importance: Importance.high,
  ));
  await android.createNotificationChannel(const AndroidNotificationChannel(
    AppIdentifiers.channelTodoReminders,
    'Task Reminders',
    importance: Importance.high,
  ));
  await android.createNotificationChannel(const AndroidNotificationChannel(
    AppIdentifiers.channelNoteMentions,
    'Note Reminders',
    importance: Importance.defaultImportance,
  ));
  await android.createNotificationChannel(const AndroidNotificationChannel(
    AppIdentifiers.channelLockInNudge,
    'Lock-In Nudge',
    importance: Importance.low,
  ));
}

class NotificationReconciler {
  NotificationReconciler({
    required HabitRepository habitRepo,
    required TodoRepository todoRepo,
  })  : _habitRepo = habitRepo,
        _todoRepo = todoRepo;

  final HabitRepository _habitRepo;
  final TodoRepository _todoRepo;

  static int _idFor(String type, String id) =>
      (type + id).hashCode.abs() % 100000;

  Future<void> reconcile() async {
    try {
      await initNotifications();
      await _ensureChannels();
      await _plugin.cancelAll();
      await _scheduleHabitReminders();
      await _scheduleTodoReminders();
    } catch (_) {}
  }

  Future<void> _scheduleHabitReminders() async {
    final habits = await _habitRepo.watchAll().first;
    final today = LocalDate.today();
    for (final h in habits) {
      if (!h.isActive || h.reminderTime == null) continue;
      final parts = h.reminderTime!.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      await _plugin.zonedSchedule(
        id: _idFor('habit', h.id),
        title: h.name,
        body: 'Time to check in!',
        scheduledDate: _nextInstance(today, hour, minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppIdentifiers.channelHabitReminders,
            'Habit Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _scheduleTodoReminders() async {
    final pending = await _todoRepo.watchToday().first;
    final upcoming = await _todoRepo.watchUpcoming().first;
    for (final t in [...pending, ...upcoming]) {
      if (t.reminderAt == null) continue;
      final dt = DateTime.tryParse(t.reminderAt!);
      if (dt == null || dt.isBefore(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id: _idFor('todo', t.id),
        title: t.title,
        body: 'Task reminder',
        scheduledDate: tz.TZDateTime.from(dt, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppIdentifiers.channelTodoReminders,
            'Task Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static tz.TZDateTime _nextInstance(LocalDate from, int hour, int minute) {
    var dt = tz.TZDateTime(
        tz.local, from.year, from.month, from.day, hour, minute);
    if (dt.isBefore(tz.TZDateTime.now(tz.local))) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }
}

class _ReconcilerNotifier extends Notifier<NotificationReconciler?> {
  @override
  NotificationReconciler? build() => null;
  void set(NotificationReconciler r) => state = r;
  void clear() => state = null;
}

final reconcilerStateProvider =
    NotifierProvider<_ReconcilerNotifier, NotificationReconciler?>(
        _ReconcilerNotifier.new);
