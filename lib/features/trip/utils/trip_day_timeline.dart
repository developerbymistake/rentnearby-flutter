class TripDayTimeline {
  static const int startMinute = 9 * 60;

  static List<int> starts({
    required List<int> visits,
    required List<int?> roads,
    int reserved = 0,
    int from = startMinute,
  }) {
    final out = <int>[];
    var t = from + (reserved < 0 ? 0 : reserved);
    for (var i = 0; i < visits.length; i++) {
      out.add(t);
      t += visits[i] + (i < roads.length ? (roads[i] ?? 0) : 0);
    }
    return out;
  }

  static String clock(int minutes) {
    final m = minutes % (24 * 60);
    final h = m ~/ 60;
    final mm = (m % 60).toString().padLeft(2, '0');
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$mm ${h < 12 ? 'am' : 'pm'}';
  }
}
