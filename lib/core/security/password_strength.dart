// lib/core/security/password_strength.dart
// zxcvbn-style estimate (pure Dart, offline): entropy from character pools,
// penalised for repeats, sequences and common passwords. Score 0–4.
// Policy (Phase 5C): minimum 10 chars; block submission when score < 2.

import 'dart:math';

class PasswordStrength {
  const PasswordStrength({
    required this.score,
    required this.entropyBits,
    required this.crackTimeLabel,
    required this.meetsMinimum,
  });

  /// 0 (very weak) … 4 (very strong).
  final int score;
  final double entropyBits;
  final String crackTimeLabel;
  final bool meetsMinimum;

  bool get acceptable => meetsMinimum && score >= 2;
  String get label =>
      const ['Very weak', 'Weak', 'Fair', 'Strong', 'Very strong'][score];

  static const minLength = 10;
  static const _common = {
    'password',
    'passw0rd',
    '12345678',
    '123456789',
    '1234567890',
    'qwertyuiop',
    'qwerty123',
    'iloveyou',
    'letmein123',
    'welcome123',
    'admin1234',
    'abc12345',
    'password1',
    'password123',
    '1q2w3e4r5t',
    'streakin',
  };

  static PasswordStrength estimate(String pw) {
    if (pw.isEmpty) {
      return const PasswordStrength(
        score: 0,
        entropyBits: 0,
        crackTimeLabel: 'instantly',
        meetsMinimum: false,
      );
    }
    var pool = 0;
    if (pw.contains(RegExp(r'[a-z]'))) pool += 26;
    if (pw.contains(RegExp(r'[A-Z]'))) pool += 26;
    if (pw.contains(RegExp(r'[0-9]'))) pool += 10;
    if (pw.contains(RegExp(r'[^A-Za-z0-9]'))) pool += 33;
    var bits = pw.length * (log(max(pool, 2)) / ln2);

    // Penalties: repeated chars, sequences, common passwords.
    final unique = pw.split('').toSet().length;
    bits -= (pw.length - unique) * 1.5;
    final lower = pw.toLowerCase();
    if (_common.any(lower.contains)) bits = min(bits, 20);
    if (_hasSequence(lower)) bits -= 8;
    if (RegExp(r'^(.)\1+$').hasMatch(pw)) bits = min(bits, 8);
    bits = max(bits, 0);

    final score = bits < 28
        ? 0
        : bits < 40
        ? 1
        : bits < 56
        ? 2
        : bits < 72
        ? 3
        : 4;
    return PasswordStrength(
      score: score,
      entropyBits: bits,
      crackTimeLabel: _crackTime(bits),
      meetsMinimum: pw.length >= minLength,
    );
  }

  static bool _hasSequence(String s) {
    var run = 1;
    for (var i = 1; i < s.length; i++) {
      final d = s.codeUnitAt(i) - s.codeUnitAt(i - 1);
      run = (d == 1 || d == -1) ? run + 1 : 1;
      if (run >= 4) return true;
    }
    return false;
  }

  /// Offline fast-hash attacker at 1e10 guesses/s (conservative for Argon2id
  /// this is pessimistic, which is the safe direction for a UI estimate).
  static String _crackTime(double bits) {
    final seconds = pow(2, bits) / 1e10 / 2;
    if (seconds < 1) return 'instantly';
    if (seconds < 60) return '${seconds.round()} seconds';
    if (seconds < 3600) return '${(seconds / 60).round()} minutes';
    if (seconds < 86400) return '${(seconds / 3600).round()} hours';
    if (seconds < 86400 * 365) return '${(seconds / 86400).round()} days';
    final years = seconds / (86400 * 365);
    if (years < 1e3) return '${years.round()} years';
    if (years < 1e6) return 'thousands of years';
    return 'centuries';
  }
}
