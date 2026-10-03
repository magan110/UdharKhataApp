/// Display only. Ledger arithmetic and wire/export formatting stay unchanged.
String formatDisplayPaise(int value) {
  final absolute = value.abs();
  final digits = (absolute ~/ 100).toString();
  final groups = <String>[];
  var end = digits.length;
  var width = 3;
  while (end > 0) {
    final start = (end - width).clamp(0, end);
    groups.insert(0, digits.substring(start, end));
    end = start;
    width = 2;
  }
  return '${value < 0 ? '-' : ''}₹${groups.join(',')}.${(absolute % 100).toString().padLeft(2, '0')}';
}
