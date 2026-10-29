import '../../../config/app_constants.dart';
import 'stay_owner_model.dart';

class StayDetailModel {
  final String id;
  final String userId;
  final String? slug;
  final String? name;
  final String? stayTypeId;
  final String? stayTypeName;
  final String? vehicleAccess;
  final bool? hostLivesHere;
  final List<String> facilities;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? districtName;
  final String? cityName;
  final String? cityId;
  final double? cityLat;
  final double? cityLng;
  final List<String> photos;
  final List<StayRoomModel> rooms;
  final StayRulesModel? rules;
  final int? minPricePerNight;
  final String? ownerName;
  final String? ownerPhone;
  final bool hasReported;
  final DateTime createdAt;

  StayDetailModel({
    required this.id,
    required this.userId,
    this.slug,
    this.name,
    this.stayTypeId,
    this.stayTypeName,
    this.vehicleAccess,
    this.hostLivesHere,
    required this.facilities,
    this.description,
    this.latitude,
    this.longitude,
    this.districtName,
    this.cityName,
    this.cityId,
    this.cityLat,
    this.cityLng,
    required this.photos,
    required this.rooms,
    this.rules,
    this.minPricePerNight,
    this.ownerName,
    this.ownerPhone,
    required this.hasReported,
    required this.createdAt,
  });

  String get title => (name == null || name!.isEmpty) ? 'Stay' : name!;

  String get locality =>
      [cityName, districtName].where((s) => s != null && s.isNotEmpty).join(', ');

  String get placeName {
    for (final n in [cityName, districtName]) {
      final t = n?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return 'This stay';
  }

  ({double lat, double lng})? get taxiTarget {
    if (cityLat != null && cityLng != null) return (lat: cityLat!, lng: cityLng!);
    if (latitude != null && longitude != null) return (lat: latitude!, lng: longitude!);
    return null;
  }

  static String _url(String u) => u.startsWith('http') ? u : '${AppConstants.serverUrl}$u';

  factory StayDetailModel.fromJson(Map<String, dynamic> j) => StayDetailModel(
        id: j['id'] as String,
        userId: j['userId'] as String? ?? '',
        slug: j['slug'] as String?,
        name: j['name'] as String?,
        stayTypeId: j['stayTypeId']?.toString(),
        stayTypeName: j['stayTypeName'] as String?,
        vehicleAccess: j['vehicleAccess'] as String?,
        hostLivesHere: j['hostLivesHere'] as bool?,
        facilities: ((j['facilities'] as List?) ?? const []).map((e) => e.toString()).toList(),
        description: j['description'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        districtName: j['districtName'] as String?,
        cityName: j['cityName'] as String?,
        cityId: j['cityId']?.toString(),
        cityLat: (j['cityLatitude'] as num?)?.toDouble(),
        cityLng: (j['cityLongitude'] as num?)?.toDouble(),
        photos: ((j['photos'] as List?) ?? const []).map((e) => _url(e.toString())).toList(),
        rooms: ((j['rooms'] as List?) ?? const [])
            .map((e) => StayRoomModel.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.roomIndex.compareTo(b.roomIndex)),
        rules: j['rules'] is Map<String, dynamic> ? StayRulesModel.fromJson(j['rules'] as Map<String, dynamic>) : null,
        minPricePerNight: (j['minPricePerNight'] as num?)?.toInt(),
        ownerName: j['ownerName'] as String?,
        ownerPhone: j['ownerPhone'] as String?,
        hasReported: j['hasReported'] == true,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
