// lib/features/notes/application/note_source_status.dart
// Tells the to-do list whether the note/block a promoted task came from still
// exists, so it can show a "source removed" label (Spec FR-TD-4).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note_document.dart';

/// `true` when the source note was deleted or the linked block is gone.
final noteSourceRemovedProvider =
    StreamProvider.family<bool, ({String noteId, String blockId})>((ref, key) {
      final repo = ref.watch(noteRepositoryStateProvider);
      if (repo == null) return const Stream.empty();
      return repo.watchNote(key.noteId).map((note) {
        if (note == null || note.isDeleted) return true;
        final doc = NoteDocument.fromJson(note.body);
        return !doc.blocks.any((b) => b.id == key.blockId);
      });
    });
