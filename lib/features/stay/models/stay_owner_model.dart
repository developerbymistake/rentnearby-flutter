import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/json/owner_json.dart';

class StayStatus {
  static const String draft = 'Draft';
  static const String pendingReview = 'PendingReview';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
}

class StayPhotoModel {
  final String id;
  final String url;
  final int photoOrder;

  const StayPhotoModel({required this.id, required this.url, this.photoOrder = 0});

  factory StayPhotoModel.fromJson(Map<String, dynamic> json) => StayPhotoModel(
        id: OwnerJson.str(json['id']),
        url: OwnerJson.str(json['url']),
        photoOrder: OwnerJson.integer(json['photoOrder']),
      );

  static List<StayPhotoModel> listOf(Object? raw) => OwnerJson.list(raw, StayPhotoModel.fromJson).where((p) => p.id.isNotEmpty).toList();
}

class StayRoomModel {
  final String id;
  final int roomIndex;
  final int pricePerNight;
  final int maxGuests;
  final String roomName;
  final String meals;
  final int? priceToday;

  const StayRoomModel({
    required this.id,
    required this.roomIndex,
    required this.pricePerNight,
    required this.maxGuests,
    required this.roomName,
    required this.meals,
    this.priceToday,
  });

  String get label => roomName.isNotEmpty ? roomName : 'Room $roomIndex';

  factory StayRoomModel.fromJson(Map<String, dynamic> json) => StayRoomModel(
        id: OwnerJson.str(json['id']),
        roomIndex: OwnerJson.integer(json['roomIndex'], 1),
        pricePerNight: OwnerJson.integer(json['pricePerNight']),
        maxGuests: OwnerJson.integer(json['maxGuests'], 1),
        roomName: OwnerJson.str(json['roomName']),
        meals: OwnerJson.str(json['meals']),
        priceToday: OwnerJson.intOrNull(json['priceToday']),
      );

  static List<StayRoomModel> listOf(Object? raw) =>
      OwnerJson.list(raw, StayRoomModel.fromJson).where((r) => r.id.isNotEmpty).toList()..sort((a, b) => a.roomIndex.compareTo(b.roomIndex));
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
  static String _hhmm(Object? v, String fallback) {
    final s = v is String ? v : '';
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
        cancellationPolicy: OwnerJson.strOrNull(json['cancellationPolicy']),
      );
}

class StayPendingEdit {
  final Map<String, dynamic> fields;
  final DateTime? at;

  const StayPendingEdit({this.fields = const {}, this.at});

  static StayPendingEdit? maybe(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    return StayPendingEdit(fields: OwnerJson.map(j['fields']), at: OwnerJson.time(j['at']));
  }

  bool get touchesName => fields.containsKey('name');
  bool get touchesRegistration =>
      fields.containsKey('registrationNumber') ||
      fields.containsKey('registrationTypeName') ||
      fields.containsKey('registrationOtherName') ||
      fields.containsKey('gstin');
  bool get touchesLocation =>
      fields.containsKey('address') ||
      fields.containsKey('latitude') ||
      fields.containsKey('longitude') ||
      fields.containsKey('districtName') ||
      fields.containsKey('cityName');
}

class StayEditResult {
  final bool approved;
  final String? reason;
  final DateTime? at;
  final List<String> fieldsChanged;

  const StayEditResult({required this.approved, this.reason, this.at, this.fieldsChanged = const []});

  static StayEditResult? maybe(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    final result = OwnerJson.strOrNull(j['result']);
    if (result != 'Approved' && result != 'Rejected') return null;
    return StayEditResult(
      approved: result == 'Approved',
      reason: OwnerJson.strOrNull(j['reason']),
      at: OwnerJson.time(j['at']),
      fieldsChanged: OwnerJson.strings(j['fieldsChanged']),
    );
  }
}

class StayCalendarRow {
  final int thisMonthCount;
  final DateTime? nextDate;
  final String? nextLabel;

  const StayCalendarRow({this.thisMonthCount = 0, this.nextDate, this.nextLabel});

  static StayCalendarRow? maybe(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    final next = OwnerJson.map(j['next']);
    return StayCalendarRow(
      thisMonthCount: OwnerJson.integer(j['thisMonthCount']),
      nextDate: OwnerDates.day(next['date']),
      nextLabel: OwnerJson.strOrNull(next['label']),
    );
  }
}

class StaySpecialFirst {
  final String label;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final PriceDirection direction;
  final int? percent;

  const StaySpecialFirst({this.label = '', this.dateFrom, this.dateTo, this.direction = PriceDirection.unknown, this.percent});

  static const Map<String, PriceDirection> _dirs = {
    'Lower': PriceDirection.lower,
    'Higher': PriceDirection.higher,
    'lower': PriceDirection.lower,
    'higher': PriceDirection.higher,
  };

  static StaySpecialFirst? maybe(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    return StaySpecialFirst(
      label: OwnerJson.str(j['label']),
      dateFrom: OwnerDates.day(j['dateFrom']),
      dateTo: OwnerDates.day(j['dateTo']),
      direction: OwnerJson.pick(j['direction'], _dirs, PriceDirection.unknown),
      percent: OwnerJson.intOrNull(j['percent']),
    );
  }
}

class StaySpecialPricesRow {
  final int count;
  final int? limit;
  final StaySpecialFirst? first;

  const StaySpecialPricesRow({this.count = 0, this.limit, this.first});

  static StaySpecialPricesRow? maybe(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    return StaySpecialPricesRow(count: OwnerJson.integer(j['count']), limit: OwnerJson.intOrNull(j['limit']), first: StaySpecialFirst.maybe(j['first']));
  }
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
  final String? registrationTypeId;
  final String? registrationTypeName;
  final String? registrationOtherName;
  final String? registrationNumber;
  final bool hasRegistrationNumber;
  final bool hasGstin;
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
  final List<StayPhotoModel> hiddenPhotos;
  final List<StayRoomModel> hiddenRooms;
  final List<Meter> meters;
  final StayRulesModel? rules;
  final bool acceptingGuests;
  final String? rejectedReason;
  final int? minPricePerNight;
  final String? slug;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final int pendingReportCount;
  final bool everApproved;
  final String? upiId;
  final String? whatsAppNumber;
  final bool isFeatured;
  final StayPendingEdit? pendingEdit;
  final StayEditResult? lastEditResult;
  final int confirmedBookingCount;
  final bool remindersOn;
  final StayCalendarRow? calendarRow;
  final StaySpecialPricesRow? specialPricesRow;

  const StayOwnerModel({
    required this.id,
    required this.status,
    required this.step1Done,
    required this.roomsDone,
    required this.rulesDone,
    this.name,
    this.stayTypeId,
    this.stayTypeName,
    this.registrationTypeId,
    this.registrationTypeName,
    this.registrationOtherName,
    this.registrationNumber,
    this.hasRegistrationNumber = false,
    this.hasGstin = false,
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
    this.hiddenPhotos = const [],
    this.hiddenRooms = const [],
    this.meters = const [],
    this.rules,
    this.acceptingGuests = true,
    this.rejectedReason,
    this.minPricePerNight,
    this.slug,
    this.submittedAt,
    required this.createdAt,
    this.pendingReportCount = 0,
    this.everApproved = false,
    this.upiId,
    this.whatsAppNumber,
    this.isFeatured = false,
    this.pendingEdit,
    this.lastEditResult,
    this.confirmedBookingCount = 0,
    this.remindersOn = false,
    this.calendarRow,
    this.specialPricesRow,
  });

  bool get isDraft => status == StayStatus.draft;
  bool get isPendingReview => status == StayStatus.pendingReview;
  bool get isApproved => status == StayStatus.approved;
  bool get isRejected => status == StayStatus.rejected;
  bool get canEditSetup => isDraft || isRejected;
  bool get canEditLive => isApproved;
  bool get canEditRoomsAndRules => !isPendingReview;
  bool get takenDown => isRejected && everApproved;
  bool get hasShareDetails => (upiId ?? '').isNotEmpty || (whatsAppNumber ?? '').isNotEmpty;
  bool get registrationDone => registrationTypeId != null && hasRegistrationNumber;
  int get reportCount => pendingReportCount;

  int get setupPercent {
    final d1 = step1Done;
    final d2 = d1 && roomsDone;
    final d3 = d2 && rulesDone;
    final d4 = d3 && (isPendingReview || isApproved || (isRejected && (submittedAt != null || everApproved)));
    return (d1 ? 40 : 0) + (d2 ? 30 : 0) + (d3 ? 20 : 0) + (d4 ? 10 : 0);
  }

  String get locality => [cityName, districtName].where((e) => e != null && e.isNotEmpty).join(', ');

  Meter? meter(String key) => Meter.find(meters, key);

  factory StayOwnerModel.fromJson(Map<String, dynamic> json) {
    final rules = OwnerJson.mapOrNull(json['rules']);
    return StayOwnerModel(
      id: OwnerJson.str(json['id']),
      status: OwnerJson.strOrNull(json['status']) ?? StayStatus.draft,
      step1Done: json['step1Done'] == true,
      roomsDone: json['roomsDone'] == true,
      rulesDone: json['rulesDone'] == true,
      name: OwnerJson.strOrNull(json['name']),
      stayTypeId: OwnerJson.strOrNull(json['stayTypeId']),
      stayTypeName: OwnerJson.strOrNull(json['stayTypeName']),
      registrationTypeId: OwnerJson.strOrNull(json['registrationTypeId']),
      registrationTypeName: OwnerJson.strOrNull(json['registrationTypeName']),
      registrationOtherName: OwnerJson.strOrNull(json['registrationOtherName']),
      registrationNumber: OwnerJson.strOrNull(json['registrationNumber']),
      hasRegistrationNumber: json['hasRegistrationNumber'] == true,
      hasGstin: json['hasGstin'] == true,
      vehicleAccess: OwnerJson.strOrNull(json['vehicleAccess']),
      hostLivesHere: OwnerJson.boolOrNull(json['hostLivesHere']),
      facilities: OwnerJson.strings(json['facilities']),
      description: OwnerJson.strOrNull(json['description']),
      latitude: OwnerJson.doubleOrNull(json['latitude']),
      longitude: OwnerJson.doubleOrNull(json['longitude']),
      address: OwnerJson.strOrNull(json['address']),
      districtId: OwnerJson.strOrNull(json['districtId']),
      districtName: OwnerJson.strOrNull(json['districtName']),
      cityId: OwnerJson.strOrNull(json['cityId']),
      cityName: OwnerJson.strOrNull(json['cityName']),
      photos: StayPhotoModel.listOf(json['photos']),
      rooms: StayRoomModel.listOf(json['rooms']),
      hiddenPhotos: StayPhotoModel.listOf(json['hiddenPhotos']),
      hiddenRooms: StayRoomModel.listOf(json['hiddenRooms']),
      meters: Meter.listOf(json['meters']),
      rules: rules == null ? null : StayRulesModel.fromJson(rules),
      acceptingGuests: OwnerJson.boolOrNull(json['acceptingGuests']) ?? true,
      rejectedReason: OwnerJson.strOrNull(json['rejectedReason']),
      minPricePerNight: OwnerJson.intOrNull(json['minPricePerNight']),
      slug: OwnerJson.strOrNull(json['slug']),
      submittedAt: OwnerJson.time(json['submittedAt']),
      createdAt: OwnerJson.time(json['createdAt']) ?? DateTime.now(),
      pendingReportCount: OwnerJson.intOrNull(json['reportCount']) ?? OwnerJson.integer(json['pendingReportCount']),
      everApproved: json['everApproved'] == true,
      upiId: OwnerJson.strOrNull(json['upiId']),
      whatsAppNumber: OwnerJson.strOrNull(json['whatsAppNumber']),
      isFeatured: OwnerJson.boolean(json['isFeatured']),
      pendingEdit: StayPendingEdit.maybe(json['pendingEdit']),
      lastEditResult: StayEditResult.maybe(json['lastEditResult']),
      confirmedBookingCount: OwnerJson.integer(json['confirmedBookingCount']),
      remindersOn: OwnerJson.boolean(json['remindersOn']),
      calendarRow: StayCalendarRow.maybe(json['calendarRow']),
      specialPricesRow: StaySpecialPricesRow.maybe(json['specialPricesRow']),
    );
  }
}
