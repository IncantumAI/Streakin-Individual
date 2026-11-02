// lib/features/notes/editor/note_autosave_service.dart
// Debounced autosave for the note editor.
// Spec §4.4.2: "debounce 2s after last keystroke; save on navigate-away
// and on app background (paused lifecycle event)."

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';
import 'package:streakin/core/time/hlc.dart';

enum AutosaveState { idle, pending, saving, saved, error }

class NoteAutosaveService extends ChangeNotifier {
  NoteAutosaveService({
    required NoteRepository repository,
    required this._noteId,
    this._debounce = const Duration(seconds: 2),
  }) : _repo = repository;

  final NoteRepository _repo;
  final String _noteId;
  final Duration _debounce;

  Timer? _timer;
  AutosaveState _state = AutosaveState.idle;
  NoteDocument? _pendingDoc;
  String? _pendingTitle;
  bool _disposed = false;

  AutosaveState get state => _state;

  /// Called by the editor whenever content changes.
  void onContentChanged(NoteDocument doc, String title) {
    _pendingDoc = doc;
    _pendingTitle = title;
    _timer?.cancel();
    _setState(AutosaveState.pending);
    _timer = Timer(_debounce, _save);
  }

  /// Force an immediate save (on navigate-away or app pause).
  Future<void> saveNow() async {
    _timer?.cancel();
    if (_pendingDoc != null) await _save();
  }

  Future<void> _save() async {
    if (_disposed || _pendingDoc == null) return;
    final doc = _pendingDoc!;
    final title = _pendingTitle ?? '';
    _setState(AutosaveState.saving);
    try {
      final existing = await _repo.getById(_noteId);
      if (existing == null) return; // Note was deleted while editing.
      final updated = existing.copyWith(
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        body: doc.toJson(),
        updatedAt: DateTime.now(),
        hlc: Hlc.now().toIso(),
      );
      await _repo.saveNote(updated);
      _pendingDoc = null;
      _setState(AutosaveState.saved);
      // Reset to idle after a short display window.
      Future.delayed(const Duration(seconds: 2), () {
        if (!_disposed && _state == AutosaveState.saved) {
          _setState(AutosaveState.idle);
        }
      });
    } catch (_) {
      _setState(AutosaveState.error);
    }
  }

  void _setState(AutosaveState s) {
    if (_disposed || _state == s) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
