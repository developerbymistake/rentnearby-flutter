class TripCityStatus {
  static const String ready = 'Ready';
  static const String notReady = 'NotReady';
}

class TripCityModel {
  final int cityKey;
  final String name;
  final String districtName;
  final String stateName;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String status;
  final int spotCount;

  const TripCityModel({
    required this.cityKey,
    required this.name,
    this.districtName = '',
    this.stateName = '',
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.status = TripCityStatus.ready,
    this.spotCount = 0,
  });

  bool get isReady => status == TripCityStatus.ready;

  String get placeLine => [districtName, stateName].where((s) => s.isNotEmpty).join(' · ');

  factory TripCityModel.fromJson(Map<String, dynamic> json) => TripCityModel(
        cityKey: (json['cityKey'] as num).toInt(),
        name: json['name'] as String? ?? '',
        districtName: json['districtName'] as String? ?? '',
        stateName: json['stateName'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String?,
        status: json['status'] as String? ?? TripCityStatus.ready,
        spotCount: (json['spotCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'cityKey': cityKey,
        'name': name,
        'districtName': districtName,
        'stateName': stateName,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': imageUrl,
        'status': status,
        'spotCount': spotCount,
      };
}

class TripCityPage {
  final List<TripCityModel> items;
  final bool hasMore;
  final String version;
  final int count;
  final bool stale;

  const TripCityPage({
    required this.items,
    required this.hasMore,
    required this.version,
    required this.count,
    required this.stale,
  });

  factory TripCityPage.fromJson(Map<String, dynamic> json) => TripCityPage(
        items: ((json['items'] as List?) ?? const [])
            .map((e) => TripCityModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: json['hasMore'] == true,
        version: json['version'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        stale: json['stale'] == true,
      );
}

class TripCityVersion {
  final String version;
  final int count;
  final bool stale;

  const TripCityVersion({required this.version, required this.count, required this.stale});

  factory TripCityVersion.fromJson(Map<String, dynamic> json) => TripCityVersion(
        version: json['version'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        stale: json['stale'] == true,
      );
}

class TripCitySearch {
  static List<TripCityModel> filter(List<TripCityModel> all, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return List.of(all);
    final prefix = <TripCityModel>[];
    final contains = <TripCityModel>[];
    for (final c in all) {
      final name = c.name.toLowerCase();
      if (name.startsWith(query)) {
        prefix.add(c);
      } else if (name.contains(query) || c.placeLine.toLowerCase().contains(query)) {
        contains.add(c);
      }
    }
    return [...prefix, ...contains];
  }

  static List<TripCityModel> dedupe(Iterable<TripCityModel> items) {
    final seen = <int>{};
    return [for (final c in items) if (seen.add(c.cityKey)) c];
  }
}
