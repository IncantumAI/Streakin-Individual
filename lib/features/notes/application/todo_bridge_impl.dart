// lib/features/notes/application/todo_bridge_impl.dart
// Implements TodoBridge — the single integration point between the notes
// editor and the to-do list.
//
// Contract:
//   • promoteCheckbox  → creates a Todo with sourceNoteId/sourceBlockId,
//                        writes linkedTodoId into the NoteBlock attrs,
//                        saves the note.
//   • demoteCheckbox   → soft-deletes the linked Todo,
//                        removes linkedTodoId from the NoteBlock attrs,
//                        saves the note.
//   • watchCheckboxState → watches todos.status for the linked task;
//                          emits true when done, false otherwise.
//
// Single source of truth is always the `todos` row.
// The note body carries only the linkedTodoId reference — never duplicates
// the task state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';
import 'package:streakin/features/notes/domain/todo_bridge.dart';
import 'package:streakin/features/todos/application/todo_providers.dart';
import 'package:streakin/features/todos/domain/todo.dart';
import 'package:streakin/features/todos/domain/todo_repository.dart';

class TodoBridgeImpl implements TodoBridge {
  TodoBridgeImpl({
    required this._noteRepo,
    required this._todoRepo,
  });

  final NoteRepository _noteRepo;
  final TodoRepository _todoRepo;

  static const _uuid = Uuid();

  // ── promoteCheckbox ─────────────────────────────────────────────────────

  @override
  Future<void> promoteCheckbox(
      String noteId, String blockId, String title) async {
    // 1. Check not already linked.
    final existing =
        await _todoRepo.watchBySourceBlock(noteId, blockId).first;
    if (existing != null) return; // already promoted

    // 2. Create the Todo.
    final todoId = _uuid.v4();
    final todo = Todo(
      id: todoId,
      title: title,
      priority: TodoPriority.none,
      status: TodoStatus.pending,
      countsForLockin: false,
      sourceNoteId: noteId,
      sourceBlockId: blockId,
      hlc: Hlc.now().toIso(),
    );
    await _todoRepo.save(todo);

    // 3. Write linkedTodoId into the block attrs and persist.
    await _updateBlockAttrs(noteId, blockId, {'linkedTodoId': todoId});
  }

  // ── demoteCheckbox ──────────────────────────────────────────────────────

  @override
  Future<void> demoteCheckbox(String noteId, String blockId) async {
    // 1. Find linked task.
    final todo = await _todoRepo.watchBySourceBlock(noteId, blockId).first;
    if (todo != null) {
      await _todoRepo.softDelete(todo.id);
    }

    // 2. Remove linkedTodoId from block attrs.
    await _updateBlockAttrs(noteId, blockId, {});
  }

  // ── watchCheckboxState ──────────────────────────────────────────────────

  @override
  Stream<bool> watchCheckboxState(String noteId, String blockId) {
    return _todoRepo
        .watchBySourceBlock(noteId, blockId)
        .map((todo) => todo?.isDone ?? false);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Load the note body, update the target block's attrs, save back.
  Future<void> _updateBlockAttrs(
      String noteId, String blockId, Map<String, dynamic> newAttrs) async {
    final note = await _noteRepo.watchNote(noteId).first;
    if (note == null || note.isDeleted) return;

    final doc = NoteDocument.fromJson(note.body);
    final updatedBlocks = doc.blocks.map((b) {
      if (b.id != blockId) return b;
      return b.copyWith(attrs: newAttrs);
    }).toList();

    final updatedDoc = NoteDocument(updatedBlocks);
    await _noteRepo.saveNote(
      note.copyWith(
        body: updatedDoc.toJson(),
        updatedAt: DateTime.now().toUtc(),
        hlc: Hlc.now().toIso(),
      ),
    );
  }
}

// ── Provider ────────────────────────────────────────────────────────────────

class _TodoBridgeNotifier extends Notifier<TodoBridge?> {
  @override
  TodoBridge? build() => null;
  void set(TodoBridge bridge) => state = bridge;
  void clear() => state = null;
}

final todoBridgeStateProvider =
    NotifierProvider<_TodoBridgeNotifier, TodoBridge?>(
        _TodoBridgeNotifier.new);

final todoBridgeProvider = Provider<TodoBridge>((ref) {
  final bridge = ref.watch(todoBridgeStateProvider);
  if (bridge == null) {
    throw StateError(
        'todoBridgeProvider: SessionScope has not set the bridge yet.');
  }
  return bridge;
});
