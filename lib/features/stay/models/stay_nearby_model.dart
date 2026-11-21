import '../../../config/app_constants.dart';
import 'stay_price_chip.dart';

class StayNearbyModel {
  final String id;
  final String? name;
  final String? stayTypeName;
  final double latitude;
  final double longitude;
  final int? minPricePerNight;
  final String? thumbnailUrl;
  final double distanceKm;
  final String? ownerName;
  final String? ownerPhone;
  final bool isActive;
  final bool isFeatured;
  final int? maxGuests;
  final String? meals;
  final String? checkInTime;
  final int roomCount;
  final bool hasGroundFloorRoom;
  final String? bestRoomName;
  final int? bestRoomGuests;
  final String? cityName;
  final String? districtName;
  final int? datesTotal;
  final int? datesPerNight;
  final int? basePerNight;
  final StayPriceChip? priceChip;
  final bool fullOnDates;

  StayNearbyModel({
    required this.id,
    this.name,
    this.stayTypeName,
    required this.latitude,
    required this.longitude,
    this.minPricePerNight,
    this.thumbnailUrl,
    required this.distanceKm,
    this.ownerName,
    this.ownerPhone,
    required this.isActive,
    this.isFeatured = false,
    this.maxGuests,
    this.meals,
    this.checkInTime,
    this.roomCount = 0,
    this.hasGroundFloorRoom = false,
    this.bestRoomName,
    this.bestRoomGuests,
    this.cityName,
    this.districtName,
    this.datesTotal,
    this.datesPerNight,
    this.basePerNight,
    this.priceChip,
    this.fullOnDates = false,
  });

  bool get hasDatedPrice => datesPerNight != null;

  int? get struckBase {
    final d = datesPerNight, b = basePerNight;
    return d != null && b != null && b > d ? b : null;
  }

  String get locality {
    final parts = <String>[];
    for (final n in [cityName, districtName]) {
      final v = n?.trim() ?? '';
      if (v.isNotEmpty && !parts.any((p) => p.toLowerCase() == v.toLowerCase())) parts.add(v);
    }
    return parts.join(', ');
  }

  String get title => (name == null || name!.isEmpty) ? 'Stay' : name!;

  static String? _url(String? u) =>
      u == null || u.isEmpty ? null : (u.startsWith('http') ? u : '${AppConstants.serverUrl}$u');

  factory StayNearbyModel.fromJson(Map<String, dynamic> json) => StayNearbyModel(
        id: json['id'] as String,
        name: json['name'] as String?,
        stayTypeName: json['stayTypeName'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        minPricePerNight: (json['minPricePerNight'] as num?)?.toInt(),
        thumbnailUrl: _url(json['thumbnailUrl']?.toString().trim()),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        ownerName: json['ownerName'] as String?,
        ownerPhone: json['ownerPhone'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        isFeatured: json['isFeatured'] == true,
        maxGuests: (json['maxGuests'] as num?)?.toInt(),
        meals: json['meals'] as String?,
        checkInTime: json['checkInTime'] as String?,
        roomCount: (json['roomCount'] as num?)?.toInt() ?? 0,
        hasGroundFloorRoom: json['hasGroundFloorRoom'] == true,
        bestRoomName: json['bestRoomName'] as String?,
        bestRoomGuests: (json['bestRoomGuests'] as num?)?.toInt(),
        cityName: json['cityName'] as String?,
        districtName: json['districtName'] as String?,
        datesTotal: StayPriceChip.money(json['datesTotal']),
        datesPerNight: StayPriceChip.money(json['datesPerNight']),
        basePerNight: StayPriceChip.money(json['basePerNight']),
        priceChip: StayPriceChip.fromJson(json['priceChip']),
        fullOnDates: json['fullOnDates'] == true,
      );
}
