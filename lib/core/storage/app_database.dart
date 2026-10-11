// lib/core/storage/app_database.dart — fixed applyWorkaround + removed slow IO warning.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:streakin/core/crypto/hkdf.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/storage/identifiers.dart';

part 'app_database.g.dart';

// ── Tables ─────────────────────────────────────────────────────────────────

class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get iconIndex => integer().withDefault(const Constant(0))();
  IntColumn get accentIndex => integer().withDefault(const Constant(0))();
  IntColumn get scheduleMask => integer().withDefault(const Constant(127))();
  TextColumn get reminderTime => text().nullable()();
  TextColumn get startDate => text()();
  TextColumn get archivedAt => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get restTokensPerWeek => integer().withDefault(const Constant(0))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get localDate => text()();
  TextColumn get status => text()();
  TextColumn get note => text().nullable()();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['UNIQUE (habit_id, local_date)'];
}

class DayLocks extends Table {
  TextColumn get localDate => text()();
  TextColumn get lockedAt => text()();
  @override
  Set<Column> get primaryKey => {localDate};
}

class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get dueDate => text().nullable()();
  TextColumn get dueTime => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get completedAt => text().nullable()();
  BoolColumn get countsForLockin => boolean().withDefault(const Constant(false))();
  TextColumn get sourceNoteId => text().nullable()();
  TextColumn get sourceBlockId => text().nullable()();
  TextColumn get reminderAt => text().nullable()();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get iconIndex => integer().withDefault(const Constant(0))();
  IntColumn get accentIndex => integer().withDefault(const Constant(0))();
  TextColumn get vaultId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get templateKind => text().withDefault(const Constant('blank'))();
  TextColumn get body => text().withDefault(const Constant('{}'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get vaultId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class NoteLinks extends Table {
  TextColumn get srcNoteId => text()();
  TextColumn get dstNoteId => text()();
  TextColumn get blockId => text()();
  @override
  Set<Column> get primaryKey => {srcNoteId, dstNoteId, blockId};
}

class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tag => text()();
  @override
  Set<Column> get primaryKey => {noteId, tag};
}

class DateMentions extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get blockId => text()();
  TextColumn get startsAt => text()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get reminderOffset => text().withDefault(const Constant('at_time'))();
  TextColumn get notifId => text().nullable()();
  TextColumn get vaultId => text().nullable()();
  TextColumn get genericLabel => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get kind => text()();
  TextColumn get mime => text()();
  IntColumn get size => integer()();
  TextColumn get sha256 => text()();
  TextColumn get storageName => text()();
  TextColumn get createdAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class NoteEmbeddings extends Table {
  TextColumn get noteId => text()();
  IntColumn get chunkIdx => integer()();
  BlobColumn get vector => blob()();
  TextColumn get modelVer => text()();
  @override
  Set<Column> get primaryKey => {noteId, chunkIdx};
}

class Vaults extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kdfParams => text()();
  TextColumn get wrappedVaultKey => text()();
  TextColumn get wrappedVaultKeyRecovery => text().nullable()();
  IntColumn get autoLockSeconds => integer().withDefault(const Constant(120))();
  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get why => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('dated'))(); // 'dated'|'open'
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active'|'archived'
  TextColumn get archiveReason => text().nullable()(); // 'completed'|'completed_early'|'replaced'|'abandoned'
  TextColumn get archivedAt => text().nullable()();
  TextColumn get activatedHlc => text()();
  IntColumn get accentIndex => integer().withDefault(const Constant(0))();
  IntColumn get restTokenPool => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class GoalHabits extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(Goals, #id)();
  TextColumn get habitId => text()();
  TextColumn get linkedFrom => text()();
  TextColumn get linkedTo => text().nullable()();
  TextColumn get hlc => text()();
  TextColumn get deletedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class GoalSummaries extends Table {
  TextColumn get goalId => text().references(Goals, #id)();
  TextColumn get computedThrough => text()();
  IntColumn get totalDays => integer()();
  IntColumn get elapsedDays => integer()();
  IntColumn get alignmentPct => integer().nullable()();
  IntColumn get perfectDays => integer()();
  IntColumn get bestStreak => integer()();
  TextColumn get perHabit => text().withDefault(const Constant('{}'))(); // JSON
  TextColumn get milestones => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get hlc => text()();
  @override
  Set<Column> get primaryKey => {goalId};
}

class GoalLocalState extends Table {
  TextColumn get goalId => text().references(Goals, #id)();
  BoolColumn get celebrationPending => boolean().withDefault(const Constant(false))();
  TextColumn get milestonesShown => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get heroPromptDismissedUntil => text().nullable()();
  @override
  Set<Column> get primaryKey => {goalId};
}

class SyncPeers extends Table {
  TextColumn get deviceId => text()();
  TextColumn get name => text()();
  TextColumn get publicKey => text()();
  TextColumn get pairedAt => text()();
  TextColumn get lastSentHlc => text().nullable()();
  TextColumn get lastRecvHlc => text().nullable()();
  @override
  Set<Column> get primaryKey => {deviceId};
}

// ── Database ────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Habits, HabitLogs, DayLocks, Todos, Folders, Notes,
  NoteLinks, NoteTags, DateMentions, Attachments,
  NoteEmbeddings, Vaults, SyncPeers,
  Goals, GoalHabits, GoalSummaries, GoalLocalState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFtsTable();
          await _createGoalIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await _createFtsTable();
          if (from < 3) {
            await m.createTable(goals);
            await m.createTable(goalHabits);
            await m.createTable(goalSummaries);
            await m.createTable(goalLocalState);
            await _createGoalIndexes();
          }
        },
        beforeOpen: (details) async {
          await _createFtsTable();
          await _createGoalIndexes();
        },
      );

  Future<void> _createFtsTable() async {
    try {
      await customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS note_fts '
        "USING fts5(title, plain_text, content=notes, content_rowid=rowid)",
      );
    } catch (_) {
      // Non-fatal — FTS search will be unavailable but core functionality
      // (create/save notes) will still work.
    }
  }

  Future<void> _createGoalIndexes() async {
    try {
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS one_active_goal ON goals(status) '
        "WHERE status = 'active' AND deleted_at IS NULL",
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS one_open_link ON goal_habits(goal_id, habit_id) '
        'WHERE linked_to IS NULL AND deleted_at IS NULL',
      );
    } catch (_) {}
  }
}

// ── Opener ──────────────────────────────────────────────────────────────────

Future<AppDatabase> openAppDatabase(List<int> dek) async {
  // Derive DB key on the main isolate using pure-Dart HKDF (no platform channel).
  // Must complete before NativeDatabase is created — the setup callback runs
  // synchronously where platform channels are unavailable.
  final dekBytes = dek is Uint8List ? dek : Uint8List.fromList(dek);
  final dbKey = await HkdfDerive.deriveDbKey(dekBytes);
  final hexKey = SecureBytes.toHex(dbKey);
  SecureBytes.zeroFill(dbKey);

  final dir = await getApplicationSupportDirectory();
  final dbFile = File(p.join(dir.path, AppIdentifiers.dbFileName));

  // NativeDatabase (not createInBackground): runs on calling isolate,
  // so SQLCipher native libs are available and no isolate spawn needed.
  return AppDatabase(
    NativeDatabase(
      dbFile,
      setup: (db) {
        db.execute("PRAGMA key = \"x'$hexKey'\"");
        db.execute('PRAGMA cipher_memory_security = ON');
        db.execute('PRAGMA secure_delete = ON');
        db.execute('PRAGMA foreign_keys = ON');
        db.execute('PRAGMA journal_mode = WAL');
      },
    ),
  );
}

/// Apply the SQLCipher workaround on Android and register SQLCipher as the
/// sqlite3 library. Call once at app startup before runApp.
Future<void> initSqlCipherOnAndroid() async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    // Override all sqlite3 opens to use libsqlcipher.so instead of libsqlite3.so.
    open.overrideForAll(openCipherOnAndroid);
  }
}

/// Open the database with a pre-derived hex key (64-char hex string).
/// Use this when HKDF has already been run on the main isolate.
/// initSqlCipherOnAndroid() must have been called first on Android.
Future<AppDatabase> openAppDatabaseWithKey(String hexKey) async {
  final dir = await getApplicationSupportDirectory();
  final dbFile = File(p.join(dir.path, AppIdentifiers.dbFileName));
  return AppDatabase(
    NativeDatabase(
      dbFile,
      setup: (db) {
        db.execute("PRAGMA key = \"x'$hexKey'\"");
        db.execute('PRAGMA cipher_memory_security = ON');
        db.execute('PRAGMA secure_delete = ON');
        db.execute('PRAGMA foreign_keys = ON');
        db.execute('PRAGMA journal_mode = WAL');
      },
    ),
  );
}

Future<bool> isDbEncrypted() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, AppIdentifiers.dbFileName));
  if (!file.existsSync()) return true;
  final bytes = file.openSync().readSync(15);
  final header = String.fromCharCodes(bytes);
  return !header.startsWith('SQLite format');
}
