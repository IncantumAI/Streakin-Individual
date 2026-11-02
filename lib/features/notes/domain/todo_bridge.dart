// lib/features/notes/domain/todo_bridge.dart
// TodoBridge interface — implemented in Phase 4 (To-do module).
// Notes module calls this to promote/demote checkboxes as tasks.
// Stub in Phase 3; wired in Phase 4.

abstract interface class TodoBridge {
  /// Promote a checkbox block in a note to a full To-do task.
  Future<void> promoteCheckbox(String noteId, String blockId, String title);

  /// Remove the To-do task link from a checkbox (keep checkbox, drop task).
  Future<void> demoteCheckbox(String noteId, String blockId);

  /// Set the done state of the task linked to a checkbox (same use-case as
  /// ticking the task in the to-do list).
  Future<void> setCheckboxDone(String noteId, String blockId, bool done);

  /// Watch whether a checkbox is currently backed by a complete To-do task.
  Stream<bool> watchCheckboxState(String noteId, String blockId);
}
