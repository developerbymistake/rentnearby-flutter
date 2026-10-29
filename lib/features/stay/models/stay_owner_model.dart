class StayStatus {
  static const String draft = 'Draft';
  static const String pendingReview = 'PendingReview';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
}

class StayPhotoModel {
  final String id;
  final String url;

  const StayPhotoModel({required this.id, required this.url});

  factory StayPhotoModel.fromJson(Map<String, dynamic> json) => StayPhotoModel(
        id: json['id']?.toString() ?? '',
        url: json['url'] as String? ?? '',
      );
}

class StayRoomModel {
  final String id;
  final int roomIndex;
  final int pricePerNight;
  final int maxGuests;
  final String roomName;
  final String meals;

  const StayRoomModel({
    required this.id,
    required this.roomIndex,
    required this.pricePerNight,
    required this.maxGuests,
    required this.roomName,
    required this.meals,
  });

  String get label => roomName.isNotEmpty ? roomName : 'Room $roomIndex';

  factory StayRoomModel.fromJson(Map<String, dynamic> json) => StayRoomModel(
        id: json['id']?.toString() ?? '',
        roomIndex: (json['roomIndex'] as num?)?.toInt() ?? 1,
        pricePerNight: (json['pricePerNight'] as num?)?.toInt() ?? 0,
        maxGuests: (json['maxGuests'] as num?)?.toInt() ?? 1,
        roomName: json['roomName'] as String? ?? '',
        meals: json['meals'] as String? ?? '',
      );
}

class StayRulesModel {
  final String checkInTime;
  final String checkOutTime;
  final bool petsAllowed;
  final bool smokingAllowed;
  final bool alcoholAllowed;
  final bool unmarriedCouplesAllowed;
  final bool idProofRequired;
  final String? cancellationPolicy;

  const StayRulesModel({
    required this.checkInTime,
    required this.checkOutTime,
    required this.petsAllowed,
    required this.smokingAllowed,
    required this.alcoholAllowed,
    required this.unmarriedCouplesAllowed,
    required this.idProofRequired,
    required this.cancellationPolicy,
  });

  // Server may send TimeOnly as "HH:mm:ss"; keep "HH:mm".
  static String _hhmm(dynamic v, String fallback) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : fallback;
  }

  factory StayRulesModel.fromJson(Map<String, dynamic> json) => StayRulesModel(
        checkInTime: _hhmm(json['checkInTime'], '12:00'),
        checkOutTime: _hhmm(json['checkOutTime'], '11:00'),
        petsAllowed: json['petsAllowed'] == true,
        smokingAllowed: json['smokingAllowed'] == true,
        alcoholAllowed: json['alcoholAllowed'] == true,
        unmarriedCouplesAllowed: json['unmarriedCouplesAllowed'] == true,
        idProofRequired: json['idProofRequired'] == true,
        cancellationPolicy: json['cancellationPolicy'] as String?,
      );
}

class StayOwnerModel {
  final String id;
  final String status;
  final bool step1Done;
  final bool roomsDone;
  final bool rulesDone;
  final String? name;
  final String? stayTypeId;
  final String? stayTypeName;
  final String? vehicleAccess;
  final bool? hostLivesHere;
  final List<String> facilities;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? districtId;
  final String? districtName;
  final String? cityId;
  final String? cityName;
  final List<StayPhotoModel> photos;
  final List<StayRoomModel> rooms;
  final StayRulesModel? rules;
  final bool acceptingGuests;
  final String? rejectedReason;
  final int? minPricePerNight;
  final String? slug;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final int pendingReportCount;

  const StayOwnerModel({
    required this.id,
    required this.status,
    required this.step1Done,
    required this.roomsDone,
    required this.rulesDone,
    this.name,
    this.stayTypeId,
    this.stayTypeName,
    this.vehicleAccess,
    this.hostLivesHere,
    this.facilities = const [],
    this.description,
    this.latitude,
    this.longitude,
    this.address,
    this.districtId,
    this.districtName,
    this.cityId,
    this.cityName,
    this.photos = const [],
    this.rooms = const [],
    this.rules,
    this.acceptingGuests = true,
    this.rejectedReason,
    this.minPricePerNight,
    this.slug,
    this.submittedAt,
    required this.createdAt,
    this.pendingReportCount = 0,
  });

  bool get isDraft => status == StayStatus.draft;
  bool get isPendingReview => status == StayStatus.pendingReview;
  bool get isApproved => status == StayStatus.approved;
  bool get isRejected => status == StayStatus.rejected;
  bool get canEditSetup => isDraft || isRejected;

  String get locality =>
      [cityName, districtName].where((e) => e != null && e.isNotEmpty).join(', ');

  factory StayOwnerModel.fromJson(Map<String, dynamic> json) {
    final rooms = (json['rooms'] as List? ?? [])
        .map((e) => StayRoomModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.roomIndex.compareTo(b.roomIndex));
    return StayOwnerModel(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? StayStatus.draft,
      step1Done: json['step1Done'] == true,
      roomsDone: json['roomsDone'] == true,
      rulesDone: json['rulesDone'] == true,
      name: json['name'] as String?,
      stayTypeId: json['stayTypeId']?.toString(),
      stayTypeName: json['stayTypeName'] as String?,
      vehicleAccess: json['vehicleAccess'] as String?,
      hostLivesHere: json['hostLivesHere'] as bool?,
      facilities: (json['facilities'] as List? ?? []).map((e) => e.toString()).toList(),
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      districtId: json['districtId']?.toString(),
      districtName: json['districtName'] as String?,
      cityId: json['cityId']?.toString(),
      cityName: json['cityName'] as String?,
      photos: (json['photos'] as List? ?? [])
          .map((e) => StayPhotoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      rooms: rooms,
      rules: json['rules'] is Map<String, dynamic>
          ? StayRulesModel.fromJson(json['rules'] as Map<String, dynamic>)
          : null,
      acceptingGuests: json['acceptingGuests'] as bool? ?? true,
      rejectedReason: json['rejectedReason'] as String?,
      minPricePerNight: (json['minPricePerNight'] as num?)?.toInt(),
      slug: json['slug'] as String?,
      submittedAt: json['submittedAt'] != null ? DateTime.tryParse(json['submittedAt'].toString()) : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      pendingReportCount: (json['pendingReportCount'] as num?)?.toInt() ?? 0,
    );
  }
}
