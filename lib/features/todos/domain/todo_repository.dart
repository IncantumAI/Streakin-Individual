// lib/features/todos/domain/todo_repository.dart
// Spec §4.3: TodoRepository interface.
// No Drift/Flutter imports — domain layer stays pure.

import 'package:streakin/features/todos/domain/todo.dart';

abstract interface class TodoRepository {
  /// Tasks due today or overdue (pending only).
  Stream<List<Todo>> watchToday();

  /// Tasks with a future due date (pending only).
  Stream<List<Todo>> watchUpcoming();

  /// Tasks with no due date (pending only).
  Stream<List<Todo>> watchAnytime();

  /// Completed tasks (not deleted), most recently completed first.
  Stream<List<Todo>> watchDone();

  /// Upsert a task.
  Future<void> save(Todo todo);

  /// Mark task as done, recording [completedAt] timestamp.
  Future<void> complete(String id);

  /// Reverse a completion (sets status back to pending, clears completedAt).
  Future<void> uncomplete(String id);

  /// Soft-delete: sets [deletedAt], removes from all streams.
  Future<void> softDelete(String id);

  /// Watch the task linked to a specific note checkbox block.
  /// Emits null when no linked task exists.
  Stream<Todo?> watchBySourceBlock(String noteId, String blockId);

  /// Fetch a single task by id (null if not found or deleted).
  Future<Todo?> getById(String id);
}
