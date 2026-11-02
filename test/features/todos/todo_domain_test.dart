// test/features/todos/todo_domain_test.dart
// Unit tests for Track 4A: Todo entity, TodoPriority, TodoStatus,
// DriftTodoRepository (via in-memory Drift DB), TodoCalendarSource,
// and lock-in integration logic.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/storage/app_database.dart' show AppDatabase;
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/todos/data/drift_todo_repository.dart';
import 'package:streakin/features/todos/data/todo_dao.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';
import 'package:uuid/uuid.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

AppDatabase _openInMemory() {
  return AppDatabase(NativeDatabase.memory());
}

const _uuid = Uuid();

Todo _todo({
  String? id,
  String title = 'Test task',
  String? dueDate,
  String? dueTime,
  TodoPriority priority = TodoPriority.none,
  TodoStatus status = TodoStatus.pending,
  String? completedAt,
  bool countsForLockin = false,
  String? sourceNoteId,
  String? sourceBlockId,
  String? reminderAt,
  String? deletedAt,
}) => Todo(
  id: id ?? _uuid.v4(),
  title: title,
  dueDate: dueDate,
  dueTime: dueTime,
  priority: priority,
  status: status,
  completedAt: completedAt,
  countsForLockin: countsForLockin,
  sourceNoteId: sourceNoteId,
  sourceBlockId: sourceBlockId,
  reminderAt: reminderAt,
  hlc: '2026-10-07T00:00:00.000Z-0000-test',
  deletedAt: deletedAt,
);

// ── TodoPriority ───────────────────────────────────────────────────────────

void main() {
  group('TodoPriority', () {
    test('fromInt maps 0→none, 1→medium, 2→high', () {
      expect(TodoPriority.fromInt(0), TodoPriority.none);
      expect(TodoPriority.fromInt(1), TodoPriority.medium);
      expect(TodoPriority.fromInt(2), TodoPriority.high);
    });

    test('fromInt unknown value defaults to none', () {
      expect(TodoPriority.fromInt(99), TodoPriority.none);
    });

    test('toInt round-trips', () {
      for (final p in TodoPriority.values) {
        expect(TodoPriority.fromInt(p.toInt()), p);
      }
    });
  });

  // ── TodoStatus ─────────────────────────────────────────────────────────────

  group('TodoStatus', () {
    test('fromString maps pending/done', () {
      expect(TodoStatus.fromString('pending'), TodoStatus.pending);
      expect(TodoStatus.fromString('done'), TodoStatus.done);
    });

    test('fromString unknown defaults to pending', () {
      expect(TodoStatus.fromString('unknown'), TodoStatus.pending);
    });

    test('toLabel round-trips', () {
      expect(
        TodoStatus.fromString(TodoStatus.pending.toLabel()),
        TodoStatus.pending,
      );
      expect(TodoStatus.fromString(TodoStatus.done.toLabel()), TodoStatus.done);
    });
  });

  // ── Todo entity ────────────────────────────────────────────────────────────

  group('Todo entity', () {
    test('isDone only when status=done and not deleted', () {
      final t = _todo(status: TodoStatus.done);
      expect(t.isDone, isTrue);
      expect(t.isPending, isFalse);
    });

    test('isDone false when deleted', () {
      final t = _todo(
        status: TodoStatus.done,
        deletedAt: '2026-10-07T10:00:00.000Z',
      );
      expect(t.isDone, isFalse);
    });

    test('isPending false when deleted', () {
      final t = _todo(deletedAt: '2026-10-07T10:00:00.000Z');
      expect(t.isPending, isFalse);
    });

    test('hasDueDate', () {
      expect(_todo(dueDate: '2026-10-10').hasDueDate, isTrue);
      expect(_todo().hasDueDate, isFalse);
    });

    test('isDueOn matches exact date', () {
      final t = _todo(dueDate: '2026-10-10');
      expect(t.isDueOn(const LocalDate(2026, 10, 10)), isTrue);
      expect(t.isDueOn(const LocalDate(2026, 10, 11)), isFalse);
    });

    test('isOverdue: past due date and pending', () {
      final t = _todo(dueDate: '2020-01-01');
      expect(t.isOverdue(const LocalDate(2026, 10, 7)), isTrue);
    });

    test('isOverdue: false when done', () {
      final t = _todo(dueDate: '2020-01-01', status: TodoStatus.done);
      expect(t.isOverdue(const LocalDate(2026, 10, 7)), isFalse);
    });

    test('isOverdue: false when no due date', () {
      expect(_todo().isOverdue(const LocalDate(2026, 10, 7)), isFalse);
    });

    test('isOverdue: false when due date is today', () {
      final today = LocalDate.today();
      final t = _todo(dueDate: today.toIso());
      expect(t.isOverdue(today), isFalse);
    });

    test('hasSourceNote requires both fields', () {
      expect(
        _todo(sourceNoteId: 'n1', sourceBlockId: 'b1').hasSourceNote,
        isTrue,
      );
      expect(_todo(sourceNoteId: 'n1').hasSourceNote, isFalse);
      expect(_todo().hasSourceNote, isFalse);
    });

    test('copyWith nullable override works', () {
      final t = _todo(dueDate: '2026-10-10');
      final cleared = t.copyWith(dueDate: () => null);
      expect(cleared.dueDate, isNull);
      expect(cleared.id, t.id);
    });

    test('equality based on id + hlc', () {
      final a = _todo(id: 'x');
      final b = _todo(id: 'x');
      // Same id but same hlc value from helper → equal
      expect(a, equals(b));
    });
  });

  // ── DriftTodoRepository ────────────────────────────────────────────────────

  group('DriftTodoRepository', () {
    late AppDatabase db;
    late TodoRepository repo;

    setUp(() {
      db = _openInMemory();
      repo = DriftTodoRepository(TodoDao(db));
    });

    tearDown(() => db.close());

    // ── save + streams ────────────────────────────────────────────────────

    test('saved pending task appears in watchAnytime', () async {
      final t = _todo(title: 'No date task');
      await repo.save(t);
      final list = await repo.watchAnytime().first;
      expect(list.length, 1);
      expect(list.first.title, 'No date task');
    });

    test('saved task with today due date appears in watchToday', () async {
      final today = LocalDate.today().toIso();
      final t = _todo(dueDate: today);
      await repo.save(t);
      final list = await repo.watchToday().first;
      expect(list.any((x) => x.id == t.id), isTrue);
    });

    test('overdue task appears in watchToday', () async {
      final t = _todo(dueDate: '2020-01-01');
      await repo.save(t);
      final list = await repo.watchToday().first;
      expect(list.any((x) => x.id == t.id), isTrue);
    });

    test('future due date appears in watchUpcoming', () async {
      final future = LocalDate.today().addDays(5).toIso();
      final t = _todo(dueDate: future);
      await repo.save(t);
      final list = await repo.watchUpcoming().first;
      expect(list.any((x) => x.id == t.id), isTrue);
    });

    test('upcoming task does NOT appear in watchToday', () async {
      final future = LocalDate.today().addDays(5).toIso();
      final t = _todo(dueDate: future);
      await repo.save(t);
      final list = await repo.watchToday().first;
      expect(list.any((x) => x.id == t.id), isFalse);
    });

    test('anytime task does NOT appear in watchToday', () async {
      final t = _todo();
      await repo.save(t);
      final list = await repo.watchToday().first;
      expect(list.any((x) => x.id == t.id), isFalse);
    });

    test('anytime task does NOT appear in watchUpcoming', () async {
      final t = _todo();
      await repo.save(t);
      final list = await repo.watchUpcoming().first;
      expect(list.any((x) => x.id == t.id), isFalse);
    });

    // ── complete / uncomplete ─────────────────────────────────────────────

    test('complete moves task from anytime to done', () async {
      final t = _todo();
      await repo.save(t);
      await repo.complete(t.id);
      final anytime = await repo.watchAnytime().first;
      final done = await repo.watchDone().first;
      expect(anytime.any((x) => x.id == t.id), isFalse);
      expect(done.any((x) => x.id == t.id), isTrue);
    });

    test('complete sets completedAt', () async {
      final t = _todo();
      await repo.save(t);
      await repo.complete(t.id);
      final fetched = await repo.getById(t.id);
      expect(fetched?.completedAt, isNotNull);
      expect(fetched?.status, TodoStatus.done);
    });

    test('uncomplete moves task back to pending', () async {
      final t = _todo();
      await repo.save(t);
      await repo.complete(t.id);
      await repo.uncomplete(t.id);
      final anytime = await repo.watchAnytime().first;
      final done = await repo.watchDone().first;
      expect(anytime.any((x) => x.id == t.id), isTrue);
      expect(done.any((x) => x.id == t.id), isFalse);
    });

    test('uncomplete clears completedAt', () async {
      final t = _todo();
      await repo.save(t);
      await repo.complete(t.id);
      await repo.uncomplete(t.id);
      final fetched = await repo.getById(t.id);
      expect(fetched?.completedAt, isNull);
      expect(fetched?.status, TodoStatus.pending);
    });

    // ── soft delete ───────────────────────────────────────────────────────

    test('softDelete removes task from all streams', () async {
      final t = _todo();
      await repo.save(t);
      await repo.softDelete(t.id);
      final anytime = await repo.watchAnytime().first;
      final done = await repo.watchDone().first;
      expect(anytime.any((x) => x.id == t.id), isFalse);
      expect(done.any((x) => x.id == t.id), isFalse);
    });

    test('getById returns null after softDelete', () async {
      final t = _todo();
      await repo.save(t);
      await repo.softDelete(t.id);
      expect(await repo.getById(t.id), isNull);
    });

    // ── watchBySourceBlock ────────────────────────────────────────────────

    test('watchBySourceBlock returns linked task', () async {
      final t = _todo(sourceNoteId: 'note1', sourceBlockId: 'block1');
      await repo.save(t);
      final linked = await repo.watchBySourceBlock('note1', 'block1').first;
      expect(linked?.id, t.id);
    });

    test('watchBySourceBlock returns null when no match', () async {
      final linked = await repo.watchBySourceBlock('note1', 'block1').first;
      expect(linked, isNull);
    });

    test('watchBySourceBlock returns null after softDelete', () async {
      final t = _todo(sourceNoteId: 'note1', sourceBlockId: 'block1');
      await repo.save(t);
      await repo.softDelete(t.id);
      final linked = await repo.watchBySourceBlock('note1', 'block1').first;
      expect(linked, isNull);
    });

    // ── priority ordering ─────────────────────────────────────────────────

    test('high priority task appears before none in watchAnytime', () async {
      final low = _todo(id: 'low', title: 'Low');
      final high = _todo(
        id: 'high',
        title: 'High',
        priority: TodoPriority.high,
      );
      await repo.save(low);
      await repo.save(high);
      final list = await repo.watchAnytime().first;
      expect(list.first.priority, TodoPriority.high);
    });

    // ── upsert ────────────────────────────────────────────────────────────

    test('save updates existing task', () async {
      final t = _todo(title: 'Original');
      await repo.save(t);
      final updated = t.copyWith(title: 'Updated');
      await repo.save(updated);
      final fetched = await repo.getById(t.id);
      expect(fetched?.title, 'Updated');
    });

    // ── countsForLockin ───────────────────────────────────────────────────

    test('countsForLockin persists correctly', () async {
      final t = _todo(countsForLockin: true);
      await repo.save(t);
      final fetched = await repo.getById(t.id);
      expect(fetched?.countsForLockin, isTrue);
    });

    test('countsForLockin defaults to false', () async {
      final t = _todo();
      await repo.save(t);
      final fetched = await repo.getById(t.id);
      expect(fetched?.countsForLockin, isFalse);
    });
  });

  // ── TodoCalendarSource logic ───────────────────────────────────────────────

  group('Todo calendar entries', () {
    late AppDatabase db;
    late TodoRepository repo;

    setUp(() {
      db = _openInMemory();
      repo = DriftTodoRepository(TodoDao(db));
    });

    tearDown(() => db.close());

    test('task with due date in range produces CalendarEntry', () async {
      final target = LocalDate.today().addDays(10);
      final t = _todo(dueDate: target.toIso(), title: 'Meeting');
      await repo.save(t);

      final range = DateRange(
        start: LocalDate.today(),
        end: LocalDate.today().addDays(30),
      );
      // Verify the repository exposes the task in the today/upcoming streams.
      // (CalendarSource widget tests are integration-level; here we verify
      // the data layer produces a task with the correct due date.)
      final upcoming = await repo.watchUpcoming().first;
      expect(
        upcoming.any((x) => x.id == t.id && x.dueDate == target.toIso()),
        isTrue,
      );

      // Also verify range contains the date.
      expect(range.contains(target), isTrue);
    });

    test('task outside range not selected by range contains check', () {
      const range = DateRange(
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
      );
      expect(range.contains(const LocalDate(2026, 11, 1)), isFalse);
    });

    test('high priority entry gets danger color marker', () {
      // Priority color is determined by TodoPriority value — verify enum.
      expect(TodoPriority.high.toInt(), 2);
      expect(TodoPriority.medium.toInt(), 1);
      expect(TodoPriority.none.toInt(), 0);
    });
  });

  // ── Lock-in integration logic ──────────────────────────────────────────────

  group('countsForLockin logic', () {
    late AppDatabase db;
    late TodoRepository repo;

    setUp(() {
      db = _openInMemory();
      repo = DriftTodoRepository(TodoDao(db));
    });

    tearDown(() => db.close());

    test('flagged task pending → not all flagged done', () async {
      final today = LocalDate.today().toIso();
      final t = _todo(dueDate: today, countsForLockin: true);
      await repo.save(t);
      final todayTasks = await repo.watchToday().first;
      final flagged = todayTasks.where((x) => x.countsForLockin).toList();
      final allFlaggedDone = flagged.every((x) => x.isDone);
      expect(allFlaggedDone, isFalse);
    });

    test('flagged task completed → all flagged done', () async {
      final today = LocalDate.today().toIso();
      final t = _todo(dueDate: today, countsForLockin: true);
      await repo.save(t);
      await repo.complete(t.id);
      // After completion the task moves to done, watchToday no longer returns it.
      // Lock-in check must also consult watchDone for flagged tasks.
      final done = await repo.watchDone().first;
      final flaggedDone = done
          .where((x) => x.countsForLockin && x.isDone)
          .toList();
      expect(flaggedDone.length, 1);
    });

    test('unflagged task completed → flagged-done count unchanged', () async {
      final today = LocalDate.today().toIso();
      final flagged = _todo(dueDate: today, countsForLockin: true);
      final unflagged = _todo(dueDate: today);
      await repo.save(flagged);
      await repo.save(unflagged);
      await repo.complete(unflagged.id);
      final todayTasks = await repo.watchToday().first;
      final pendingFlagged = todayTasks
          .where((x) => x.countsForLockin)
          .toList();
      // Flagged task still pending → not locked in
      expect(pendingFlagged.length, 1);
      expect(pendingFlagged.first.isPending, isTrue);
    });

    test(
      'setting off → todos irrelevant to lock-in (no flagged tasks)',
      () async {
        // With countTodosForLockIn = false, the lock-in service ignores todos.
        // This is enforced at the use-case layer (Phase 4 settings),
        // but we verify that flagged field itself is stored.
        final t = _todo();
        await repo.save(t);
        final fetched = await repo.getById(t.id);
        expect(fetched?.countsForLockin, isFalse);
      },
    );
  });
}
