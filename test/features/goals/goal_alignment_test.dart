import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';
import 'package:streakin/features/habits/application/habit_completion_port_impl.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/habit_repository.dart';

// ── Stub HabitRepository ──────────────────────────────────────────────────────

class _StubHabitRepo implements HabitRepository {
  final List<Habit> habits;
  final Map<String, List<HabitLog>> logs; // habitId → logs

  _StubHabitRepo({required this.habits, required this.logs});

  @override
  Future<Habit?> getById(String id) async =>
      habits.cast<Habit?>().firstWhere((h) => h?.id == id, orElse: () => null);

  @override
  Stream<List<Habit>> watchAll() => Stream.value(habits);

  @override
  Stream<List<Habit>> watchActiveForDate(LocalDate date) =>
      Stream.value(habits.where((h) => h.isActive).toList());

  @override
  Future<void> save(Habit habit) async {}

  @override
  Future<void> archive(String id) async {}

  @override
  Future<void> softDelete(String id) async {}

  @override
  Stream<List<HabitLog>> watchLogs(String habitId, DateRange range) =>
      Stream.value([]);

  @override
  Future<HabitLog?> getLog(String habitId, LocalDate date) async => null;

  @override
  Future<void> saveLog(HabitLog log) async {}

  @override
  Future<void> deleteLog(String habitId, LocalDate date) async {}

  @override
  Stream<DayLock?> watchDayLock(LocalDate date) => Stream.value(null);

  @override
  Future<void> saveDayLock(DayLock lock) async {}

  @override
  Future<void> deleteDayLock(LocalDate date) async {}

  @override
  Future<Map<String, List<HabitLog>>> fetchLogsForHabits(
      List<String> habitIds, DateRange range) async {
    final result = <String, List<HabitLog>>{};
    for (final id in habitIds) {
      final all = logs[id] ?? [];
      result[id] = all
          .where((l) =>
              l.localDate >= range.start &&
              l.localDate <= range.end &&
              !l.isDeleted)
          .toList();
    }
    return result;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Habit _makeHabit(String id, {int mask = 127}) => Habit(
      id: id,
      name: id,
      iconIndex: 0,
      accentIndex: 0,
      scheduleMask: ScheduleMask(mask),
      startDate: LocalDate.parse('2030-01-01'),
      sortOrder: 0,
      restTokensPerWeek: 1,
      hlc: '0-0000-0000',
    );

HabitLog _log(String habitId, String date, HabitLogStatus status) => HabitLog(
      id: '$habitId-$date',
      habitId: habitId,
      localDate: LocalDate.parse(date),
      status: status,
      hlc: '0-0000-0000',
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('HabitCompletionPortImpl alignment', () {
    test('100% when all done', () async {
      final h = _makeHabit('h1');
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {
          'h1': [
            _log('h1', '2030-01-06', HabitLogStatus.done), // Mon
            _log('h1', '2030-01-07', HabitLogStatus.done), // Tue
          ]
        },
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1',
              from: LocalDate.parse('2030-01-06'),
              to: LocalDate.parse('2030-01-07'))
        ],
        through: LocalDate.parse('2030-01-07'),
        goalRestTokenPool: 0,
      );
      expect(stats.alignmentPct, 100);
      expect(stats.perfectDays, 2);
    });

    test('50% when half done', () async {
      final h = _makeHabit('h1');
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {
          'h1': [
            _log('h1', '2030-01-06', HabitLogStatus.done),
          ]
        },
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1',
              from: LocalDate.parse('2030-01-06'),
              to: LocalDate.parse('2030-01-07'))
        ],
        through: LocalDate.parse('2030-01-07'),
        goalRestTokenPool: 0,
      );
      expect(stats.alignmentPct, 50);
    });

    test('rest day neutral when tokens available', () async {
      final h = _makeHabit('h1');
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {
          'h1': [
            _log('h1', '2030-01-06', HabitLogStatus.done),
            _log('h1', '2030-01-07', HabitLogStatus.rest),
          ]
        },
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1',
              from: LocalDate.parse('2030-01-06'),
              to: LocalDate.parse('2030-01-07'))
        ],
        through: LocalDate.parse('2030-01-07'),
        goalRestTokenPool: 4, // tokens available → rest is neutral
      );
      // Only 1 scheduled (the done day), rest is excluded
      expect(stats.scheduled, 1);
      expect(stats.done, 1);
      expect(stats.alignmentPct, 100);
    });

    test('rest day counts as missed when tokens exhausted', () async {
      final h = _makeHabit('h1');
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {
          'h1': [
            _log('h1', '2030-01-06', HabitLogStatus.done),
            _log('h1', '2030-01-07', HabitLogStatus.rest),
          ]
        },
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1',
              from: LocalDate.parse('2030-01-06'),
              to: LocalDate.parse('2030-01-07'))
        ],
        through: LocalDate.parse('2030-01-07'),
        goalRestTokenPool: 0, // no tokens → rest counts as missed
      );
      expect(stats.scheduled, 2);
      expect(stats.done, 1);
      expect(stats.alignmentPct, 50);
    });

    test('no linked habits → null alignment', () async {
      final port = HabitCompletionPortImpl(
          _StubHabitRepo(habits: [], logs: {}));
      final stats = await port.closedDayStats(
        windows: [],
        through: LocalDate.parse('2030-01-07'),
        goalRestTokenPool: 4,
      );
      expect(stats.alignmentPct, isNull);
      expect(stats.scheduled, 0);
    });

    test('alignment pct always in [0,100]', () async {
      // Property: result is bounded
      final h = _makeHabit('h1');
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {'h1': []},
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1',
              from: LocalDate.parse('2030-01-06'),
              to: LocalDate.parse('2030-01-10'))
        ],
        through: LocalDate.parse('2030-01-10'),
        goalRestTokenPool: 0,
      );
      if (stats.alignmentPct != null) {
        expect(stats.alignmentPct!, inInclusiveRange(0, 100));
      }
    });

    test('weekday mask respected — scheduled only on mask days', () async {
      // mask = 0b0000001 = Monday only (bit 0)
      final h = _makeHabit('h1', mask: 1);
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {
          'h1': [
            _log('h1', '2030-01-07', HabitLogStatus.done), // Tuesday — not scheduled
            _log('h1', '2030-01-06', HabitLogStatus.done), // Monday — scheduled
          ]
        },
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1',
              from: LocalDate.parse('2030-01-06'),
              to: LocalDate.parse('2030-01-07'))
        ],
        through: LocalDate.parse('2030-01-07'),
        goalRestTokenPool: 0,
      );
      // Only Monday (2030-01-06) is scheduled
      expect(stats.scheduled, 1);
      expect(stats.done, 1);
    });

    test('link window respected — days outside window excluded', () async {
      final h = _makeHabit('h1');
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {
          'h1': [
            _log('h1', '2030-01-05', HabitLogStatus.done), // before window
            _log('h1', '2030-01-06', HabitLogStatus.done), // in window
            _log('h1', '2030-01-07', HabitLogStatus.done), // after window
          ]
        },
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1',
              from: LocalDate.parse('2030-01-06'),
              to: LocalDate.parse('2030-01-06')) // only one day
        ],
        through: LocalDate.parse('2030-01-07'),
        goalRestTokenPool: 0,
      );
      expect(stats.scheduled, 1);
      expect(stats.done, 1);
    });

    test('best streak computed correctly', () async {
      final h = _makeHabit('h1');
      final repo = _StubHabitRepo(
        habits: [h],
        logs: {
          'h1': [
            _log('h1', '2030-01-06', HabitLogStatus.done),
            _log('h1', '2030-01-07', HabitLogStatus.done),
            _log('h1', '2030-01-08', HabitLogStatus.done),
            // gap
            _log('h1', '2030-01-10', HabitLogStatus.done),
            _log('h1', '2030-01-11', HabitLogStatus.done),
          ]
        },
      );
      final port = HabitCompletionPortImpl(repo);
      final stats = await port.closedDayStats(
        windows: [
          HabitLinkWindow(
              habitId: 'h1', from: LocalDate.parse('2030-01-06'))
        ],
        through: LocalDate.parse('2030-01-11'),
        goalRestTokenPool: 0,
      );
      expect(stats.bestStreak, 3);
    });
  });
}
