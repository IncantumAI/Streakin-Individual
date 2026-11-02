// Spec §12.1/§12.2 — reconcile() with a fake scheduler.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:streakin/core/notifications/notification_reconciler.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';

class _MockHabitRepo extends Mock implements HabitRepository {}

class _MockTodoRepo extends Mock implements TodoRepository {}

class _FakeScheduler implements NotificationScheduler {
  final Map<int, PlannedNotification> scheduled = {};
  final Map<int, String?> foreign = {};

  @override
  Future<void> init() async {}

  @override
  Future<List<({int id, String? payload})>> pending() async => [
    for (final n in scheduled.values) (id: n.id, payload: n.payload),
    for (final e in foreign.entries) (id: e.key, payload: e.value),
  ];

  @override
  Future<void> schedule(PlannedNotification n) async => scheduled[n.id] = n;

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    foreign.remove(id);
  }
}

class _FakeMentions implements DateMentionReminderSource {
  List<DateMentionReminder> rows = [];
  @override
  Future<List<DateMentionReminder>> load() async => rows;
  @override
  Stream<void> changes() => const Stream.empty();
}

Habit _habit(String id, {String? reminder = '08:00', bool archived = false}) =>
    Habit(
      id: id,
      name: 'Habit $id',
      iconIndex: 0,
      accentIndex: 0,
      scheduleMask: ScheduleMask.every,
      reminderTime: reminder,
      startDate: const LocalDate(2026, 1, 1),
      archivedAt: archived ? const LocalDate(2026, 6, 1) : null,
      sortOrder: 0,
      restTokensPerWeek: 1,
      hlc: 'h',
    );

Todo _todo(String id, {String? reminderAt, String? dueDate}) => Todo(
  id: id,
  title: 'Todo $id',
  priority: TodoPriority.none,
  status: TodoStatus.pending,
  countsForLockin: false,
  reminderAt: reminderAt,
  dueDate: dueDate,
  hlc: 'h',
);

void main() {
  setUpAll(() => registerFallbackValue(const LocalDate(2026, 1, 1)));

  late _MockHabitRepo habits;
  late _MockTodoRepo todos;
  late _FakeScheduler scheduler;
  late _FakeMentions mentions;
  late List<Habit> habitRows;
  late List<Todo> todayRows;
  late List<Todo> upcomingRows;
  var settings = const ReconcilerSettings();
  final now = DateTime(2026, 10, 1, 12);

  NotificationReconciler make() => NotificationReconciler(
    habitRepo: habits,
    todoRepo: todos,
    mentionSource: mentions,
    scheduler: scheduler,
    settings: () async => settings,
    clock: () => now,
  );

  setUp(() {
    habits = _MockHabitRepo();
    todos = _MockTodoRepo();
    scheduler = _FakeScheduler();
    mentions = _FakeMentions();
    habitRows = [];
    todayRows = [];
    upcomingRows = [];
    settings = const ReconcilerSettings();
    when(() => habits.watchAll()).thenAnswer((_) => Stream.value(habitRows));
    when(() => habits.watchDayLock(any()))
        .thenAnswer((_) => Stream.value(null));
    when(() => todos.watchToday()).thenAnswer((_) => Stream.value(todayRows));
    when(() => todos.watchUpcoming())
        .thenAnswer((_) => Stream.value(upcomingRows));
  });

  Set<String> payloads() =>
      scheduler.scheduled.values.map((n) => n.payload).toSet();

  test('habit added → notification scheduled; archived → cancelled', () async {
    habitRows = [_habit('a')];
    await make().reconcile();
    expect(payloads(), contains('habit:a'));

    habitRows = [_habit('a', archived: true)];
    await make().reconcile();
    expect(payloads(), isNot(contains('habit:a')));
  });

  test('todo with reminderAt scheduled; completed → cancelled', () async {
    upcomingRows = [_todo('t', reminderAt: '2026-10-02T09:00:00')];
    await make().reconcile();
    expect(payloads(), contains('todo:t'));

    upcomingRows = [];
    await make().reconcile();
    expect(payloads(), isNot(contains('todo:t')));
  });

  test('todo with only a due date uses the default reminder time', () async {
    upcomingRows = [_todo('d', dueDate: '2026-10-03')];
    await make().reconcile();
    final n = scheduler.scheduled.values.single;
    expect(n.at, DateTime(2026, 10, 3, 9));
  });

  test('date-mention chip deleted → notification cancelled', () async {
    mentions.rows = [
      DateMentionReminder(
        key: 'k',
        noteId: 'n1',
        startsAt: DateTime(2026, 10, 2, 17),
        allDay: false,
        reminderOffset: 'at_time',
        noteTitle: 'Plan',
      ),
    ];
    await make().reconcile();
    expect(payloads(), contains('date_mention:n1'));

    mentions.rows = [];
    await make().reconcile();
    expect(payloads(), isNot(contains('date_mention:n1')));
  });

  test('vault mention uses generic title and no body', () async {
    mentions.rows = [
      DateMentionReminder(
        key: 'v',
        noteId: 'vn',
        startsAt: DateTime(2026, 10, 2, 17),
        allDay: false,
        reminderOffset: 'at_time',
        noteTitle: 'Secret plans',
        isVault: true,
      ),
    ];
    await make().reconcile();
    final n = scheduler.scheduled.values.single;
    expect(n.title, 'Reminder');
    expect(n.body, isNull);
  });

  test('lock-in nudge scheduled when habits exist', () async {
    habitRows = [_habit('a', reminder: null)];
    await make().reconcile();
    expect(payloads(), contains('lockin:today'));
  });

  test('per-type toggles disable notifications', () async {
    habitRows = [_habit('a')];
    upcomingRows = [_todo('t', reminderAt: '2026-10-02T09:00:00')];
    settings = const ReconcilerSettings(habits: false, lockInNudge: false);
    await make().reconcile();
    expect(payloads(), {'todo:t'});
  });

  test(
    'idempotent: running twice yields the same set, no duplicates',
    () async {
      habitRows = [_habit('a'), _habit('b')];
      upcomingRows = [_todo('t', reminderAt: '2026-10-02T09:00:00')];
      final r = make();
      await r.reconcile();
      final first = Map.of(scheduler.scheduled);
      await r.reconcile();
      expect(scheduler.scheduled, first);
    },
  );

  test('after reboot (empty scheduler) everything is restored', () async {
    habitRows = [_habit('a')];
    upcomingRows = [_todo('t', reminderAt: '2026-10-02T09:00:00')];
    await make().reconcile();
    final before = Map.of(scheduler.scheduled);
    scheduler.scheduled.clear();
    await make().reconcile();
    expect(scheduler.scheduled, before);
  });

  test('never cancels notifications it does not own', () async {
    scheduler.foreign[42] = 'goal:countdown';
    await make().reconcile();
    expect(scheduler.foreign.containsKey(42), isTrue);
  });
}
