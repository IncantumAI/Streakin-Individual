// lib/features/notes/application/vault_migration.dart
// Spec §4.4.7: moving notes into / out of a vault re-encrypts them (decrypt
// under the source key → write under the target key). Each note is a single
// transactional upsert in the repository, so a failure leaves the original
// row untouched.

import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/features/notes/domain/note_repository.dart';

class VaultMigrationService {
  VaultMigrationService(this._repo);
  final NoteRepository _repo;

  Future<void> moveNoteIntoVault(String noteId, String vaultId) async {
    final n = await _repo.getById(noteId); // plaintext (decrypted if needed)
    if (n == null) throw StateError('Note not found or its vault is locked');
    await _repo.saveNote(
      n.copyWith(
        vaultId: vaultId,
        updatedAt: DateTime.now().toUtc(),
        hlc: Hlc.now().toIso(),
      ),
    );
  }

  Future<void> moveNoteOutOfVault(String noteId) async {
    final n = await _repo.getById(noteId);
    if (n == null) throw StateError('Note not found or its vault is locked');
    await _repo.saveNote(
      n.copyWith(
        clearVaultId: true,
        updatedAt: DateTime.now().toUtc(),
        hlc: Hlc.now().toIso(),
      ),
    );
  }

  /// Converts [folderId] and everything below it into [vaultId]. Returns the
  /// number of notes re-encrypted. [onProgress] drives the progress UI.
  Future<int> convertFolderToVault(
    String folderId,
    String vaultId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final folders = await _repo.watchFolders().first;
    final subtree = <String>{folderId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final f in folders) {
        if (f.parentId != null &&
            subtree.contains(f.parentId) &&
            subtree.add(f.id)) {
          grew = true;
        }
      }
    }

    final noteIds = <String>[];
    for (final fid in subtree) {
      for (final n in await _repo.watchFolder(fid).first) {
        if (n.vaultId == null) noteIds.add(n.id);
      }
    }

    var done = 0;
    for (final id in noteIds) {
      await moveNoteIntoVault(id, vaultId);
      onProgress?.call(++done, noteIds.length);
    }
    for (final f in folders.where((f) => subtree.contains(f.id))) {
      await _repo.saveFolder(
        f.copyWith(vaultId: vaultId, hlc: Hlc.now().toIso()),
      );
    }
    return noteIds.length;
  }
}
