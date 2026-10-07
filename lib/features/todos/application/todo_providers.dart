// lib/features/todos/application/todo_providers.dart
// Riverpod providers for the todos feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';

// ── Repository state (set by SessionScope after DB opens) ─────────────────

class _TodoRepositoryNotifier extends Notifier<TodoRepository?> {
  @override
  TodoRepository? build() => null;

  void set(TodoRepository repo) => state = repo;
  void clear() => state = null;
}

final todoRepositoryStateProvider =
    NotifierProvider<_TodoRepositoryNotifier, TodoRepository?>(
        _TodoRepositoryNotifier.new);

/// Convenience provider — throws clearly if SessionScope has not yet set it.
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final repo = ref.watch(todoRepositoryStateProvider);
  if (repo == null) {
    throw UnimplementedError(
        'todoRepositoryProvider must be set in SessionScope');
  }
  return repo;
});

// ── Streams ───────────────────────────────────────────────────────────────

final todosTodayProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchToday();
});

final todosUpcomingProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchUpcoming();
});

final todosAnytimeProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchAnytime();
});

final todosDoneProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchDone();
});

// ── Use-cases ─────────────────────────────────────────────────────────────

final todoUseCasesProvider = Provider(TodoUseCases.new);

class TodoUseCases {
  TodoUseCases(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();

  TodoRepository get _repo => _ref.read(todoRepositoryProvider);

  Future<void> addTodo({
    required String title,
    String? dueDate,
    String? dueTime,
    TodoPriority priority = TodoPriority.none,
    bool countsForLockin = false,
    String? reminderAt,
  }) async {
    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      dueDate: dueDate,
      dueTime: dueTime,
      priority: priority,
      status: TodoStatus.pending,
      countsForLockin: countsForLockin,
      reminderAt: reminderAt,
      hlc: Hlc.now().toIso(),
    );
    await _repo.save(todo);
  }

  Future<void> updateTodo(Todo updated) async {
    await _repo.save(updated.copyWith(hlc: Hlc.now().toIso()));
  }

  Future<void> completeTodo(String id) async {
    await _repo.complete(id);
  }

  Future<void> uncompleteTodo(String id) async {
    await _repo.uncomplete(id);
  }

  Future<void> deleteTodo(String id) async {
    await _repo.softDelete(id);
  }
}
