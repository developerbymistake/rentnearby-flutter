class TripSpotStatus {
  static const String ready = 'Ready';
  static const String notReady = 'NotReady';
  static const String stale = 'Stale';
}

class TripSpotModel {
  final String id;
  final String source;
  final String name;
  final String? displayName;
  final String? description;
  final double latitude;
  final double longitude;
  final String category;
  final String? area;
  final int visitMinutes;
  final bool isFeatured;
  final int rank;
  final String? imageUrl;
  final String? imageCredit;
  final String? imageLicense;

  const TripSpotModel({
    required this.id,
    required this.source,
    required this.name,
    this.displayName,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.area,
    required this.visitMinutes,
    this.isFeatured = false,
    this.rank = 0,
    this.imageUrl,
    this.imageCredit,
    this.imageLicense,
  });

  String get title => (displayName == null || displayName!.isEmpty) ? name : displayName!;

  factory TripSpotModel.fromJson(Map<String, dynamic> json) => TripSpotModel(
        id: json['id'] as String,
        source: json['source'] as String? ?? '',
        name: json['name'] as String? ?? '',
        displayName: json['displayName'] as String?,
        description: json['description'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        category: json['category'] as String? ?? 'attraction',
        area: json['area'] as String?,
        visitMinutes: (json['visitMinutes'] as num?)?.toInt() ?? 60,
        isFeatured: json['isFeatured'] == true,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        imageUrl: json['imageUrl'] as String?,
        imageCredit: json['imageCredit'] as String?,
        imageLicense: json['imageLicense'] as String?,
      );
}

class TripSpotsPage {
  final List<TripSpotModel> items;
  final bool hasMore;
  final String? nextCursor;
  final String status;
  final String cityName;
  final int? cityKey;
  final int total;
  final DateTime? generatedAt;

  const TripSpotsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    required this.status,
    required this.cityName,
    this.cityKey,
    required this.total,
    this.generatedAt,
  });

  bool get isNotReady => status == TripSpotStatus.notReady;

  factory TripSpotsPage.fromJson(Map<String, dynamic> json) => TripSpotsPage(
        items: ((json['items'] as List?) ?? const [])
            .map((e) => TripSpotModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: json['hasMore'] == true,
        nextCursor: json['nextCursor'] as String?,
        status: json['status'] as String? ?? TripSpotStatus.notReady,
        cityName: json['cityName'] as String? ?? '',
        cityKey: (json['cityKey'] as num?)?.toInt(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
      );
}
