class TaxiCountdown {
  const TaxiCountdown._();

  static Duration remaining(DateTime? until, {required Duration offset, required DateTime now}) {
    if (until == null) return Duration.zero;
    final left = until.toUtc().difference(now.toUtc().add(offset));
    return left.isNegative ? Duration.zero : left;
  }

  static bool isOver(DateTime? until, {required Duration offset, required DateTime now}) =>
      remaining(until, offset: offset, now: now) == Duration.zero;

  static String text(Duration left) {
    final ms = left.isNegative ? 0 : left.inMilliseconds;
    final seconds = (ms + 999) ~/ 1000;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String label(DateTime? until, {required Duration offset, required DateTime now}) =>
      text(remaining(until, offset: offset, now: now));
}
