// lib/features/sharing/data/sharing_store.dart
// Reads the records to export and applies imported records with the merge
// rules of Spec §10.4:
//   habits / habit_logs / todos / folders → last-writer-wins by HLC
//   tombstones (deletedAt)                → applied as soft-deletes
//   notes → one side changed: take it; both changed: newer stays canonical
//           and the older version becomes a "(conflict · device · date)" copy
//   streaks are never stored → re-derived from logs after merge
// Rows travel as JSON maps produced by Drift's generated toJson().

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/time/hlc.dart';

/// Compares two HLC strings; falls back to string order when unparsable.
int compareHlc(String? a, String? b) {
  if (a == b) return 0;
  if (a == null || a.isEmpty) return -1;
  if (b == null || b.isEmpty) return 1;
  try {
    return Hlc.parse(a).compareTo(Hlc.parse(b));
  } catch (_) {
    return a.compareTo(b);
  }
}

String? maxHlc(Iterable<String?> values) {
  String? best;
  for (final v in values) {
    if (v == null || v.isEmpty) continue;
    if (best == null || compareHlc(v, best) > 0) best = v;
  }
  return best;
}

/// Everything exported from this device (JSON rows per table).
class ExportRecords {
  ExportRecords(this.tables);
  final Map<String, List<Map<String, dynamic>>> tables;

  int get total => tables.values.fold(0, (a, l) => a + l.length);

  String toNdjson() {
    final b = StringBuffer();
    for (final e in tables.entries) {
      for (final row in e.value) {
        b.writeln(jsonEncode({'t': e.key, 'r': row}));
      }
    }
    return b.toString();
  }

  static ExportRecords fromNdjson(String ndjson) {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final line in const LineSplitter().convert(ndjson)) {
      if (line.trim().isEmpty) continue;
      final m = jsonDecode(line) as Map<String, dynamic>;
      out
          .putIfAbsent(m['t'] as String, () => [])
          .add((m['r'] as Map).cast<String, dynamic>());
    }
    return ExportRecords(out);
  }
}

/// Counts shown on the import preview screen. Nothing is written to compute it.
class ImportPreview {
  const ImportPreview({
    required this.newCount,
    required this.updatedCount,
    required this.conflictCount,
    required this.deletedCount,
    required this.schemaVer,
    required this.attachmentSizeBytes,
  });
  final int newCount;
  final int updatedCount;
  final int conflictCount;
  final int deletedCount;
  final int schemaVer;
  final int attachmentSizeBytes;
}

enum _Act { insert, update, conflictCopy, tombstone, skip }

class _Plan {
  _Plan(this.table, this.act, this.row, {this.local});
  final String table;
  final _Act act;
  final Map<String, dynamic> row;
  final dynamic local; // existing Drift row, when any
}

class SharingStore {
  SharingStore(this._db);
  final AppDatabase _db;

  static const hlcTables = [
    'habits',
    'habit_logs',
    'todos',
    'folders',
    'notes',
  ];

  // ── Export ────────────────────────────────────────────────────────────────

  /// Collects the rows to export. [sinceHlc] limits HLC-bearing tables to
  /// strictly newer records (delta). [includeVault] decides, per vault id,
  /// whether its notes may be exported (the vault must be unlocked).
  Future<ExportRecords> collect({
    String? sinceHlc,
    bool Function(String vaultId)? includeVault,
  }) async {
    bool newer(String hlc) => sinceHlc == null || compareHlc(hlc, sinceHlc) > 0;
    bool vaultOk(String? v) => v == null || (includeVault?.call(v) ?? false);

    final notes = (await _db.select(_db.notes).get())
        .where((n) => newer(n.hlc) && vaultOk(n.vaultId))
        .toList();
    final vaultIds = {
      for (final n in notes)
        if (n.vaultId != null) n.vaultId!,
    };
    final noteIds = {for (final n in notes) n.id};

    return ExportRecords({
      'habits': [
        for (final r in await _db.select(_db.habits).get())
          if (newer(r.hlc)) r.toJson(),
      ],
      'habit_logs': [
        for (final r in await _db.select(_db.habitLogs).get())
          if (newer(r.hlc)) r.toJson(),
      ],
      'day_locks': [
        for (final r in await _db.select(_db.dayLocks).get()) r.toJson(),
      ],
      'todos': [
        for (final r in await _db.select(_db.todos).get())
          if (newer(r.hlc)) r.toJson(),
      ],
      'folders': [
        for (final r in await _db.select(_db.folders).get())
          if (newer(r.hlc) && vaultOk(r.vaultId)) r.toJson(),
      ],
      'notes': [for (final n in notes) n.toJson()],
      'vaults': [
        for (final v in await _db.select(_db.vaults).get())
          if (vaultIds.contains(v.id)) v.toJson(),
      ],
      'attachments': [
        for (final a in await _db.select(_db.attachments).get())
          if (noteIds.contains(a.noteId)) a.toJson(),
      ],
    });
  }

  /// Newest HLC across the exported records (becomes `lastSentHlc`).
  static String? newestHlc(ExportRecords r) => maxHlc([
    for (final t in hlcTables)
      for (final row in r.tables[t] ?? const <Map<String, dynamic>>[])
        row['hlc'] as String?,
  ]);

  // ── Import ────────────────────────────────────────────────────────────────

  Future<List<_Plan>> _plan(
    ExportRecords incoming,
    String? lastCommonHlc,
  ) async {
    final plans = <_Plan>[];
    final t = incoming.tables;

    for (final row in t['habits'] ?? const <Map<String, dynamic>>[]) {
      final local = await (_db.select(
        _db.habits,
      )..where((x) => x.id.equals(row['id'] as String))).getSingleOrNull();
      plans.add(_lww('habits', row, local?.hlc, local));
    }
    for (final row in t['habit_logs'] ?? const <Map<String, dynamic>>[]) {
      final byId = await (_db.select(
        _db.habitLogs,
      )..where((x) => x.id.equals(row['id'] as String))).getSingleOrNull();
      final byDay =
          byId ??
          await (_db.select(_db.habitLogs)..where(
                (x) =>
                    x.habitId.equals(row['habitId'] as String) &
                    x.localDate.equals(row['localDate'] as String),
              ))
              .getSingleOrNull();
      plans.add(_lww('habit_logs', row, byDay?.hlc, byDay));
    }
    for (final row in t['todos'] ?? const <Map<String, dynamic>>[]) {
      final local = await (_db.select(
        _db.todos,
      )..where((x) => x.id.equals(row['id'] as String))).getSingleOrNull();
      plans.add(_lww('todos', row, local?.hlc, local));
    }
    for (final row in t['folders'] ?? const <Map<String, dynamic>>[]) {
      final local = await (_db.select(
        _db.folders,
      )..where((x) => x.id.equals(row['id'] as String))).getSingleOrNull();
      plans.add(_lww('folders', row, local?.hlc, local));
    }
    for (final row in t['notes'] ?? const <Map<String, dynamic>>[]) {
      final local = await (_db.select(
        _db.notes,
      )..where((x) => x.id.equals(row['id'] as String))).getSingleOrNull();
      if (local == null) {
        plans.add(_Plan('notes', _Act.insert, row));
        continue;
      }
      final cmp = compareHlc(row['hlc'] as String?, local.hlc);
      if (cmp == 0 || local.body == row['body']) {
        plans.add(_Plan('notes', _Act.skip, row, local: local));
        continue;
      }
      final incomingTomb = row['deletedAt'] != null;
      final bothChanged =
          lastCommonHlc != null &&
          compareHlc(local.hlc, lastCommonHlc) > 0 &&
          compareHlc(row['hlc'] as String?, lastCommonHlc) > 0 &&
          local.vaultId == null &&
          !incomingTomb &&
          local.deletedAt == null;
      if (bothChanged) {
        plans.add(_Plan('notes', _Act.conflictCopy, row, local: local));
      } else if (cmp > 0) {
        plans.add(
          _Plan(
            'notes',
            incomingTomb ? _Act.tombstone : _Act.update,
            row,
            local: local,
          ),
        );
      } else {
        plans.add(_Plan('notes', _Act.skip, row, local: local));
      }
    }
    for (final row in t['day_locks'] ?? const <Map<String, dynamic>>[]) {
      final local =
          await (_db.select(_db.dayLocks)
                ..where((x) => x.localDate.equals(row['localDate'] as String)))
              .getSingleOrNull();
      plans.add(
        _Plan('day_locks', local == null ? _Act.insert : _Act.skip, row),
      );
    }
    for (final row in t['vaults'] ?? const <Map<String, dynamic>>[]) {
      final local = await (_db.select(
        _db.vaults,
      )..where((x) => x.id.equals(row['id'] as String))).getSingleOrNull();
      plans.add(_Plan('vaults', local == null ? _Act.insert : _Act.skip, row));
    }
    for (final row in t['attachments'] ?? const <Map<String, dynamic>>[]) {
      final local = await (_db.select(
        _db.attachments,
      )..where((x) => x.id.equals(row['id'] as String))).getSingleOrNull();
      plans.add(
        _Plan('attachments', local == null ? _Act.insert : _Act.skip, row),
      );
    }
    return plans;
  }

  _Plan _lww(
    String table,
    Map<String, dynamic> row,
    String? localHlc,
    dynamic local,
  ) {
    if (local == null) return _Plan(table, _Act.insert, row);
    final cmp = compareHlc(row['hlc'] as String?, localHlc);
    if (cmp <= 0) return _Plan(table, _Act.skip, row, local: local);
    return _Plan(
      table,
      row['deletedAt'] != null ? _Act.tombstone : _Act.update,
      row,
      local: local,
    );
  }

  /// Dry run: counts only. Writes nothing.
  Future<ImportPreview> preview(
    ExportRecords incoming, {
    required int schemaVer,
    required int attachmentSizeBytes,
    String? lastCommonHlc,
  }) async {
    final plans = await _plan(incoming, lastCommonHlc);
    int c(bool Function(_Plan) f) => plans.where(f).length;
    return ImportPreview(
      newCount: c(
        (p) =>
            p.act == _Act.insert &&
            p.table != 'vaults' &&
            p.table != 'day_locks',
      ),
      updatedCount: c((p) => p.act == _Act.update),
      conflictCount: c((p) => p.act == _Act.conflictCopy),
      deletedCount: c((p) => p.act == _Act.tombstone),
      schemaVer: schemaVer,
      attachmentSizeBytes: attachmentSizeBytes,
    );
  }

  /// Applies the merge inside one transaction; any failure rolls everything
  /// back. Returns ids of notes written (callers rebuild derived rows).
  Future<Set<String>> apply(
    ExportRecords incoming, {
    String? lastCommonHlc,
    String senderName = 'other device',
    DateTime? now,
  }) async {
    final plans = await _plan(incoming, lastCommonHlc);
    final touchedNotes = <String>{};
    await _db.transaction(() async {
      for (final p in plans) {
        if (p.act == _Act.skip) continue;
        switch (p.table) {
          case 'habits':
            await _db
                .into(_db.habits)
                .insertOnConflictUpdate(Habit.fromJson(p.row));
          case 'habit_logs':
            final log = HabitLog.fromJson(p.row);
            final existing = p.local as HabitLog?;
            if (existing != null && existing.id != log.id) {
              await (_db.delete(
                _db.habitLogs,
              )..where((x) => x.id.equals(existing.id))).go();
            }
            await _db.into(_db.habitLogs).insertOnConflictUpdate(log);
          case 'todos':
            await _db
                .into(_db.todos)
                .insertOnConflictUpdate(Todo.fromJson(p.row));
          case 'folders':
            await _db
                .into(_db.folders)
                .insertOnConflictUpdate(Folder.fromJson(p.row));
          case 'day_locks':
            await _db
                .into(_db.dayLocks)
                .insertOnConflictUpdate(DayLock.fromJson(p.row));
          case 'vaults':
            await _db
                .into(_db.vaults)
                .insertOnConflictUpdate(Vault.fromJson(p.row));
          case 'attachments':
            await _db
                .into(_db.attachments)
                .insertOnConflictUpdate(Attachment.fromJson(p.row));
          case 'notes':
            final incomingNote = Note.fromJson(p.row);
            if (p.act == _Act.conflictCopy) {
              final local = p.local as Note;
              final incomingNewer = compareHlc(incomingNote.hlc, local.hlc) > 0;
              final older = incomingNewer ? local : incomingNote;
              final newer = incomingNewer ? incomingNote : local;
              final day = (now ?? DateTime.now()).toIso8601String().substring(
                0,
                10,
              );
              await _db.into(_db.notes).insertOnConflictUpdate(newer);
              await _db
                  .into(_db.notes)
                  .insert(
                    older.copyWith(
                      id: const Uuid().v4(),
                      title: '${older.title} (conflict · $senderName · $day)',
                      hlc: Hlc.now().toIso(),
                      isPinned: false,
                    ),
                  );
              touchedNotes.add(newer.id);
            } else {
              await _db.into(_db.notes).insertOnConflictUpdate(incomingNote);
              touchedNotes.add(incomingNote.id);
            }
        }
      }
    });
    return touchedNotes;
  }

  /// Manifest-level numbers for the preview screen.
  static Map<String, dynamic> manifestFor(
    ExportRecords r, {
    required int schemaVersion,
    required String deviceId,
    required String scope,
    String? sinceHlc,
    required List<Map<String, dynamic>> attachmentIndex,
  }) => {
    'format': 1,
    'schemaVer': schemaVersion,
    'deviceId': deviceId,
    'scope': scope,
    'sinceHlc': ?sinceHlc,
    'maxHlc': newestHlc(r),
    'counts': {for (final e in r.tables.entries) e.key: e.value.length},
    'attachments': attachmentIndex,
  };
}
