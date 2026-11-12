import '../../../utils/city_search_rank.dart';
import '../../../utils/cloudinary_thumb.dart';
import '../trip_strings_tab.dart';

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
  final String? coverUrl;
  final String status;
  final int spotCount;
  final bool isPopularDestination;

  const TripCityModel({
    required this.cityKey,
    required this.name,
    this.districtName = '',
    this.stateName = '',
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.coverUrl,
    this.status = TripCityStatus.ready,
    this.spotCount = 0,
    this.isPopularDestination = false,
  });

  bool get isReady => status == TripCityStatus.ready;

  String? get cover {
    final c = coverUrl;
    if (c != null && c.isNotEmpty) return c;
    final i = imageUrl;
    return i == null || i.isEmpty ? null : CloudinaryThumb.of(i);
  }

  String get placeLine => [districtName, stateName].where((s) => s.isNotEmpty).join(' · ');

  String get tileLine => [districtName, if (spotCount > 0) TripStringsTab.cityMeta(spotCount)].where((s) => s.isNotEmpty).join(' · ');

  factory TripCityModel.fromJson(Map<String, dynamic> json) => TripCityModel(
        cityKey: (json['cityKey'] as num).toInt(),
        name: json['name'] as String? ?? '',
        districtName: json['districtName'] as String? ?? '',
        stateName: json['stateName'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String?,
        coverUrl: json['coverUrl'] as String?,
        status: json['status'] as String? ?? TripCityStatus.ready,
        spotCount: (json['spotCount'] as num?)?.toInt() ?? 0,
        isPopularDestination: json['isPopularDestination'] == true,
      );

  Map<String, dynamic> toJson() => {
        'cityKey': cityKey,
        'name': name,
        'districtName': districtName,
        'stateName': stateName,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': imageUrl,
        'coverUrl': coverUrl,
        'status': status,
        'spotCount': spotCount,
        'isPopularDestination': isPopularDestination,
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
  static List<TripCityModel> filter(List<TripCityModel> all, String q) => CitySearchRank.rank<TripCityModel>(
        all,
        q,
        name: (c) => c.name,
        districtOf: (c) => c.districtName,
        popular: (c) => c.isPopularDestination,
        weight: (c) => c.spotCount,
      );

  static List<TripCityModel> popularFirst(List<TripCityModel> items) => [
        ...items.where((c) => c.isPopularDestination),
        ...items.where((c) => !c.isPopularDestination),
      ];

  static List<TripCityModel> dedupe(Iterable<TripCityModel> items) {
    final seen = <int>{};
    return [for (final c in items) if (seen.add(c.cityKey)) c];
  }
}
