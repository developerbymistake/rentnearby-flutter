import '../../../utils/photo_url.dart';

class TripSpotStatus {
  static const String ready = 'Ready';
  static const String notReady = 'NotReady';
  static const String stale = 'Stale';
}

class TripSpotModel {
  static const int maxPhotos = 3;
  static const int maxGallery = 10;

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
  final List<String> images;
  final int galleryCount;

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
    this.images = const [],
    this.galleryCount = 0,
  });

  String get title => (displayName == null || displayName!.isEmpty) ? name : displayName!;

  List<String> get photos {
    if (images.isNotEmpty) return images.length <= maxPhotos ? images : images.sublist(0, maxPhotos);
    final u = imageUrl;
    return u == null || u.isEmpty ? const [] : [u];
  }

  bool get hasPhoto => photos.isNotEmpty;

  static List<TripSpotModel> photoFirst(List<TripSpotModel> spots) {
    final out = <TripSpotModel>[];
    var i = 0;
    while (i < spots.length) {
      var j = i;
      while (j < spots.length && spots[j].rank == spots[i].rank) {
        j++;
      }
      final run = spots.sublist(i, j);
      out
        ..addAll(run.where((s) => s.hasPhoto))
        ..addAll(run.where((s) => !s.hasPhoto));
      i = j;
    }
    return out;
  }

  static List<String> cleanUrls(Object? raw, int max) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final e in raw) {
      final u = PhotoUrl.parse(e);
      if (u == null || !seen.add(u)) continue;
      out.add(u);
      if (out.length >= max) break;
    }
    return out;
  }

  static String? _str(Object? v) => v is String ? v : null;

  static double _num(Object? v) => v is num ? v.toDouble() : double.nan;

  static int _int(Object? v, int fallback) => v is num && v.isFinite ? v.toInt() : fallback;

  factory TripSpotModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return TripSpotModel(
      id: id is String ? id : (id == null ? '' : '$id'),
      source: _str(json['source']) ?? '',
      name: _str(json['name']) ?? '',
      displayName: _str(json['displayName']),
      description: _str(json['description']),
      latitude: _num(json['latitude']),
      longitude: _num(json['longitude']),
      category: _str(json['category']) ?? 'attraction',
      area: _str(json['area']),
      visitMinutes: _int(json['visitMinutes'], 60),
      isFeatured: json['isFeatured'] == true,
      rank: _int(json['rank'], 0),
      imageUrl: PhotoUrl.parse(json['imageUrl']),
      images: cleanUrls(json['images'], maxPhotos),
      galleryCount: _int(json['galleryCount'], 0).clamp(0, maxGallery),
    );
  }

  static TripSpotModel? tryFromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final m = TripSpotModel.fromJson(Map<String, dynamic>.from(json));
      if (m.id.isEmpty || !m.latitude.isFinite || !m.longitude.isFinite) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'name': name,
        'displayName': displayName,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'area': area,
        'visitMinutes': visitMinutes,
        'isFeatured': isFeatured,
        'rank': rank,
        'imageUrl': imageUrl,
        'images': images,
        'galleryCount': galleryCount,
      };
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

  String get version => generatedAt?.toIso8601String() ?? '';

  factory TripSpotsPage.fromJson(Map<String, dynamic> json) => TripSpotsPage(
        items: [
          for (final e in (json['items'] is List ? json['items'] as List : const []))
            ?TripSpotModel.tryFromJson(e),
        ],
        hasMore: json['hasMore'] == true,
        nextCursor: json['nextCursor'] as String?,
        status: json['status'] as String? ?? TripSpotStatus.notReady,
        cityName: json['cityName'] as String? ?? '',
        cityKey: (json['cityKey'] as num?)?.toInt(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
      );
}
