// lib/core/platform/desktop_notification_scheduler.dart
// Spec §12.3 / Phase 8A–B: flutter_local_notifications cannot schedule on
// Windows/Linux, so desktop reminders are in-process timers that fire toast /
// libnotify notifications while the app (or its tray) is running.
//
// A process-wide singleton: it deliberately outlives the locked session so
// reminders still fire from the tray while no decrypted data is held. The
// schedule is mirrored to a small NON-SECRET `schedule.json` (times + generic
// texts only — never vault note titles) so tray mode can restore timers.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:streakin/core/notifications/notification_reconciler.dart';

class DesktopNotificationScheduler implements NotificationScheduler {
  DesktopNotificationScheduler._();
  static final DesktopNotificationScheduler instance =
      DesktopNotificationScheduler._();

  static bool get isDesktop => Platform.isWindows || Platform.isLinux;

  final Map<int, PlannedNotification> _planned = {};
  final Map<int, Timer> _timers = {};
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await initNotifications(); // sets up the shared plugin + tap routing
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) notificationTapPayload.value = r.payload;
        },
      );
    } catch (_) {}
    await _restoreFromDisk();
  }

  @override
  Future<List<({int id, String? payload})>> pending() async => [
    for (final n in _planned.values) (id: n.id, payload: n.payload),
  ];

  @override
  Future<void> schedule(PlannedNotification n) async {
    _planned[n.id] = n;
    _arm(n);
    await _persist();
  }

  @override
  Future<void> cancel(int id) async {
    _planned.remove(id);
    _timers.remove(id)?.cancel();
    await _persist();
  }

  void _arm(PlannedNotification n) {
    _timers.remove(n.id)?.cancel();
    final delay = n.at.difference(DateTime.now());
    // Dart timers handle long delays fine; clamp negatives to "now".
    _timers[n.id] = Timer(delay.isNegative ? Duration.zero : delay, () async {
      await _fire(n);
      if (n.repeatsDaily) {
        final next = PlannedNotification(
          id: n.id,
          kind: n.kind,
          payload: n.payload,
          title: n.title,
          body: n.body,
          channelId: n.channelId,
          channelName: n.channelName,
          at: n.at.add(const Duration(days: 1)),
          repeatsDaily: true,
        );
        _planned[n.id] = next;
        _arm(next);
      } else {
        _planned.remove(n.id);
        _timers.remove(n.id);
      }
      await _persist();
    });
  }

  Future<void> _fire(PlannedNotification n) async {
    try {
      await _plugin.show(
        id: n.id,
        title: n.title,
        body: n.body,
        notificationDetails: const NotificationDetails(
          linux: LinuxNotificationDetails(),
        ),
        payload: n.payload,
      );
    } catch (_) {}
  }

  // ── schedule.json (non-secret) ────────────────────────────────────────────

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'schedule.json'));
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      await f.writeAsString(
        jsonEncode([
          for (final n in _planned.values)
            {
              'id': n.id,
              'payload': n.payload, // opaque type:id
              'title': n.title,
              'body': n.body,
              'channel': n.channelId,
              'at': n.at.toIso8601String(),
              'daily': n.repeatsDaily,
            },
        ]),
      );
    } catch (_) {}
  }

  Future<void> _restoreFromDisk() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return;
      final list = jsonDecode(await f.readAsString()) as List<dynamic>;
      for (final raw in list.cast<Map<String, dynamic>>()) {
        final n = PlannedNotification(
          id: raw['id'] as int,
          kind: NotificationKind.todo,
          payload: raw['payload'] as String,
          title: raw['title'] as String,
          body: raw['body'] as String?,
          channelId: raw['channel'] as String,
          channelName: raw['channel'] as String,
          at: DateTime.parse(raw['at'] as String),
          repeatsDaily: raw['daily'] as bool? ?? false,
        );
        if (n.repeatsDaily || n.at.isAfter(DateTime.now())) {
          _planned[n.id] = n;
          _arm(n);
        }
      }
    } catch (_) {}
  }
}
