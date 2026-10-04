// test/core/time/local_date_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/time/local_date.dart';

void main() {
  group('LocalDate', () {
    test('toIso formats correctly', () {
      expect(const LocalDate(2026, 1, 5).toIso(), '2026-01-05');
      expect(const LocalDate(2026, 12, 31).toIso(), '2026-12-31');
    });

    test('parse round-trips', () {
      const s = '2026-10-04';
      final d = LocalDate.parse(s);
      expect(d.toIso(), s);
    });

    test('equality', () {
      expect(const LocalDate(2026, 10, 4), const LocalDate(2026, 10, 4));
      expect(const LocalDate(2026, 10, 4), isNot(const LocalDate(2026, 10, 5)));
    });

    test('comparison operators', () {
      const a = LocalDate(2026, 1, 1);
      const b = LocalDate(2026, 1, 2);
      expect(a < b, isTrue);
      expect(b > a, isTrue);
      expect(a <= a, isTrue);
      expect(a >= a, isTrue);
    });

    test('addDays / subtractDays', () {
      const d = LocalDate(2026, 12, 30);
      expect(d.addDays(2).toIso(), '2027-01-01');
      expect(d.subtractDays(1).toIso(), '2026-12-29');
    });

    test('weekday returns ISO weekday', () {
      // 2026-10-05 is a Monday (weekday = 1)
      expect(const LocalDate(2026, 10, 5).weekday, 1);
      // 2026-10-11 is a Sunday (weekday = 7)
      expect(const LocalDate(2026, 10, 11).weekday, 7);
    });

    test('DateRange.contains', () {
      const r = DateRange(start: LocalDate(2026, 1, 1), end: LocalDate(2026, 1, 7));
      expect(r.contains(const LocalDate(2026, 1, 1)), isTrue);
      expect(r.contains(const LocalDate(2026, 1, 7)), isTrue);
      expect(r.contains(const LocalDate(2025, 12, 31)), isFalse);
      expect(r.contains(const LocalDate(2026, 1, 8)), isFalse);
    });

    test('DateRange.dates iterates all days', () {
      const r = DateRange(start: LocalDate(2026, 1, 1), end: LocalDate(2026, 1, 3));
      final dates = r.dates.toList();
      expect(dates.length, 3);
      expect(dates[0].toIso(), '2026-01-01');
      expect(dates[2].toIso(), '2026-01-03');
    });
  });
}
