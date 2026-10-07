// lib/features/todos/data/todo_dao.dart
// Drift DAO for the todos table.

import 'package:drift/drift.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/todos/domain/todo.dart' as domain;
import 'package:uuid/uuid.dart';

part 'todo_dao.g.dart';

@DriftAccessor(tables: [Todos])
class TodoDao extends DatabaseAccessor<AppDatabase> with _$TodoDaoMixin {
  TodoDao(super.db);

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();

  // ── Today / overdue ───────────────────────────────────────────────────────

  Stream<List<domain.Todo>> watchToday() {
    final today = LocalDate.today().toIso();
    return (select(todos)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.status.equals('pending') &
              t.dueDate.isNotNull() &
              t.dueDate.isSmallerOrEqualValue(today))
          ..orderBy([
            (t) => OrderingTerm.asc(t.dueDate),
            (t) => OrderingTerm.desc(t.priority),
          ]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  // ── Upcoming ──────────────────────────────────────────────────────────────

  Stream<List<domain.Todo>> watchUpcoming() {
    final today = LocalDate.today().toIso();
    return (select(todos)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.status.equals('pending') &
              t.dueDate.isNotNull() &
              t.dueDate.isBiggerThanValue(today))
          ..orderBy([
            (t) => OrderingTerm.asc(t.dueDate),
            (t) => OrderingTerm.desc(t.priority),
          ]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  // ── Anytime ───────────────────────────────────────────────────────────────

  Stream<List<domain.Todo>> watchAnytime() {
    return (select(todos)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.status.equals('pending') &
              t.dueDate.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.hlc),
          ]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  // ── Done ──────────────────────────────────────────────────────────────────

  Stream<List<domain.Todo>> watchDone() {
    return (select(todos)
          ..where((t) =>
              t.deletedAt.isNull() & t.status.equals('done'))
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  // ── Upsert ────────────────────────────────────────────────────────────────

  Future<void> save(domain.Todo todo) async {
    await into(todos).insertOnConflictUpdate(TodosCompanion(
      id: Value(todo.id),
      title: Value(todo.title),
      dueDate: Value(todo.dueDate),
      dueTime: Value(todo.dueTime),
      priority: Value(todo.priority.toInt()),
      status: Value(todo.status.toLabel()),
      completedAt: Value(todo.completedAt),
      countsForLockin: Value(todo.countsForLockin),
      sourceNoteId: Value(todo.sourceNoteId),
      sourceBlockId: Value(todo.sourceBlockId),
      reminderAt: Value(todo.reminderAt),
      hlc: Value(todo.hlc),
      deletedAt: Value(todo.deletedAt),
    ));
  }

  // ── Complete / uncomplete ─────────────────────────────────────────────────

  Future<void> complete(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        status: const Value('done'),
        completedAt: Value(now),
        hlc: Value(Hlc.now().toIso()),
      ),
    );
  }

  Future<void> uncomplete(String id) async {
    await (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        status: const Value('pending'),
        completedAt: const Value(null),
        hlc: Value(Hlc.now().toIso()),
      ),
    );
  }

  // ── Soft delete ───────────────────────────────────────────────────────────

  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        deletedAt: Value(now),
        hlc: Value(Hlc.now().toIso()),
      ),
    );
  }

  // ── Source-block watch ────────────────────────────────────────────────────

  Stream<domain.Todo?> watchBySourceBlock(String noteId, String blockId) {
    return (select(todos)
          ..where((t) =>
              t.sourceNoteId.equals(noteId) &
              t.sourceBlockId.equals(blockId) &
              t.deletedAt.isNull()))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  // ── By id ─────────────────────────────────────────────────────────────────

  Future<domain.Todo?> getById(String id) async {
    final row = await (select(todos)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  // ── Calendar range query ──────────────────────────────────────────────────

  /// All non-deleted tasks with a due date inside [start..end] (inclusive).
  Future<List<domain.Todo>> fetchByDateRange(
      LocalDate start, LocalDate end) async {
    final rows = await (select(todos)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.dueDate.isNotNull() &
              t.dueDate.isBiggerOrEqualValue(start.toIso()) &
              t.dueDate.isSmallerOrEqualValue(end.toIso())))
        .get();
    return rows.map(_fromRow).toList();
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  // Drift generates a data class named `Todo` (matching table class `Todos`).
  // We alias the domain class to `domain.Todo` to avoid the name clash.
  static domain.Todo _fromRow(Todo row) => domain.Todo(
        id: row.id,
        title: row.title,
        dueDate: row.dueDate,
        dueTime: row.dueTime,
        priority: domain.TodoPriority.fromInt(row.priority),
        status: domain.TodoStatus.fromString(row.status),
        completedAt: row.completedAt,
        countsForLockin: row.countsForLockin,
        sourceNoteId: row.sourceNoteId,
        sourceBlockId: row.sourceBlockId,
        reminderAt: row.reminderAt,
        hlc: row.hlc,
        deletedAt: row.deletedAt,
      );
}
