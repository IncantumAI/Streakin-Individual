// lib/core/time/hlc.dart — added < > operators, removed unused _rng field.

class Hlc implements Comparable<Hlc> {
  const Hlc({required this.wallMs, required this.counter, required this.node});

  final int wallMs;
  final int counter;
  final String node;

  static int _lastWallMs = 0;
  static int _lastCounter = 0;
  static String _node = '0000';

  static void init(String nodeId) {
    _node = nodeId.length >= 4
        ? nodeId.substring(0, 4)
        : nodeId.padLeft(4, '0');
  }

  static Hlc now() {
    final wall = DateTime.now().millisecondsSinceEpoch;
    if (wall > _lastWallMs) {
      _lastWallMs = wall;
      _lastCounter = 0;
    } else {
      _lastCounter++;
    }
    return Hlc(wallMs: _lastWallMs, counter: _lastCounter, node: _node);
  }

  String toIso() =>
      '$wallMs-${counter.toRadixString(16).padLeft(4, '0')}-$node';

  @override
  String toString() => toIso();

  factory Hlc.parse(String s) {
    final parts = s.split('-');
    if (parts.length != 3) throw FormatException('Invalid HLC: $s');
    return Hlc(
      wallMs: int.parse(parts[0]),
      counter: int.parse(parts[1], radix: 16),
      node: parts[2],
    );
  }

  @override
  int compareTo(Hlc other) {
    final w = wallMs.compareTo(other.wallMs);
    if (w != 0) return w;
    final c = counter.compareTo(other.counter);
    if (c != 0) return c;
    return node.compareTo(other.node);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <=(Hlc other) => compareTo(other) <= 0;
  bool operator >=(Hlc other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      wallMs == other.wallMs &&
      counter == other.counter &&
      node == other.node;

  @override
  int get hashCode => Object.hash(wallMs, counter, node);
}
