// lib/features/notes/domain/date_mention_parser.dart
// Spec §4.4.5: DateMentionParser — pure Dart, no Flutter, no external chrono lib.
//
// Supported @-mention formats (case-insensitive):
//   Relative:
//     @today                    → today, all-day
//     @tomorrow                 → tomorrow, all-day
//     @yesterday                → yesterday, all-day
//     @today 6pm                → today at 18:00
//     @tomorrow 9:30            → tomorrow at 09:30
//     @today 9:30am             → today at 09:30
//   Weekday (nearest future or today):
//     @monday / @mon            → next Monday, all-day
//     @fri 4pm                  → next Friday at 16:00
//     @next monday              → next Monday (skips today), all-day
//     @next fri 10:30           → next Friday at 10:30
//   Day-of-month:
//     @15                       → 15th of current or next month, all-day
//     @15 oct                   → 15 October current or next year, all-day
//     @15 oct 4pm               → 15 October at 16:00
//     @oct 15                   → same as @15 oct
//     @oct 15 4pm
//   ISO date:
//     @2026-10-15               → all-day
//     @2026-10-15 16:00         → specific time
//
// Ambiguity rule: if a time-only input resolves to a past time today,
//   it advances to the next day.
//
// Returns: ParsedMention { DateTime startsAt, bool allDay }
// Throws:  DateMentionParseException on unrecognised input.

class ParsedMention {
  const ParsedMention({required this.startsAt, required this.allDay});
  final DateTime startsAt;
  final bool allDay;

  @override
  bool operator ==(Object other) =>
      other is ParsedMention &&
      startsAt == other.startsAt &&
      allDay == other.allDay;

  @override
  int get hashCode => Object.hash(startsAt, allDay);

  @override
  String toString() => 'ParsedMention(startsAt: $startsAt, allDay: $allDay)';
}

class DateMentionParseException implements Exception {
  const DateMentionParseException(this.input);
  final String input;

  @override
  String toString() => 'DateMentionParseException: cannot parse "@$input"';
}

class DateMentionParser {
  const DateMentionParser();

  // ── Month name table ────────────────────────────────────────────────────────
  static const _months = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  // ── Weekday name table ──────────────────────────────────────────────────────
  static const _weekdays = {
    'mon': 1, 'monday': 1,
    'tue': 2, 'tuesday': 2,
    'wed': 3, 'wednesday': 3,
    'thu': 4, 'thursday': 4, 'thur': 4, 'thurs': 4,
    'fri': 5, 'friday': 5,
    'sat': 6, 'saturday': 6,
    'sun': 7, 'sunday': 7,
  };

  /// Parse a raw @-mention string (without the leading `@`).
  /// [now] is the current DateTime; defaults to [DateTime.now()].
  ParsedMention parse(String raw, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final input = raw.trim().toLowerCase();

    if (input.isEmpty) throw DateMentionParseException(raw);

    // ── ISO date: 2026-10-15 [HH:mm] ────────────────────────────────────────
    final isoMatch = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2})(?:\s+(.+))?$')
        .firstMatch(input);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      final timeStr = isoMatch.group(4);
      final date = DateTime(y, m, d);
      if (timeStr != null) {
        final t = _parseTime(timeStr);
        if (t == null) throw DateMentionParseException(raw);
        return ParsedMention(
            startsAt: DateTime(y, m, d, t.$1, t.$2), allDay: false);
      }
      return ParsedMention(startsAt: date, allDay: true);
    }

    // ── Relative: today / tomorrow / yesterday [time] ────────────────────────
    if (input.startsWith('today')) {
      final rest = input.substring(5).trim();
      if (rest.isEmpty) return ParsedMention(startsAt: today, allDay: true);
      final t = _parseTime(rest);
      if (t == null) throw DateMentionParseException(raw);
      var dt = DateTime(today.year, today.month, today.day, t.$1, t.$2);
      // Ambiguity: past time today → advance to tomorrow.
      if (dt.isBefore(base)) {
        dt = dt.add(const Duration(days: 1));
      }
      return ParsedMention(startsAt: dt, allDay: false);
    }

    if (input.startsWith('tomorrow')) {
      final rest = input.substring(8).trim();
      final tomorrow = today.add(const Duration(days: 1));
      if (rest.isEmpty) return ParsedMention(startsAt: tomorrow, allDay: true);
      final t = _parseTime(rest);
      if (t == null) throw DateMentionParseException(raw);
      return ParsedMention(
          startsAt: DateTime(
              tomorrow.year, tomorrow.month, tomorrow.day, t.$1, t.$2),
          allDay: false);
    }

    if (input.startsWith('yesterday')) {
      final rest = input.substring(9).trim();
      final yesterday = today.subtract(const Duration(days: 1));
      if (rest.isEmpty) {
        return ParsedMention(startsAt: yesterday, allDay: true);
      }
      final t = _parseTime(rest);
      if (t == null) throw DateMentionParseException(raw);
      return ParsedMention(
          startsAt: DateTime(
              yesterday.year, yesterday.month, yesterday.day, t.$1, t.$2),
          allDay: false);
    }

    // ── "next <weekday> [time]" ──────────────────────────────────────────────
    if (input.startsWith('next ')) {
      final rest = input.substring(5).trim();
      return _parseWeekdayExpr(rest, today, base, forceNext: true,
          rawFull: raw);
    }

    // ── Bare weekday [time] ──────────────────────────────────────────────────
    for (final entry in _weekdays.entries) {
      if (input == entry.key ||
          input.startsWith('${entry.key} ') ||
          input.startsWith('${entry.key}\t')) {
        final rest = input.substring(entry.key.length).trim();
        return _parseWeekdayExpr(input, today, base,
            forceNext: false, rawFull: raw);
      }
    }

    // ── "<day> <month> [time]" or "<month> <day> [time]" ────────────────────
    final dayMonthResult = _tryDayMonth(input, today, raw);
    if (dayMonthResult != null) return dayMonthResult;

    // ── Bare day number: @15 [time] ──────────────────────────────────────────
    final dayOnly =
        RegExp(r'^(\d{1,2})(?:\s+(.+))?$').firstMatch(input);
    if (dayOnly != null) {
      final day = int.parse(dayOnly.group(1)!);
      if (day >= 1 && day <= 31) {
        final timeStr = dayOnly.group(2);
        DateTime date = DateTime(today.year, today.month, day);
        if (!date.isAfter(today.subtract(const Duration(days: 1)))) {
          // Past or today (without time) — advance to next month.
          date = DateTime(today.year, today.month + 1, day);
        }
        if (timeStr == null) {
          return ParsedMention(startsAt: date, allDay: true);
        }
        final t = _parseTime(timeStr);
        if (t == null) throw DateMentionParseException(raw);
        var dt = DateTime(date.year, date.month, date.day, t.$1, t.$2);
        if (dt.isBefore(base)) dt = dt.add(const Duration(days: 31));
        return ParsedMention(startsAt: dt, allDay: false);
      }
    }

    throw DateMentionParseException(raw);
  }

  // ── Parse weekday expression ──────────────────────────────────────────────

  ParsedMention _parseWeekdayExpr(
    String input,
    DateTime today,
    DateTime base, {
    required bool forceNext,
    required String rawFull,
  }) {
    // Split off leading weekday name.
    String? matched;
    int? isoWeekday;
    for (final entry in _weekdays.entries) {
      if (input == entry.key ||
          input.startsWith('${entry.key} ') ||
          input.startsWith('${entry.key}\t')) {
        matched = entry.key;
        isoWeekday = entry.value;
        break;
      }
    }
    if (isoWeekday == null) throw DateMentionParseException(rawFull);

    final rest = input.substring(matched!.length).trim();
    final date = _nextWeekday(today, isoWeekday, forceNext: forceNext);

    if (rest.isEmpty) return ParsedMention(startsAt: date, allDay: true);
    final t = _parseTime(rest);
    if (t == null) throw DateMentionParseException(rawFull);
    return ParsedMention(
        startsAt: DateTime(date.year, date.month, date.day, t.$1, t.$2),
        allDay: false);
  }

  // ── Parse day-month combinations ─────────────────────────────────────────

  ParsedMention? _tryDayMonth(String input, DateTime today, String raw) {
    // Patterns: "15 oct [time]" or "oct 15 [time]"
    final tokens = input.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;

    int? day;
    int? month;
    String? timeToken;

    // "<day> <month> [time]"
    if (tokens.length >= 2) {
      final d = int.tryParse(tokens[0]);
      final m = _months[tokens[1]];
      if (d != null && m != null) {
        day = d;
        month = m;
        timeToken = tokens.length >= 3 ? tokens.sublist(2).join(' ') : null;
      }
    }

    // "<month> <day> [time]"
    if (day == null && tokens.length >= 2) {
      final m = _months[tokens[0]];
      final d = int.tryParse(tokens[1]);
      if (m != null && d != null) {
        month = m;
        day = d;
        timeToken = tokens.length >= 3 ? tokens.sublist(2).join(' ') : null;
      }
    }

    if (day == null || month == null) return null;
    if (day < 1 || day > 31) return null;

    // Choose year: current year, or next year if the date has passed.
    DateTime date = DateTime(today.year, month, day);
    if (date.isBefore(today)) {
      date = DateTime(today.year + 1, month, day);
    }

    if (timeToken == null || timeToken.isEmpty) {
      return ParsedMention(startsAt: date, allDay: true);
    }
    final t = _parseTime(timeToken);
    if (t == null) return null;
    return ParsedMention(
        startsAt: DateTime(date.year, date.month, date.day, t.$1, t.$2),
        allDay: false);
  }

  // ── Next weekday helper ───────────────────────────────────────────────────

  /// Returns the date of the nearest [isoWeekday] (1=Mon…7=Sun).
  /// If [forceNext] is true, always advances past today even if today matches.
  static DateTime _nextWeekday(DateTime from, int isoWeekday,
      {required bool forceNext}) {
    int diff = isoWeekday - from.weekday;
    if (diff < 0) diff += 7;
    if (diff == 0 && forceNext) diff = 7;
    return from.add(Duration(days: diff));
  }

  // ── Time parser ───────────────────────────────────────────────────────────
  // Supports: "6pm", "6:30pm", "6:30 pm", "18:00", "9", "9:30", "9am", "9:30am"

  static (int hour, int minute)? _parseTime(String s) {
    s = s.trim().toLowerCase();
    if (s.isEmpty) return null;

    // HH:mm[:ss] 24h
    final hm24 = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(s);
    if (hm24 != null) {
      final h = int.parse(hm24.group(1)!);
      final m = int.parse(hm24.group(2)!);
      if (h > 23 || m > 59) return null;
      return (h, m);
    }

    // H[H][:MM][am|pm]
    final ampm = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$').firstMatch(s);
    if (ampm != null) {
      int h = int.parse(ampm.group(1)!);
      final m = int.tryParse(ampm.group(2) ?? '0') ?? 0;
      final suffix = ampm.group(3)!;
      if (h > 12 || m > 59) return null;
      if (suffix == 'pm' && h != 12) h += 12;
      if (suffix == 'am' && h == 12) h = 0;
      return (h, m);
    }

    // Bare integer hour (0–23) — no am/pm
    final bare = RegExp(r'^(\d{1,2})$').firstMatch(s);
    if (bare != null) {
      final h = int.parse(bare.group(1)!);
      if (h > 23) return null;
      return (h, 0);
    }

    return null;
  }
}
