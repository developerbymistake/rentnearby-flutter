import 'trip_geo.dart';

class TripStayQuoteLine {
  final String roomName;
  final int units;
  final int guests;
  final int? pricePerNight;

  const TripStayQuoteLine({required this.roomName, required this.units, required this.guests, this.pricePerNight});

  factory TripStayQuoteLine.fromJson(Map<String, dynamic> json) => TripStayQuoteLine(
        roomName: json['roomName'] as String? ?? '',
        units: (json['units'] as num?)?.toInt() ?? 0,
        guests: (json['guests'] as num?)?.toInt() ?? 0,
        pricePerNight: (json['pricePerNight'] as num?)?.toInt(),
      );
}

// Where the night sits: the day's spots in route order and the next morning's first spot (same city), if any.
class TripStayNight {
  final List<TripPoint> spots;
  final TripPoint? next;

  const TripStayNight({required this.spots, this.next});

  List<TripPoint> get points => [...spots, ?next];

  TripPoint? get evening => spots.isEmpty ? null : spots.last;
}

class TripStayFit {
  final String id;
  final int priorityRank;
  final bool? fits;
  final int? quotePerNight;
  final int? quoteTotal;
  final List<TripStayQuoteLine> quoteLines;
  final double nearestKm;
  final int nearestIndex;
  final double detourKm;

  const TripStayFit({
    required this.id,
    this.priorityRank = 0,
    this.fits,
    this.quotePerNight,
    this.quoteTotal,
    this.quoteLines = const [],
    required this.nearestKm,
    this.nearestIndex = 0,
    required this.detourKm,
  });
}

// Trip stay ranking: fits the party, then paid rank, then the night's added travel
// (last spot of the day -> stay -> first spot of the next morning), then the nearest spot, then id.
class TripStayRank {
  static double detourKm(TripPoint stay, TripPoint evening, TripPoint? next) {
    if (next == null) return TripGeo.km(evening, stay);
    final d = TripGeo.km(evening, stay) + TripGeo.km(stay, next) - TripGeo.km(evening, next);
    return d < 0 ? 0 : d;
  }

  static TripStayFit? evaluate(Map<String, dynamic> json, TripStayNight night) {
    final id = json['id'];
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    if (id is! String || lat == null || lng == null) return null;
    final at = (lat: lat, lng: lng);
    final points = night.points;
    final near = TripGeo.valid(at) ? TripGeo.nearest(at, points) : null;
    final evening = night.evening;
    final lines = json['quoteLines'];
    return TripStayFit(
      id: id,
      priorityRank: (json['priorityRank'] as num?)?.toInt() ?? 0,
      fits: json['fits'] is bool ? json['fits'] as bool : null,
      quotePerNight: (json['quotePerNight'] as num?)?.toInt(),
      quoteTotal: (json['quoteTotal'] as num?)?.toInt(),
      quoteLines: lines is List
          ? [for (final l in lines.whereType<Map<String, dynamic>>()) TripStayQuoteLine.fromJson(l)]
          : const [],
      nearestKm: near?.km ?? double.infinity,
      nearestIndex: near?.index ?? 0,
      detourKm: evening == null || !TripGeo.valid(at) ? (near?.km ?? double.infinity) : detourKm(at, evening, night.next),
    );
  }

  static int _fitOrder(bool? f) => f == true ? 0 : (f == null ? 1 : 2);

  static int compare(TripStayFit a, TripStayFit b) {
    var c = _fitOrder(a.fits).compareTo(_fitOrder(b.fits));
    if (c != 0) return c;
    c = b.priorityRank.compareTo(a.priorityRank);
    if (c != 0) return c;
    c = a.detourKm.compareTo(b.detourKm);
    if (c != 0) return c;
    c = a.nearestKm.compareTo(b.nearestKm);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  // Deduped by id (first wins), kept within radiusKm of the night's points, ranked by compare.
  static List<TripStayFit> rank(Iterable<Map<String, dynamic>> rows, TripStayNight night, double radiusKm) {
    final seen = <String>{};
    final out = <TripStayFit>[];
    for (final r in rows) {
      final f = evaluate(r, night);
      if (f == null || !seen.add(f.id) || f.nearestKm > radiusKm) continue;
      out.add(f);
    }
    out.sort(compare);
    return out;
  }

  static int? priceOf(TripStayFit? f, int? listed) => f?.quotePerNight ?? listed;
}
