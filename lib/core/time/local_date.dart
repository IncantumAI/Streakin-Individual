// lib/core/time/local_date.dart
//
// A calendar-date value type (yyyy-MM-dd) that never stores UTC offsets.
// Spec §4.2: "All dates are local calendar dates (yyyy-MM-dd), never UTC
// instants, so travel and DST cannot shift a completion to another day."

import 'package:flutter/foundation.dart';

/// An immutable local calendar date (year, month, day).
/// No timezone information is stored.
@immutable
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12),
      assert(day >= 1 && day <= 31);

  final int year;
  final int month;
  final int day;

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Create from the local time of [dateTime]. The time-of-day is ignored.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  /// Create from an ISO yyyy-MM-dd string.
  factory LocalDate.parse(String s) {
    final parts = s.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid LocalDate string: $s');
    }
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Today, using the device local clock (no day-boundary offset here;
  /// apply offset at the call site if needed).
  static LocalDate today() => LocalDate.fromDateTime(DateTime.now());

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Returns the ISO yyyy-MM-dd string used as DB keys.
  String toIso() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => toIso();

  // ── Arithmetic ────────────────────────────────────────────────────────────

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(_toDateTime().add(Duration(days: days)));

  LocalDate subtractDays(int days) => addDays(-days);

  /// Returns the ISO weekday: 1 = Monday … 7 = Sunday.
  int get weekday => _toDateTime().weekday;

  DateTime _toDateTime() => DateTime(year, month, day);

  // ── Comparison ────────────────────────────────────────────────────────────

  @override
  int compareTo(LocalDate other) {
    final y = year.compareTo(other.year);
    if (y != 0) return y;
    final m = month.compareTo(other.month);
    if (m != 0) return m;
    return day.compareTo(other.day);
  }

  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// A closed date range [start, end] (inclusive on both ends).
@immutable
class DateRange {
  const DateRange({required this.start, required this.end});
  final LocalDate start;
  final LocalDate end;

  bool contains(LocalDate d) => d >= start && d <= end;

  /// Iterate all dates in the range (inclusive).
  Iterable<LocalDate> get dates sync* {
    var d = start;
    while (d <= end) {
      yield d;
      d = d.addDays(1);
    }
  }
}
