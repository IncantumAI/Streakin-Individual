// lib/features/notes/search/note_chunker.dart
// Spec §4.7: splits a note's plain text into ~200–300 token chunks,
// paragraph-aware, for embedding. Tokens are approximated by whitespace words.

class TextChunk {
  const TextChunk({required this.chunkIdx, required this.text});
  final int chunkIdx;
  final String text;
  int get tokens => _tokens(text);
}

int _tokens(String s) =>
    s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

class NoteChunker {
  const NoteChunker({this.minTokens = 200, this.maxTokens = 300});
  final int minTokens;
  final int maxTokens;

  /// Paragraphs are separated by blank lines or single newlines. Paragraphs
  /// are packed greedily up to [maxTokens]; a paragraph longer than
  /// [maxTokens] is split on sentence, then word, boundaries.
  List<TextChunk> chunk(String plainText) {
    final paragraphs = plainText
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return const [];

    final pieces = <String>[];
    for (final p in paragraphs) {
      if (_tokens(p) <= maxTokens) {
        pieces.add(p);
      } else {
        pieces.addAll(_split(p));
      }
    }

    final chunks = <String>[];
    final current = StringBuffer();
    var currentTokens = 0;
    void flush() {
      if (currentTokens > 0) chunks.add(current.toString().trim());
      current.clear();
      currentTokens = 0;
    }

    for (final piece in pieces) {
      final t = _tokens(piece);
      if (currentTokens + t > maxTokens) flush();
      if (current.isNotEmpty) current.write('\n');
      current.write(piece);
      currentTokens += t;
      if (currentTokens >= minTokens) flush();
    }
    flush();

    return [
      for (var i = 0; i < chunks.length; i++)
        TextChunk(chunkIdx: i, text: chunks[i]),
    ];
  }

  List<String> _split(String paragraph) {
    final sentences = paragraph.split(RegExp(r'(?<=[.!?])\s+'));
    final out = <String>[];
    final buf = <String>[];
    var tokens = 0;
    void flush() {
      if (buf.isNotEmpty) out.add(buf.join(' '));
      buf.clear();
      tokens = 0;
    }

    for (final s in sentences) {
      final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length > maxTokens) {
        flush();
        for (var i = 0; i < words.length; i += maxTokens) {
          out.add(
            words.sublist(i, (i + maxTokens).clamp(0, words.length)).join(' '),
          );
        }
        continue;
      }
      if (tokens + words.length > maxTokens) flush();
      buf.add(s);
      tokens += words.length;
    }
    flush();
    return out;
  }
}
