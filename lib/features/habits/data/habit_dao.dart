// lib/features/habits/data/habit_dao.dart
// Drift DAO. Domain entity imports are aliased to avoid name clash
// with Drift-generated data classes (Habit, HabitLog, DayLock).

import 'package:drift/drift.dart';
import 'package:streakin/core/storage/app_database.dart';
import 'package:streakin/core/time/hlc.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart' as domain;
import 'package:uuid/uuid.dart';

part 'habit_dao.g.dart';

@DriftAccessor(tables: [Habits, HabitLogs, DayLocks])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);

  static const _uuid = Uuid();

  // ── Habits ────────────────────────────────────────────────────────────────

  Stream<List<domain.Habit>> watchAll() {
    return (select(habits)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_habitFromRow).toList());
  }

  Stream<List<domain.Habit>> watchActiveForDate(LocalDate date) {
    final iso = date.toIso();
    return (select(habits)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.archivedAt.isNull() &
              t.startDate.isSmallerOrEqualValue(iso))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows
            .map(_habitFromRow)
            .where((h) => h.scheduleMask.isScheduled(date))
            .toList());
  }

  Future<domain.Habit?> getById(String id) async {
    final row = await (select(habits)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _habitFromRow(row);
  }

  Future<void> save(domain.Habit habit) async {
    await into(habits).insertOnConflictUpdate(HabitsCompanion(
      id: Value(habit.id),
      name: Value(habit.name),
      iconIndex: Value(habit.iconIndex),
      accentIndex: Value(habit.accentIndex),
      scheduleMask: Value(habit.scheduleMask.value),
      reminderTime: Value(habit.reminderTime),
      startDate: Value(habit.startDate.toIso()),
      archivedAt: Value(habit.archivedAt?.toIso()),
      sortOrder: Value(habit.sortOrder),
      restTokensPerWeek: Value(habit.restTokensPerWeek),
      hlc: Value(habit.hlc),
      deletedAt: Value(habit.deletedAt?.toIso()),
    ));
  }

  Future<void> archive(String id) async {
    final now = LocalDate.today().toIso();
    await (update(habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(archivedAt: Value(now), hlc: Value(Hlc.now().toIso())));
  }

  Future<void> softDelete(String id) async {
    final now = LocalDate.today().toIso();
    await (update(habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(deletedAt: Value(now), hlc: Value(Hlc.now().toIso())));
  }

  // ── Habit Logs ────────────────────────────────────────────────────────────

  Stream<List<domain.HabitLog>> watchLogs(String habitId, DateRange range) {
    return (select(habitLogs)
          ..where((t) =>
              t.habitId.equals(habitId) &
              t.localDate.isBiggerOrEqualValue(range.start.toIso()) &
              t.localDate.isSmallerOrEqualValue(range.end.toIso()) &
              t.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(_logFromRow).toList());
  }

  Future<domain.HabitLog?> getLog(String habitId, LocalDate date) async {
    final row = await (select(habitLogs)
          ..where((t) =>
              t.habitId.equals(habitId) & t.localDate.equals(date.toIso())))
        .getSingleOrNull();
    return row == null ? null : _logFromRow(row);
  }

  Future<void> saveLog(domain.HabitLog log) async {
    await into(habitLogs).insertOnConflictUpdate(HabitLogsCompanion(
      id: Value(log.id),
      habitId: Value(log.habitId),
      localDate: Value(log.localDate.toIso()),
      status: Value(log.status.name),
      note: Value(log.note),
      hlc: Value(log.hlc),
      deletedAt: Value(log.deletedAt?.toIso()),
    ));
  }

  Future<void> deleteLog(String habitId, LocalDate date) async {
    final now = LocalDate.today().toIso();
    await (update(habitLogs)
          ..where((t) =>
              t.habitId.equals(habitId) & t.localDate.equals(date.toIso())))
        .write(HabitLogsCompanion(
            deletedAt: Value(now), hlc: Value(Hlc.now().toIso())));
  }

  Future<Map<String, List<domain.HabitLog>>> fetchLogsForHabits(
      List<String> habitIds, DateRange range) async {
    final rows = await (select(habitLogs)
          ..where((t) =>
              t.habitId.isIn(habitIds) &
              t.localDate.isBiggerOrEqualValue(range.start.toIso()) &
              t.localDate.isSmallerOrEqualValue(range.end.toIso()) &
              t.deletedAt.isNull()))
        .get();
    final map = <String, List<domain.HabitLog>>{};
    for (final row in rows) {
      final log = _logFromRow(row);
      map.putIfAbsent(log.habitId, () => []).add(log);
    }
    return map;
  }

  // ── Day Locks ─────────────────────────────────────────────────────────────

  Stream<domain.DayLock?> watchDayLock(LocalDate date) {
    return (select(dayLocks)
          ..where((t) => t.localDate.equals(date.toIso())))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _dayLockFromRow(row));
  }

  Future<void> saveDayLock(domain.DayLock lock) async {
    await into(dayLocks).insertOnConflictUpdate(DayLocksCompanion(
      localDate: Value(lock.localDate.toIso()),
      lockedAt: Value(lock.lockedAt.toIso8601String()),
    ));
  }

  Future<void> deleteDayLock(LocalDate date) async {
    await (delete(dayLocks)..where((t) => t.localDate.equals(date.toIso())))
        .go();
  }

  // ── Mappers ───────────────────────────────────────────────────────────────
  // Drift generates data classes named Habit, HabitLog, DayLock matching
  // the table class names. We use them here directly (via app_database import).

  static domain.Habit _habitFromRow(Habit row) => domain.Habit(
        id: row.id,
        name: row.name,
        iconIndex: row.iconIndex,
        accentIndex: row.accentIndex,
        scheduleMask: domain.ScheduleMask(row.scheduleMask),
        reminderTime: row.reminderTime,
        startDate: LocalDate.parse(row.startDate),
        archivedAt:
            row.archivedAt != null ? LocalDate.parse(row.archivedAt!) : null,
        sortOrder: row.sortOrder,
        restTokensPerWeek: row.restTokensPerWeek,
        hlc: row.hlc,
        deletedAt:
            row.deletedAt != null ? LocalDate.parse(row.deletedAt!) : null,
      );

  static domain.HabitLog _logFromRow(HabitLog row) => domain.HabitLog(
        id: row.id,
        habitId: row.habitId,
        localDate: LocalDate.parse(row.localDate),
        status: domain.HabitLogStatus.values
            .firstWhere((s) => s.name == row.status),
        note: row.note,
        hlc: row.hlc,
        deletedAt:
            row.deletedAt != null ? LocalDate.parse(row.deletedAt!) : null,
      );

  static domain.DayLock _dayLockFromRow(DayLock row) => domain.DayLock(
        localDate: LocalDate.parse(row.localDate),
        lockedAt: DateTime.parse(row.lockedAt),
      );

  static String newId() => _uuid.v4();
}
