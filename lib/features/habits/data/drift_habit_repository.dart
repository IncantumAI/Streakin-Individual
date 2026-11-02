// lib/features/habits/data/drift_habit_repository.dart
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';
import 'package:streakin/features/habits/data/habit_dao.dart';

class DriftHabitRepository implements HabitRepository {
  DriftHabitRepository(this._dao);
  final HabitDao _dao;

  @override
  Stream<List<Habit>> watchAll() => _dao.watchAll();
  @override
  Stream<List<Habit>> watchActiveForDate(LocalDate date) =>
      _dao.watchActiveForDate(date);
  @override
  Future<Habit?> getById(String id) => _dao.getById(id);
  @override
  Future<void> save(Habit habit) => _dao.save(habit);
  @override
  Future<void> archive(String id) => _dao.archive(id);
  @override
  Future<void> softDelete(String id) => _dao.softDelete(id);
  @override
  Stream<List<HabitLog>> watchLogs(String habitId, DateRange range) =>
      _dao.watchLogs(habitId, range);
  @override
  Stream<List<HabitLog>> watchLogsForDate(LocalDate date) =>
      _dao.watchLogsForDate(date);
  @override
  Future<HabitLog?> getLog(String habitId, LocalDate date) =>
      _dao.getLog(habitId, date);
  @override
  Future<void> saveLog(HabitLog log) => _dao.saveLog(log);
  @override
  Future<void> deleteLog(String habitId, LocalDate date) =>
      _dao.deleteLog(habitId, date);
  @override
  Stream<DayLock?> watchDayLock(LocalDate date) => _dao.watchDayLock(date);
  @override
  Future<void> saveDayLock(DayLock lock) => _dao.saveDayLock(lock);
  @override
  Future<void> deleteDayLock(LocalDate date) => _dao.deleteDayLock(date);
  @override
  Future<Map<String, List<HabitLog>>> fetchLogsForHabits(
    List<String> habitIds,
    DateRange range,
  ) => _dao.fetchLogsForHabits(habitIds, range);
}
