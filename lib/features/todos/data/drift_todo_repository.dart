// lib/features/todos/data/drift_todo_repository.dart
// DriftTodoRepository implements TodoRepository via TodoDao.

import 'package:streakin/features/todos/data/todo_dao.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';

class DriftTodoRepository implements TodoRepository {
  const DriftTodoRepository(this._dao);
  final TodoDao _dao;

  @override
  Stream<List<Todo>> watchToday() => _dao.watchToday();

  @override
  Stream<List<Todo>> watchUpcoming() => _dao.watchUpcoming();

  @override
  Stream<List<Todo>> watchAnytime() => _dao.watchAnytime();

  @override
  Stream<List<Todo>> watchDone() => _dao.watchDone();

  @override
  Future<void> save(Todo todo) => _dao.save(todo);

  @override
  Future<void> complete(String id) => _dao.complete(id);

  @override
  Future<void> uncomplete(String id) => _dao.uncomplete(id);

  @override
  Future<void> softDelete(String id) => _dao.softDelete(id);

  @override
  Stream<Todo?> watchBySourceBlock(String noteId, String blockId) =>
      _dao.watchBySourceBlock(noteId, blockId);

  @override
  Future<Todo?> getById(String id) => _dao.getById(id);
}
