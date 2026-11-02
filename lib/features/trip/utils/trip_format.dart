class TripFormat {
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String km(double value) => '${number(value)} km';

  static String visit(int minutes) {
    if (minutes < 60) return '$minutes min';
    return '${_trim(minutes / 60)} h';
  }

  static String number(double value) => value < 10 ? _trim(value) : value.round().toString();

  static String _trim(double value) {
    final s = value.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}
