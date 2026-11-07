import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import 'trip_format.dart';
import 'trip_geo.dart';

class TripSpotMinutes {
  final List<String> ids;
  final List<List<int?>> minutes;

  const TripSpotMinutes(this.ids, this.minutes);

  static TripSpotMinutes? fromJson(Map<String, dynamic> json) {
    if (json['available'] != true) return null;
    final ids = ((json['ids'] as List?) ?? const []).whereType<String>().toList();
    final rows = <List<int?>>[
      for (final r in (json['minutes'] as List?) ?? const [])
        if (r is List) [for (final v in r) v is num ? v.round() : null],
    ];
    if (ids.isEmpty || rows.length != ids.length) return null;
    return TripSpotMinutes(ids, rows);
  }
}

class TripMinutesBook {
  final Map<String, int?> _pairs = {};

  bool get isEmpty => _pairs.isEmpty;

  void put(TripSpotMinutes m) {
    for (var i = 0; i < m.ids.length; i++) {
      final row = m.minutes[i];
      for (var j = 0; j < m.ids.length && j < row.length; j++) {
        if (i != j) _pairs['${m.ids[i]}|${m.ids[j]}'] = row[j];
      }
    }
  }

  int? between(String a, String b) => _pairs['$a|$b'] ?? _pairs['$b|$a'];
}

class TripNearby {
  final TripSpotModel spot;
  final int? minutes;
  final double km;

  const TripNearby(this.spot, this.minutes, this.km);
}

class TripRouteEstimate {
  final int places;
  final int? minutes;
  final double km;

  const TripRouteEstimate(this.places, this.minutes, this.km);
}

class TripQuickStart {
  final String id;
  final String title;
  final List<String> ids;

  const TripQuickStart(this.id, this.title, this.ids);
}

class TripSpotPicks {
  static const int mustSeeMax = 8;
  static const int quickMax = 3;
  static const int quickSize = 3;
  static const int minutesMax = 25;

  static int _rank(TripSpotModel s) => s.rank <= 0 ? 1 << 30 : s.rank;

  static List<TripSpotModel> byRank(Iterable<TripSpotModel> spots) {
    final list = spots.toList();
    final order = {for (var i = 0; i < list.length; i++) list[i].id: i};
    list.sort((a, b) {
      final c = _rank(a).compareTo(_rank(b));
      return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
    });
    return list;
  }

  static List<TripSpotModel> mustSee(List<TripSpotModel> items) {
    if (!items.any((s) => s.isFeatured)) return const [];
    final featured = byRank(items.where((s) => s.isFeatured));
    final rest = byRank(items.where((s) => !s.isFeatured));
    return [...featured, ...rest].take(mustSeeMax).toList();
  }

  static TripPoint _pt(TripSpotModel s) => (lat: s.latitude, lng: s.longitude);

  static double kmBetween(TripSpotModel a, TripSpotModel b) => TripGeo.km(_pt(a), _pt(b));

  // Unadded spots closest to the spot by straight line; used to pick what to ask the road matrix about.
  static List<TripSpotModel> candidatesNear(TripSpotModel from, List<TripSpotModel> pool, {int max = minutesMax - 1}) {
    final list = pool.where((s) => s.id != from.id).toList()
      ..sort((a, b) => kmBetween(from, a).compareTo(kmBetween(from, b)));
    return list.take(max).toList();
  }

  // Nearest by road minutes when the book knows any of these pairs, else nearest by straight line.
  static TripNearby? nearest(TripSpotModel from, List<TripSpotModel> candidates, TripMinutesBook book) {
    TripNearby? best;
    for (final c in candidates) {
      if (c.id == from.id) continue;
      final m = book.between(from.id, c.id);
      if (m == null) continue;
      if (best == null || m < best.minutes!) best = TripNearby(c, m, kmBetween(from, c));
    }
    if (best != null) return best;
    for (final c in candidates) {
      if (c.id == from.id) continue;
      final k = kmBetween(from, c);
      if (best == null || k < best.km) best = TripNearby(c, null, k);
    }
    return best;
  }

  static TripRouteEstimate? route(List<TripSpotModel> chosen, TripMinutesBook book) {
    if (chosen.length < 2) return null;
    var full = true;
    for (var i = 0; i < chosen.length && full; i++) {
      for (var j = i + 1; j < chosen.length; j++) {
        if (book.between(chosen[i].id, chosen[j].id) == null) {
          full = false;
          break;
        }
      }
    }
    double cost(TripSpotModel a, TripSpotModel b) =>
        full ? book.between(a.id, b.id)!.toDouble() : kmBetween(a, b);
    final left = chosen.toList();
    var cur = left.removeAt(0);
    var minutes = 0;
    var km = 0.0;
    while (left.isNotEmpty) {
      var bi = 0;
      for (var i = 1; i < left.length; i++) {
        if (cost(cur, left[i]) < cost(cur, left[bi])) bi = i;
      }
      final next = left.removeAt(bi);
      km += kmBetween(cur, next);
      if (full) minutes += book.between(cur.id, next.id)!;
      cur = next;
    }
    return TripRouteEstimate(chosen.length, full ? minutes : null, km);
  }

  static String routeText(TripRouteEstimate r) {
    final lead = 'Your ${r.places} places';
    final m = r.minutes;
    return m != null
        ? '$lead · about ${TripFormat.duration(m)} of driving'
        : '$lead · about ${r.km < 1 ? '1' : TripFormat.number(r.km)} km';
  }

  static String nearbyText(TripSpotModel added, TripNearby n) {
    final m = n.minutes;
    final far = m != null ? '${TripFormat.duration(m)} from' : 'about ${n.km < 1 ? '1' : TripFormat.number(n.km)} km from';
    return '${n.spot.title} is $far ${added.title}. Add it?';
  }

  static const _bundleDefs = <(String, String, List<String>)>[
    ('views', 'Lakes and views', ['lake', 'viewpoint', 'waterfall', 'beach']),
    ('temples', 'Temples', ['temple', 'ghat', 'cave']),
    ('heritage', 'Forts and heritage', ['fort', 'palace', 'museum', 'historic', 'bridge']),
    ('nature', 'Parks and wildlife', ['park', 'garden', 'zoo', 'wildlife']),
  ];

  static List<TripQuickStart> quickStarts(List<TripSpotModel> items) {
    final out = <TripQuickStart>[];
    for (final def in _bundleDefs) {
      final ids = byRank(items.where((s) => def.$3.contains(s.category))).take(quickSize).map((s) => s.id).toList();
      if (ids.length >= 2) out.add(TripQuickStart(def.$1, def.$2, ids));
    }
    final town = byRank(items).take(quickSize).map((s) => s.id).toList();
    if (town.length >= 2 && out.length < quickMax) out.add(TripQuickStart('town', 'Half day in town', town));
    return out.take(quickMax).toList();
  }

  // Ids this bundle may add: not yet picked, within the room left; picked ones are untouched.
  static List<String> bundleAdds(TripQuickStart b, Set<String> selected, int room) =>
      b.ids.where((id) => !selected.contains(id)).take(room < 0 ? 0 : room).toList();

  static int roomFor({required int limit, required int selected, required int existing, required int other}) {
    final byLimit = limit < 0 ? TripConstants.maxSpots : limit - selected;
    final byTrip = TripConstants.maxSpots - selected - existing - other;
    return byLimit < byTrip ? byLimit : byTrip;
  }
}
