// lib/features/notes/data/drift_date_mention_source.dart
// Feeds `@date` mentions to the NotificationReconciler. Rows of deleted notes
// are excluded by the DAO join, so deleting a note (or a chip) removes the
// mention from the expected set and the reconciler cancels its notification.

import 'package:streakin/core/notifications/notification_reconciler.dart';
import 'package:streakin/features/notes/data/note_dao.dart';

class DriftDateMentionSource implements DateMentionReminderSource {
  DriftDateMentionSource(this._dao);
  final NoteDao _dao;

  @override
  Future<List<DateMentionReminder>> load() async {
    final rows = await _dao.watchActiveMentions().first;
    final out = <DateMentionReminder>[];
    for (final r in rows) {
      final m = r.mention;
      final at = DateTime.tryParse(m.startsAt);
      if (at == null) continue;
      out.add(
        DateMentionReminder(
          key: m.notifId ?? m.id,
          noteId: m.noteId,
          startsAt: at,
          allDay: m.allDay,
          reminderOffset: m.reminderOffset,
          noteTitle: r.title.isEmpty ? null : r.title,
          isVault: m.vaultId != null,
        ),
      );
    }
    return out;
  }

  @override
  Stream<void> changes() => _dao.watchActiveMentions();
}
