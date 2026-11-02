// Track 5C: strength meter policy (min 10 chars, block when score < 2).

import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/core/security/password_strength.dart';

void main() {
  test('too short never meets the minimum', () {
    final s = PasswordStrength.estimate('Ab1!');
    expect(s.meetsMinimum, isFalse);
    expect(s.acceptable, isFalse);
  });

  test(
    'common / repetitive / sequential passwords are blocked (score < 2)',
    () {
      for (final pw in [
        'password123',
        'aaaaaaaaaaaa',
        '1234567890',
        'qwerty123456',
      ]) {
        final s = PasswordStrength.estimate(pw);
        expect(s.score, lessThan(2), reason: pw);
        expect(s.acceptable, isFalse, reason: pw);
      }
    },
  );

  test('a long mixed passphrase is accepted and has a crack-time label', () {
    final s = PasswordStrength.estimate('violet-Harbor-27-lantern!');
    expect(s.acceptable, isTrue);
    expect(s.score, greaterThanOrEqualTo(3));
    expect(s.crackTimeLabel, isNotEmpty);
  });

  test('score is monotonic with length for the same character classes', () {
    final a = PasswordStrength.estimate('Tr0ub4dor&3').entropyBits;
    final b = PasswordStrength.estimate('Tr0ub4dor&3-horse-staple').entropyBits;
    expect(b, greaterThan(a));
  });
}
