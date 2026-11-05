import 'trip_geo.dart';

// One definition of a day's load, the same as the server's SplitDay: route = visit + drive (server totalMinutes),
// load = reserved travel road + route, over the limit when load > limit.
class TripDayLoad {
  static const double fallbackSpeedKmh = 30;
  static const double estimateFactor = 2.0;

  static int route({int? serverTotal, required int visitMinutes}) => serverTotal ?? visitMinutes;

  static int load({required int reserved, required int route}) => (reserved < 0 ? 0 : reserved) + route;

  static bool isOver(int load, int limit) => load > limit;

  // Straight-line estimate, same rule as the server's DaySplitter.FillEstimates.
  static int estimateMinutes(TripPoint a, TripPoint b) {
    final km = TripGeo.km(a, b);
    return (km / fallbackSpeedKmh * 60 * estimateFactor).ceil();
  }

  // Cheapest insertion of a new stop into a route of n stops: position p goes before stop p (p == n appends).
  // delta(p) = in(p - 1 -> x) + out(x -> p) - leg(p - 1 -> p); ties keep the later position. O(n).
  static ({int index, int deltaMinutes}) cheapestInsertion({
    required int count,
    required int Function(int from) toNew,
    required int Function(int to) fromNew,
    required int Function(int from) legAfter,
  }) {
    if (count <= 0) return (index: 0, deltaMinutes: 0);
    var bestIndex = count;
    var best = toNew(count - 1);
    for (var p = count - 1; p >= 0; p--) {
      final d = (p > 0 ? toNew(p - 1) : 0) + fromNew(p) - (p > 0 ? legAfter(p - 1) : 0);
      if (d < best) {
        best = d;
        bestIndex = p;
      }
    }
    return (index: bestIndex, deltaMinutes: best);
  }
}
