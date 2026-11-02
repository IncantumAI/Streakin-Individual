// lib/core/notifications/notification_reconciler.dart
// Spec §12.1/§12.2: derive the complete expected notification set from the
// DB, diff it against what is scheduled, cancel stale ones, (re)schedule the
// rest. Idempotent. Payloads are opaque "type:id" only.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:streakin/core/storage/identifiers.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _initialised = false;

/// Payload of the notification the user tapped. The app shell consumes it
/// after unlock (the router lock guard sends the user to the lock screen first).
final ValueNotifier<String?> notificationTapPayload = ValueNotifier(null);

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
  const linux = LinuxInitializationSettings(defaultActionName: 'Open');
  try {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: ios,
        linux: linux,
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) notificationTapPayload.value = r.payload;
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      notificationTapPayload.value = payload;
    }
  } catch (_) {}
}

Future<void> _ensureChannels() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final android = _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return;
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      AppIdentifiers.channelHabitReminders,
      'Habit Reminders',
      importance: Importance.high,
    ),
  );
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      AppIdentifiers.channelTodoReminders,
      'Task Reminders',
      importance: Importance.high,
    ),
  );
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      AppIdentifiers.channelNoteMentions,
      'Note Reminders',
    ),
  );
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      AppIdentifiers.channelLockInNudge,
      'Lock-In Nudge',
      importance: Importance.low,
    ),
  );
}

/// Fires an immediate notification. Returns false if permission is denied.
Future<bool> showTestNotification() async {
  await initNotifications();
  await _ensureChannels();
  final status = await Permission.notification.request();
  if (!status.isGranted) return false;
  await _plugin.show(
    id: 999001,
    title: 'Streakin test notification',
    body: 'Notifications are working.',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        AppIdentifiers.channelHabitReminders,
        'Habit Reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
  return true;
}

/// Opens this app's system settings page (notification toggles live there).
Future<bool> openNotificationSettings() => openAppSettings();

// ── Planned notification model ───────────────────────────────────────────────

enum NotificationKind { habit, lockInNudge, todo, dateMention }

@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.payload,
    required this.title,
    required this.channelId,
    required this.channelName,
    required this.at,
    this.body,
    this.repeatsDaily = false,
  });

  final int id;
  final NotificationKind kind;

  /// Opaque "type:id" — never contains user content.
  final String payload;
  final String title;
  final String? body;
  final String channelId;
  final String channelName;
  final DateTime at;
  final bool repeatsDaily;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.payload == payload &&
      other.title == title &&
      other.body == body &&
      other.at == at &&
      other.repeatsDaily == repeatsDaily;

  @override
  int get hashCode => Object.hash(id, payload, title, body, at, repeatsDaily);
}

/// Payload prefixes owned by this reconciler. Anything else (e.g. goal
/// reminders) is never touched.
const _ownedPrefixes = ['habit:', 'lockin:', 'todo:', 'date_mention:'];

bool _isOwned(String? payload) =>
    payload != null && _ownedPrefixes.any(payload.startsWith);

// ── Scheduler seam (fakeable in tests) ───────────────────────────────────────

abstract interface class NotificationScheduler {
  Future<void> init();

  /// Currently scheduled notifications as (id, payload).
  Future<List<({int id, String? payload})>> pending();
  Future<void> schedule(PlannedNotification n);
  Future<void> cancel(int id);
}

class FlutterNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> init() async {
    await initNotifications();
    await _ensureChannels();
  }

  @override
  Future<List<({int id, String? payload})>> pending() async {
    final reqs = await _plugin.pendingNotificationRequests();
    return [for (final r in reqs) (id: r.id, payload: r.payload)];
  }

  @override
  Future<void> schedule(PlannedNotification n) {
    return _plugin.zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      scheduledDate: tz.TZDateTime.from(n.at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          n.channelId,
          n.channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: n.repeatsDaily ? DateTimeComponents.time : null,
      payload: n.payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

/// Android/iOS: OS-scheduled notifications. Windows/Linux: in-process timers
/// (see desktop_notification_scheduler.dart) — registered by the app at boot.
NotificationScheduler Function() defaultNotificationScheduler =
    FlutterNotificationScheduler.new;

// ── Inputs ───────────────────────────────────────────────────────────────────

/// A `@date` mention row, reduced to what the reconciler needs.
class DateMentionReminder {
  const DateMentionReminder({
    required this.key,
    required this.noteId,
    required this.startsAt,
    required this.allDay,
    required this.reminderOffset,
    this.noteTitle,
    this.isVault = false,
  });

  final String key;
  final String noteId;
  final DateTime startsAt;
  final bool allDay;

  /// One of: at_time, 10_min, 1_h, 1_day.
  final String reminderOffset;
  final String? noteTitle;
  final bool isVault;
}

abstract interface class DateMentionReminderSource {
  /// Mentions of non-deleted notes.
  Future<List<DateMentionReminder>> load();

  /// Emits whenever mentions (or their notes) change.
  Stream<void> changes();
}

/// User-facing notification settings (Settings → Notifications).
class ReconcilerSettings {
  const ReconcilerSettings({
    this.habits = true,
    this.todos = true,
    this.mentions = true,
    this.lockInNudge = true,
    this.defaultReminderMinutes = 540,
    this.nudgeMinutes = 20 * 60,
  });

  final bool habits;
  final bool todos;
  final bool mentions;
  final bool lockInNudge;
  final int defaultReminderMinutes;
  final int nudgeMinutes;

  static Future<ReconcilerSettings> fromPrefs() async {
    final p = await SharedPreferences.getInstance();
    return ReconcilerSettings(
      habits: p.getBool(AppIdentifiers.prefNotifHabits) ?? true,
      todos: p.getBool(AppIdentifiers.prefNotifTodos) ?? true,
      mentions: p.getBool(AppIdentifiers.prefNotifMentions) ?? true,
      lockInNudge: p.getBool(AppIdentifiers.prefNotifLockInNudge) ?? true,
      defaultReminderMinutes:
          p.getInt(AppIdentifiers.prefDefaultReminderMinutes) ?? 540,
    );
  }
}

// ── Reconciler ───────────────────────────────────────────────────────────────

class NotificationReconciler {
  NotificationReconciler({
    required this._habitRepo,
    required this._todoRepo,
    this._mentionSource,
    NotificationScheduler? scheduler,
    Future<ReconcilerSettings> Function()? settings,
    DateTime Function()? clock,
  }) : _scheduler = scheduler ?? defaultNotificationScheduler(),
       _settings = settings ?? ReconcilerSettings.fromPrefs,
       _now = clock ?? DateTime.now;

  final HabitRepository _habitRepo;
  final TodoRepository _todoRepo;
  final DateMentionReminderSource? _mentionSource;
  final NotificationScheduler _scheduler;
  final Future<ReconcilerSettings> Function() _settings;
  final DateTime Function() _now;

  bool _running = false;
  bool _again = false;

  static int idFor(String type, String id) =>
      (type + id).hashCode.abs() % 2000000000;

  /// Entry point. Safe to call at any time and from anywhere; concurrent
  /// calls coalesce into one extra pass.
  Future<void> reconcile() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _reconcileOnce();
      } while (_again);
    } catch (_) {
      // Notifications are best-effort; never crash the app over them.
    } finally {
      _running = false;
    }
  }

  Future<void> _reconcileOnce() async {
    await _scheduler.init();
    final settings = await _settings();
    final expected = <int, PlannedNotification>{};
    for (final n in [
      if (settings.habits) ...await _habitReminders(),
      if (settings.lockInNudge) ...await _lockInNudge(settings),
      if (settings.todos) ...await _todoReminders(settings),
      if (settings.mentions) ...await _mentionReminders(settings),
    ]) {
      expected[n.id] = n;
    }

    // Cancel owned notifications that are no longer expected.
    for (final p in await _scheduler.pending()) {
      if (_isOwned(p.payload) && !expected.containsKey(p.id)) {
        await _scheduler.cancel(p.id);
      }
    }
    // (Re)schedule everything expected; same id replaces → no duplicates.
    for (final n in expected.values) {
      await _scheduler.schedule(n);
    }
  }

  /// Re-run [reconcile] whenever the underlying data changes. Debounced.
  /// Returns a cancel function.
  VoidCallback watch() {
    Timer? debounce;
    void kick([Object? _]) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 600), reconcile);
    }

    final subs = <StreamSubscription<dynamic>>[
      _habitRepo.watchAll().listen(kick, onError: (_) {}),
      _todoRepo.watchToday().listen(kick, onError: (_) {}),
      _todoRepo.watchUpcoming().listen(kick, onError: (_) {}),
      if (_mentionSource != null)
        _mentionSource.changes().listen(kick, onError: (_) {}),
    ];
    return () {
      debounce?.cancel();
      for (final s in subs) {
        unawaited(s.cancel());
      }
    };
  }

  // ── Expected-set builders ─────────────────────────────────────────────────

  Future<List<PlannedNotification>> _habitReminders() async {
    final habits = await _habitRepo.watchAll().first;
    final out = <PlannedNotification>[];
    for (final h in habits) {
      if (!h.isActive || h.reminderTime == null) continue;
      final parts = h.reminderTime!.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      out.add(
        PlannedNotification(
          id: idFor('habit', h.id),
          kind: NotificationKind.habit,
          payload: 'habit:${h.id}',
          title: h.name,
          body: 'Time to check in!',
          channelId: AppIdentifiers.channelHabitReminders,
          channelName: 'Habit Reminders',
          at: _nextOccurrence(hour, minute),
          repeatsDaily: true,
        ),
      );
    }
    return out;
  }

  Future<List<PlannedNotification>> _lockInNudge(
    ReconcilerSettings settings,
  ) async {
    final habits = await _habitRepo.watchAll().first;
    if (!habits.any((h) => h.isActive)) return const [];
    final today = LocalDate.fromDateTime(_now());
    final locked = await _habitRepo.watchDayLock(today).first;
    var at = _nextOccurrence(
      settings.nudgeMinutes ~/ 60,
      settings.nudgeMinutes % 60,
    );
    // Already locked in today → first nudge is tomorrow evening.
    if (locked != null && LocalDate.fromDateTime(at) == today) {
      at = at.add(const Duration(days: 1));
    }
    return [
      PlannedNotification(
        id: idFor('lockin', 'nudge'),
        kind: NotificationKind.lockInNudge,
        payload: 'lockin:today',
        title: 'Lock in your day',
        body: "Don't break your streak — finish today's habits.",
        channelId: AppIdentifiers.channelLockInNudge,
        channelName: 'Lock-In Nudge',
        at: at,
      ),
    ];
  }

  Future<List<PlannedNotification>> _todoReminders(
    ReconcilerSettings settings,
  ) async {
    final pending = [
      ...await _todoRepo.watchToday().first,
      ...await _todoRepo.watchUpcoming().first,
    ];
    final out = <PlannedNotification>[];
    final now = _now();
    for (final t in pending) {
      DateTime? at;
      if (t.reminderAt != null) {
        at = DateTime.tryParse(t.reminderAt!);
      } else if (t.dueDate != null) {
        final d = LocalDate.parse(t.dueDate!);
        var minutes = settings.defaultReminderMinutes;
        final dueTime = t.dueTime;
        if (dueTime != null) {
          final p = dueTime.split(':');
          final h = p.length == 2 ? int.tryParse(p[0]) : null;
          final m = p.length == 2 ? int.tryParse(p[1]) : null;
          if (h != null && m != null) minutes = h * 60 + m;
        }
        at = DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
      }
      if (at == null || !at.isAfter(now)) continue;
      out.add(
        PlannedNotification(
          id: idFor('todo', t.id),
          kind: NotificationKind.todo,
          payload: 'todo:${t.id}',
          title: t.title,
          body: 'Task reminder',
          channelId: AppIdentifiers.channelTodoReminders,
          channelName: 'Task Reminders',
          at: at,
        ),
      );
    }
    return out;
  }

  Future<List<PlannedNotification>> _mentionReminders(
    ReconcilerSettings settings,
  ) async {
    final source = _mentionSource;
    if (source == null) return const [];
    final now = _now();
    final out = <PlannedNotification>[];
    for (final m in await source.load()) {
      DateTime at;
      if (m.allDay) {
        at = DateTime(
          m.startsAt.year,
          m.startsAt.month,
          m.startsAt.day,
        ).add(Duration(minutes: settings.defaultReminderMinutes));
      } else {
        at = m.startsAt.subtract(switch (m.reminderOffset) {
          '10_min' => const Duration(minutes: 10),
          '1_h' => const Duration(hours: 1),
          '1_day' => const Duration(days: 1),
          _ => Duration.zero,
        });
      }
      if (!at.isAfter(now)) continue;
      out.add(
        PlannedNotification(
          id: idFor('date_mention', m.key),
          kind: NotificationKind.dateMention,
          payload: 'date_mention:${m.noteId}',
          // Vault notes: generic title, no body (§8.6).
          title: m.isVault ? 'Reminder' : (m.noteTitle ?? 'Note reminder'),
          body: m.isVault ? null : 'Note reminder',
          channelId: AppIdentifiers.channelNoteMentions,
          channelName: 'Note Reminders',
          at: at,
        ),
      );
    }
    return out;
  }

  DateTime _nextOccurrence(int hour, int minute) {
    final now = _now();
    var dt = DateTime(now.year, now.month, now.day, hour, minute);
    if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
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
      _ReconcilerNotifier.new,
    );
