// lib/core/crypto/base32.dart — RFC 4648 Base32 (no padding), used for the
// human-readable pairing keys and raw sharing keys (Spec §10.2).

import 'dart:typed_data';

class Base32 {
  Base32._();
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final b in bytes) {
      buffer = (buffer << 8) | (b & 0xff);
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return out.toString();
  }

  /// Decodes, ignoring spaces, dashes and case. Throws [FormatException].
  static Uint8List decode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in clean.split('')) {
      final v = _alphabet.indexOf(ch);
      if (v < 0) throw FormatException('Invalid Base32 character: $ch');
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 0xff);
        bits -= 8;
        buffer &= (1 << bits) - 1;
      }
    }
    return Uint8List.fromList(out);
  }

  /// Groups of [size] characters separated by dashes: `AAAAA-BBBBB-…`.
  static String grouped(String s, {int size = 5}) => [
    for (var i = 0; i < s.length; i += size)
      s.substring(i, (i + size).clamp(0, s.length)),
  ].join('-');
}
