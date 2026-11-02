// lib/features/habits/domain/habit_repository.dart
// Repository interface — domain layer only, no Flutter/Drift imports.

import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/domain/habit.dart';

abstract interface class HabitRepository {
  Stream<List<Habit>> watchAll();
  Stream<List<Habit>> watchActiveForDate(LocalDate date);
  Future<Habit?> getById(String id);
  Future<void> save(Habit habit);
  Future<void> archive(String id);
  Future<void> softDelete(String id);

  Stream<List<HabitLog>> watchLogs(String habitId, DateRange range);
  Future<HabitLog?> getLog(String habitId, LocalDate date);
  Future<void> saveLog(HabitLog log);
  Future<void> deleteLog(String habitId, LocalDate date);

  Stream<DayLock?> watchDayLock(LocalDate date);
  Future<void> saveDayLock(DayLock lock);
  Future<void> deleteDayLock(LocalDate date);

  /// All logs for a list of habits in a date range (bulk fetch for streak engine).
  Future<Map<String, List<HabitLog>>> fetchLogsForHabits(
    List<String> habitIds,
    DateRange range,
  );

  /// Watch all logs for a specific date across all habits (reactive, for Today view).
  Stream<List<HabitLog>> watchLogsForDate(LocalDate date);
}
