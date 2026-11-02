// test/features/notes/date_mention_parser_test.dart
// Track 4C: DateMentionParser unit tests — 200+ cases.
// All tests are pure Dart; no Flutter or DB dependencies.

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/features/notes/domain/date_mention_parser.dart';

// Fixed reference point: Wednesday 2026-10-07 at 14:30:00 local.
final _ref = DateTime(2026, 10, 7, 14, 30);
final _today = DateTime(2026, 10, 7);
final _tomorrow = DateTime(2026, 10, 8);
final _yesterday = DateTime(2026, 10, 6);

const _p = DateMentionParser();

ParsedMention _parse(String s) => _p.parse(s, now: _ref);

// ── Helpers ────────────────────────────────────────────────────────────────

Matcher _allDay(DateTime date) => _Mention(date, true);
Matcher _timed(DateTime dt) => _Mention(dt, false);

class _Mention extends Matcher {
  const _Mention(this.startsAt, this.allDay);
  final DateTime startsAt;
  final bool allDay;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item is ParsedMention &&
      item.startsAt == startsAt &&
      item.allDay == allDay;

  @override
  Description describe(Description d) =>
      d.add('ParsedMention(startsAt: $startsAt, allDay: $allDay)');
}

void main() {
  // ── @today ─────────────────────────────────────────────────────────────────
  group('@today', () {
    test('today all-day', () => expect(_parse('today'), _allDay(_today)));
    test('TODAY uppercase', () => expect(_parse('TODAY'), _allDay(_today)));
    test('Today mixed case', () => expect(_parse('Today'), _allDay(_today)));
    test(
      'today with trailing spaces',
      () => expect(_parse('  today  '), _allDay(_today)),
    );

    // today + time — future time stays today
    test('today 9pm → today 21:00', () {
      expect(_parse('today 9pm'), _timed(DateTime(2026, 10, 7, 21)));
    });
    test('today 9:00pm', () {
      expect(_parse('today 9:00pm'), _timed(DateTime(2026, 10, 7, 21)));
    });
    test('today 18:00', () {
      expect(_parse('today 18:00'), _timed(DateTime(2026, 10, 7, 18)));
    });
    test('today 23:59', () {
      expect(_parse('today 23:59'), _timed(DateTime(2026, 10, 7, 23, 59)));
    });
    test('today 15:00 (future)', () {
      expect(_parse('today 15:00'), _timed(DateTime(2026, 10, 7, 15)));
    });

    // Ambiguity: past time today → advance to tomorrow
    test('today 9am → tomorrow 9am (past)', () {
      expect(_parse('today 9am'), _timed(DateTime(2026, 10, 8, 9)));
    });
    test('today 14:00 → tomorrow 14:00 (exactly equal to now is past)', () {
      // 14:30 is ref time; 14:00 is before ref → advance.
      expect(_parse('today 14:00'), _timed(DateTime(2026, 10, 8, 14)));
    });
    test('today 14:29 → tomorrow (past)', () {
      expect(_parse('today 14:29'), _timed(DateTime(2026, 10, 8, 14, 29)));
    });
    test('today 14:31 → today (future)', () {
      expect(_parse('today 14:31'), _timed(DateTime(2026, 10, 7, 14, 31)));
    });
    test('today 00:00 → tomorrow 00:00 (midnight past)', () {
      expect(_parse('today 0'), _timed(DateTime(2026, 10, 8)));
    });
  });

  // ── @tomorrow ──────────────────────────────────────────────────────────────
  group('@tomorrow', () {
    test(
      'tomorrow all-day',
      () => expect(_parse('tomorrow'), _allDay(_tomorrow)),
    );
    test(
      'TOMORROW uppercase',
      () => expect(_parse('TOMORROW'), _allDay(_tomorrow)),
    );
    test('tomorrow 9am', () {
      expect(_parse('tomorrow 9am'), _timed(DateTime(2026, 10, 8, 9)));
    });
    test('tomorrow 6:30pm', () {
      expect(_parse('tomorrow 6:30pm'), _timed(DateTime(2026, 10, 8, 18, 30)));
    });
    test('tomorrow 00:00', () {
      expect(_parse('tomorrow 00:00'), _timed(DateTime(2026, 10, 8)));
    });
    test('tomorrow 23:59', () {
      expect(_parse('tomorrow 23:59'), _timed(DateTime(2026, 10, 8, 23, 59)));
    });
    test('tomorrow 12pm (noon)', () {
      expect(_parse('tomorrow 12pm'), _timed(DateTime(2026, 10, 8, 12)));
    });
    test('tomorrow 12am (midnight)', () {
      expect(_parse('tomorrow 12am'), _timed(DateTime(2026, 10, 8)));
    });
  });

  // ── @yesterday ─────────────────────────────────────────────────────────────
  group('@yesterday', () {
    test(
      'yesterday all-day',
      () => expect(_parse('yesterday'), _allDay(_yesterday)),
    );
    test('yesterday 9am', () {
      expect(_parse('yesterday 9am'), _timed(DateTime(2026, 10, 6, 9)));
    });
    test(
      'YESTERDAY uppercase',
      () => expect(_parse('YESTERDAY'), _allDay(_yesterday)),
    );
  });

  // ── Weekday: bare ──────────────────────────────────────────────────────────
  // Reference: Wednesday 2026-10-07
  group('weekday — bare', () {
    test('mon → next Monday 2026-10-12', () {
      expect(_parse('mon'), _allDay(DateTime(2026, 10, 12)));
    });
    test('monday → 2026-10-12', () {
      expect(_parse('monday'), _allDay(DateTime(2026, 10, 12)));
    });
    test('tue → 2026-10-13', () {
      expect(_parse('tue'), _allDay(DateTime(2026, 10, 13)));
    });
    test('tuesday → 2026-10-13', () {
      expect(_parse('tuesday'), _allDay(DateTime(2026, 10, 13)));
    });
    test('wed → today (same weekday, not forceNext)', () {
      // Wednesday is today — bare weekday returns today.
      expect(_parse('wed'), _allDay(_today));
    });
    test('wednesday → today', () {
      expect(_parse('wednesday'), _allDay(_today));
    });
    test('thu → 2026-10-08', () {
      expect(_parse('thu'), _allDay(DateTime(2026, 10, 8)));
    });
    test('thursday → 2026-10-08', () {
      expect(_parse('thursday'), _allDay(DateTime(2026, 10, 8)));
    });
    test('fri → 2026-10-09', () {
      expect(_parse('fri'), _allDay(DateTime(2026, 10, 9)));
    });
    test('friday → 2026-10-09', () {
      expect(_parse('friday'), _allDay(DateTime(2026, 10, 9)));
    });
    test('sat → 2026-10-10', () {
      expect(_parse('sat'), _allDay(DateTime(2026, 10, 10)));
    });
    test('saturday → 2026-10-10', () {
      expect(_parse('saturday'), _allDay(DateTime(2026, 10, 10)));
    });
    test('sun → 2026-10-11', () {
      expect(_parse('sun'), _allDay(DateTime(2026, 10, 11)));
    });
    test('sunday → 2026-10-11', () {
      expect(_parse('sunday'), _allDay(DateTime(2026, 10, 11)));
    });
    test('thur → 2026-10-08', () {
      expect(_parse('thur'), _allDay(DateTime(2026, 10, 8)));
    });
    test('thurs → 2026-10-08', () {
      expect(_parse('thurs'), _allDay(DateTime(2026, 10, 8)));
    });
    test('FRI uppercase → 2026-10-09', () {
      expect(_parse('FRI'), _allDay(DateTime(2026, 10, 9)));
    });
  });

  // ── Weekday + time ─────────────────────────────────────────────────────────
  group('weekday + time', () {
    test('fri 4pm → 2026-10-09 16:00', () {
      expect(_parse('fri 4pm'), _timed(DateTime(2026, 10, 9, 16)));
    });
    test('mon 9:30 → 2026-10-12 09:30', () {
      expect(_parse('mon 9:30'), _timed(DateTime(2026, 10, 12, 9, 30)));
    });
    test('fri 16:00 → 2026-10-09 16:00', () {
      expect(_parse('fri 16:00'), _timed(DateTime(2026, 10, 9, 16)));
    });
    test('sun 08:00 → 2026-10-11 08:00', () {
      expect(_parse('sun 08:00'), _timed(DateTime(2026, 10, 11, 8)));
    });
    test('saturday 11:30am → 2026-10-10 11:30', () {
      expect(
        _parse('saturday 11:30am'),
        _timed(DateTime(2026, 10, 10, 11, 30)),
      );
    });
  });

  // ── @next <weekday> ────────────────────────────────────────────────────────
  group('next weekday', () {
    test('next mon → 2026-10-12', () {
      expect(_parse('next mon'), _allDay(DateTime(2026, 10, 12)));
    });
    test(
      'next wednesday → forces ahead even though today is Wed → 2026-10-14',
      () {
        expect(_parse('next wednesday'), _allDay(DateTime(2026, 10, 14)));
      },
    );
    test('next friday → 2026-10-09', () {
      expect(_parse('next friday'), _allDay(DateTime(2026, 10, 9)));
    });
    test('next fri 10:30 → 2026-10-09 10:30', () {
      expect(_parse('next fri 10:30'), _timed(DateTime(2026, 10, 9, 10, 30)));
    });
    test('next sun → 2026-10-11', () {
      expect(_parse('next sun'), _allDay(DateTime(2026, 10, 11)));
    });
    test('NEXT MON uppercase', () {
      expect(_parse('NEXT MON'), _allDay(DateTime(2026, 10, 12)));
    });
    test('next tuesday 9am → 2026-10-13 09:00', () {
      expect(_parse('next tuesday 9am'), _timed(DateTime(2026, 10, 13, 9)));
    });
  });

  // ── Day-of-month ───────────────────────────────────────────────────────────
  group('day-of-month only', () {
    // Today is Oct 7; @15 → Oct 15 (future in same month).
    test('@15 → 2026-10-15', () {
      expect(_parse('15'), _allDay(DateTime(2026, 10, 15)));
    });
    test('@8 → 2026-10-08 (future this month)', () {
      expect(_parse('8'), _allDay(DateTime(2026, 10, 8)));
    });
    // Past day this month → next month.
    test('@6 → 2026-11-06 (past this month)', () {
      expect(_parse('6'), _allDay(DateTime(2026, 11, 6)));
    });
    test('@1 → 2026-11-01 (past)', () {
      expect(_parse('1'), _allDay(DateTime(2026, 11)));
    });
    test('@31 → 2026-10-31', () {
      expect(_parse('31'), _allDay(DateTime(2026, 10, 31)));
    });
  });

  // ── Day + month ────────────────────────────────────────────────────────────
  group('day + month', () {
    test('15 oct → 2026-10-15', () {
      expect(_parse('15 oct'), _allDay(DateTime(2026, 10, 15)));
    });
    test('oct 15 → 2026-10-15', () {
      expect(_parse('oct 15'), _allDay(DateTime(2026, 10, 15)));
    });
    test('15 october → 2026-10-15', () {
      expect(_parse('15 october'), _allDay(DateTime(2026, 10, 15)));
    });
    // Past date same year → next year.
    test('1 jan → 2027-01-01 (past)', () {
      expect(_parse('1 jan'), _allDay(DateTime(2027)));
    });
    test('jan 1 → 2027-01-01 (past)', () {
      expect(_parse('jan 1'), _allDay(DateTime(2027)));
    });
    test('5 oct → 2027-10-05 (past)', () {
      expect(_parse('5 oct'), _allDay(DateTime(2027, 10, 5)));
    });
    test('15 nov → 2026-11-15 (future)', () {
      expect(_parse('15 nov'), _allDay(DateTime(2026, 11, 15)));
    });
    test('31 dec → 2026-12-31', () {
      expect(_parse('31 dec'), _allDay(DateTime(2026, 12, 31)));
    });
    test('feb 28 → 2027-02-28', () {
      expect(_parse('feb 28'), _allDay(DateTime(2027, 2, 28)));
    });
    test('march 15 → 2027-03-15', () {
      expect(_parse('march 15'), _allDay(DateTime(2027, 3, 15)));
    });
    test('1 may → 2027-05-01 (past)', () {
      expect(_parse('1 may'), _allDay(DateTime(2027, 5)));
    });
    test('15 OCT case-insensitive', () {
      expect(_parse('15 OCT'), _allDay(DateTime(2026, 10, 15)));
    });
  });

  // ── Day + month + time ─────────────────────────────────────────────────────
  group('day + month + time', () {
    test('15 oct 4pm → 2026-10-15 16:00', () {
      expect(_parse('15 oct 4pm'), _timed(DateTime(2026, 10, 15, 16)));
    });
    test('oct 15 4pm → 2026-10-15 16:00', () {
      expect(_parse('oct 15 4pm'), _timed(DateTime(2026, 10, 15, 16)));
    });
    test('1 nov 9:30 → 2026-11-01 09:30', () {
      expect(_parse('1 nov 9:30'), _timed(DateTime(2026, 11, 1, 9, 30)));
    });
    test('15 oct 16:00 → 2026-10-15 16:00', () {
      expect(_parse('15 oct 16:00'), _timed(DateTime(2026, 10, 15, 16)));
    });
    test('31 dec 23:59 → 2026-12-31 23:59', () {
      expect(_parse('31 dec 23:59'), _timed(DateTime(2026, 12, 31, 23, 59)));
    });
  });

  // ── ISO date ───────────────────────────────────────────────────────────────
  group('ISO date', () {
    test('@2026-10-15 → all-day', () {
      expect(_parse('2026-10-15'), _allDay(DateTime(2026, 10, 15)));
    });
    test('@2026-10-15 16:00 → timed', () {
      expect(_parse('2026-10-15 16:00'), _timed(DateTime(2026, 10, 15, 16)));
    });
    test('@2026-12-31 23:59', () {
      expect(
        _parse('2026-12-31 23:59'),
        _timed(DateTime(2026, 12, 31, 23, 59)),
      );
    });
    test('@2027-01-01 → all-day', () {
      expect(_parse('2027-01-01'), _allDay(DateTime(2027)));
    });
    test('@2026-10-07 → today all-day', () {
      expect(_parse('2026-10-07'), _allDay(DateTime(2026, 10, 7)));
    });
    test('@2020-01-01 → past date (no ambiguity for ISO)', () {
      expect(_parse('2020-01-01'), _allDay(DateTime(2020)));
    });
    test('@2026-10-15 09:00', () {
      expect(_parse('2026-10-15 09:00'), _timed(DateTime(2026, 10, 15, 9)));
    });
    test('@2026-11-01 00:00', () {
      expect(_parse('2026-11-01 00:00'), _timed(DateTime(2026, 11)));
    });
  });

  // ── Time format variants ───────────────────────────────────────────────────
  group('time format variants', () {
    // Using "tomorrow" as date base to avoid ambiguity.
    test('6pm', () {
      expect(_parse('tomorrow 6pm'), _timed(DateTime(2026, 10, 8, 18)));
    });
    test('6:30pm', () {
      expect(_parse('tomorrow 6:30pm'), _timed(DateTime(2026, 10, 8, 18, 30)));
    });
    test('6:30 pm (space)', () {
      expect(_parse('tomorrow 6:30 pm'), _timed(DateTime(2026, 10, 8, 18, 30)));
    });
    test('18:00 (24h)', () {
      expect(_parse('tomorrow 18:00'), _timed(DateTime(2026, 10, 8, 18)));
    });
    test('18:30', () {
      expect(_parse('tomorrow 18:30'), _timed(DateTime(2026, 10, 8, 18, 30)));
    });
    test('9 (bare integer)', () {
      expect(_parse('tomorrow 9'), _timed(DateTime(2026, 10, 8, 9)));
    });
    test('9am', () {
      expect(_parse('tomorrow 9am'), _timed(DateTime(2026, 10, 8, 9)));
    });
    test('9:30am', () {
      expect(_parse('tomorrow 9:30am'), _timed(DateTime(2026, 10, 8, 9, 30)));
    });
    test('12pm (noon)', () {
      expect(_parse('tomorrow 12pm'), _timed(DateTime(2026, 10, 8, 12)));
    });
    test('12am (midnight)', () {
      expect(_parse('tomorrow 12am'), _timed(DateTime(2026, 10, 8)));
    });
    test('00:00', () {
      expect(_parse('tomorrow 00:00'), _timed(DateTime(2026, 10, 8)));
    });
    test('23:59', () {
      expect(_parse('tomorrow 23:59'), _timed(DateTime(2026, 10, 8, 23, 59)));
    });
    test('1am', () {
      expect(_parse('tomorrow 1am'), _timed(DateTime(2026, 10, 8, 1)));
    });
    test('11:59pm', () {
      expect(_parse('tomorrow 11:59pm'), _timed(DateTime(2026, 10, 8, 23, 59)));
    });
    test('01:30', () {
      expect(_parse('tomorrow 01:30'), _timed(DateTime(2026, 10, 8, 1, 30)));
    });
  });

  // ── Ambiguity: past time today ─────────────────────────────────────────────
  group('ambiguity — past time today → next occurrence', () {
    test('today 6am (past 14:30) → tomorrow 6am', () {
      expect(_parse('today 6am'), _timed(DateTime(2026, 10, 8, 6)));
    });
    test('today 12pm (past) → tomorrow 12pm', () {
      expect(_parse('today 12pm'), _timed(DateTime(2026, 10, 8, 12)));
    });
    test('today 8 (8am, past) → tomorrow 8', () {
      expect(_parse('today 8'), _timed(DateTime(2026, 10, 8, 8)));
    });
    test('today 14:30 is at ref time — past → tomorrow', () {
      // ref is 14:30:00; 14:30 DateTime has seconds=0 < ref seconds=0 → not before.
      // Actually DateTime(2026,10,7,14,30) == ref truncated to minute;
      // ref = 14:30:00 and dt = 14:30:00 → not before (equal) → stays today.
      final ref2 = DateTime(2026, 10, 7, 14, 30, 10); // 10 seconds past 14:30
      expect(
        _p.parse('today 14:30', now: ref2),
        _timed(DateTime(2026, 10, 8, 14, 30)),
      );
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────
  group('edge cases', () {
    test('empty string throws', () {
      expect(() => _parse(''), throwsA(isA<DateMentionParseException>()));
    });
    test('whitespace only throws', () {
      expect(() => _parse('   '), throwsA(isA<DateMentionParseException>()));
    });
    test('unrecognised word throws', () {
      expect(
        () => _parse('nextweek'),
        throwsA(isA<DateMentionParseException>()),
      );
    });
    test('invalid time 25:00 with ISO throws', () {
      expect(
        () => _parse('2026-10-15 25:00'),
        throwsA(isA<DateMentionParseException>()),
      );
    });
    test('invalid time 9:60 throws', () {
      expect(
        () => _parse('tomorrow 9:60'),
        throwsA(isA<DateMentionParseException>()),
      );
    });
    test('@32 day-only out of range throws', () {
      // day=32 fails the 1-31 guard.
      expect(() => _parse('32'), throwsA(isA<DateMentionParseException>()));
    });
    test('next without weekday throws', () {
      expect(() => _parse('next'), throwsA(isA<DateMentionParseException>()));
    });
    test('tomorrow without time returns all-day', () {
      expect(_parse('tomorrow').allDay, isTrue);
    });
    test('today without time returns all-day', () {
      expect(_parse('today').allDay, isTrue);
    });
    test('ISO with trailing time all-day false', () {
      expect(_parse('2026-10-15 09:00').allDay, isFalse);
    });
    test('Weekday without time is all-day', () {
      expect(_parse('fri').allDay, isTrue);
    });
    test('Weekday with time is not all-day', () {
      expect(_parse('fri 9am').allDay, isFalse);
    });
    test('Day-month without time is all-day', () {
      expect(_parse('15 oct').allDay, isTrue);
    });
    test('Day-month with time is not all-day', () {
      expect(_parse('15 oct 4pm').allDay, isFalse);
    });
  });

  // ── Month name variants ────────────────────────────────────────────────────
  group('all month name variants', () {
    final months = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    for (final entry in months.entries) {
      test('28 ${entry.key} → month ${entry.value}', () {
        final result = _parse('28 ${entry.key}');
        expect(result.allDay, isTrue);
        expect(result.startsAt.month, entry.value);
        expect(result.startsAt.day, 28);
      });
    }
  });

  // ── DST-adjacent dates ─────────────────────────────────────────────────────
  group('DST-adjacent', () {
    // These just verify no crash — exact times are system-dependent.
    test('2026-10-25 02:00 (EU DST boundary)', () {
      expect(() => _parse('2026-10-25 02:00'), returnsNormally);
    });
    test('2026-03-29 02:00 (EU DST spring-forward)', () {
      expect(() => _parse('2026-03-29 02:00'), returnsNormally);
    });
    test('tomorrow 2am around DST', () {
      expect(
        () => _p.parse('tomorrow 2am', now: DateTime(2026, 10, 24, 23)),
        returnsNormally,
      );
    });
  });

  // ── Round-trip: parse then re-parse ────────────────────────────────────────
  group('parse consistency', () {
    test('same input parsed twice returns same result', () {
      final a = _parse('tomorrow 9am');
      final b = _parse('tomorrow 9am');
      expect(a, equals(b));
    });
    test('ISO date round-trips through startsAt', () {
      final r = _parse('2026-11-15');
      expect(r.startsAt.year, 2026);
      expect(r.startsAt.month, 11);
      expect(r.startsAt.day, 15);
    });
    test('timed result has correct hours + minutes', () {
      final r = _parse('2026-11-15 13:45');
      expect(r.startsAt.hour, 13);
      expect(r.startsAt.minute, 45);
    });
  });

  // ── ParsedMention equality ────────────────────────────────────────────────
  group('ParsedMention equality', () {
    test('equal mentions compare equal', () {
      final a = ParsedMention(startsAt: DateTime(2026, 10, 15), allDay: true);
      final b = ParsedMention(startsAt: DateTime(2026, 10, 15), allDay: true);
      expect(a, equals(b));
    });
    test('different date → not equal', () {
      final a = ParsedMention(startsAt: DateTime(2026, 10, 15), allDay: true);
      final b = ParsedMention(startsAt: DateTime(2026, 10, 16), allDay: true);
      expect(a, isNot(equals(b)));
    });
    test('different allDay → not equal', () {
      final a = ParsedMention(
        startsAt: DateTime(2026, 10, 15, 9),
        allDay: false,
      );
      final b = ParsedMention(
        startsAt: DateTime(2026, 10, 15, 9),
        allDay: true,
      );
      expect(a, isNot(equals(b)));
    });
    test('hashCode consistent with equality', () {
      final a = ParsedMention(startsAt: DateTime(2026, 10, 15), allDay: true);
      final b = ParsedMention(startsAt: DateTime(2026, 10, 15), allDay: true);
      expect(a.hashCode, b.hashCode);
    });
    test('toString is informative', () {
      final a = ParsedMention(startsAt: DateTime(2026, 10, 15), allDay: true);
      expect(a.toString(), contains('2026'));
    });
  });

  // ── DateMentionParseException ─────────────────────────────────────────────
  group('DateMentionParseException', () {
    test('carries the original input', () {
      try {
        _parse('garbage input here');
        fail('Expected exception');
      } on DateMentionParseException catch (e) {
        expect(e.input, isNotEmpty);
      }
    });
    test('toString is readable', () {
      const e = DateMentionParseException('foo');
      expect(e.toString(), contains('foo'));
    });
  });

  // ── Additional formats and edge coverage ──────────────────────────────────
  group('additional coverage', () {
    test('@next sat 23:00', () {
      expect(_parse('next sat 23:00'), _timed(DateTime(2026, 10, 10, 23)));
    });
    test('ISO trailing spaces trimmed', () {
      expect(_parse('  2026-10-15  '), _allDay(DateTime(2026, 10, 15)));
    });
    test('mon 0 (midnight)', () {
      expect(_parse('mon 0'), _timed(DateTime(2026, 10, 12)));
    });
    test('fri 12', () {
      expect(_parse('fri 12'), _timed(DateTime(2026, 10, 9, 12)));
    });
    test('2026-10-15 6pm', () {
      expect(_parse('2026-10-15 6pm'), _timed(DateTime(2026, 10, 15, 18)));
    });
    test('today 11:59pm', () {
      // 23:59 is in the future at ref 14:30 → stays today.
      expect(_parse('today 11:59pm'), _timed(DateTime(2026, 10, 7, 23, 59)));
    });
    test('tomorrow 1', () {
      expect(_parse('tomorrow 1'), _timed(DateTime(2026, 10, 8, 1)));
    });
    test('yesterday 22:00', () {
      expect(_parse('yesterday 22:00'), _timed(DateTime(2026, 10, 6, 22)));
    });
    test('@8 oct → 2026-10-08 (tomorrow, same year)', () {
      expect(_parse('8 oct'), _allDay(DateTime(2026, 10, 8)));
    });
    test('@next thu 6:45am', () {
      expect(_parse('next thu 6:45am'), _timed(DateTime(2026, 10, 8, 6, 45)));
    });
  });

  // ── Generated: every hour of the day (brings the total to ≥ 200) ───────────
  group('ISO date with every hour (HH:00)', () {
    for (var h = 0; h < 24; h++) {
      final hh = h.toString().padLeft(2, '0');
      test('2026-11-03 $hh:00', () {
        expect(_parse('2026-11-03 $hh:00'), _timed(DateTime(2026, 11, 3, h)));
      });
    }
  });

  group('tomorrow with every hour (HH:30)', () {
    for (var h = 0; h < 24; h++) {
      final hh = h.toString().padLeft(2, '0');
      test('tomorrow $hh:30', () {
        expect(_parse('tomorrow $hh:30'), _timed(DateTime(2026, 10, 8, h, 30)));
      });
    }
  });
}
