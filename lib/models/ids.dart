import 'dart:math';

/// Erzeugt kurze, praktisch eindeutige IDs ohne zusätzliche Abhängigkeit.
String newId([String prefix = '']) {
  final rnd = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final buf = StringBuffer(prefix);
  buf.write(DateTime.now().microsecondsSinceEpoch.toRadixString(36));
  buf.write('-');
  for (var i = 0; i < 6; i++) {
    buf.write(chars[rnd.nextInt(chars.length)]);
  }
  return buf.toString();
}
