import '../nearby_strings.dart';

double? _d(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String? _s(Object? v) {
  final t = v is String ? v.trim() : null;
  return t == null || t.isEmpty ? null : t;
}

enum NearbyLabel {
  inCity,
  near,
  far;

  static NearbyLabel parse(String? key) {
    switch (key) {
      case 'inCity':
        return NearbyLabel.inCity;
      case 'far':
        return NearbyLabel.far;
      default:
        return NearbyLabel.near;
    }
  }
}

class NearbyHeader {
  final String? centreCityName;
  final String? centreStateName;
  final double? centreCityKm;
  final String livesIn;
  final bool farAway;
  final double? nearestKm;
  final bool citiesUnavailable;

  const NearbyHeader({
    this.centreCityName,
    this.centreStateName,
    this.centreCityKm,
    this.livesIn = '',
    this.farAway = false,
    this.nearestKm,
    this.citiesUnavailable = false,
  });

  static const empty = NearbyHeader();

  factory NearbyHeader.fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return NearbyHeader(
      centreCityName: _s(j['centreCityName']),
      centreStateName: _s(j['centreStateName']),
      centreCityKm: _d(j['centreCityKm']),
      livesIn: _s(j['livesIn']) ?? '',
      farAway: j['farAway'] == true,
      nearestKm: _d(j['nearestKm']),
      citiesUnavailable: j['citiesUnavailable'] == true,
    );
  }
}

class NearbyDistance {
  final double km;
  final NearbyLabel label;
  final String? city;
  final String? state;

  const NearbyDistance({required this.km, required this.label, this.city, this.state});

  // The label always agrees with the km: nothing beyond 15 km reads as near.
  NearbyDistance.checked({required double km, required NearbyLabel label, String? city, String? state})
      : this(
          km: km,
          label: km > NearbyStrings.nearKm
              ? NearbyLabel.far
              : (label == NearbyLabel.far ? NearbyLabel.near : label),
          city: city,
          state: state,
        );

  bool get isFar => km > NearbyStrings.nearKm;

  static NearbyDistance? fromJson(Map<String, dynamic> j) {
    final km = _d(j['distanceKm']);
    if (km == null) return null;
    return NearbyDistance.checked(
      km: km,
      label: NearbyLabel.parse(j['labelKey'] as String?),
      city: _s(j['cityName']),
      state: _s(j['stateName']),
    );
  }
}

class NearbyPage<T> {
  final NearbyHeader header;
  final List<T> featured;
  final List<T> items;
  final bool hasMore;
  final String? nextToken;

  const NearbyPage({
    this.header = NearbyHeader.empty,
    this.featured = const [],
    this.items = const [],
    this.hasMore = false,
    this.nextToken,
  });
}
