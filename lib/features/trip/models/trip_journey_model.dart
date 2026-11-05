import '../../taxi/journeys/journey_models.dart';
import '../utils/trip_step_rules.dart';
import 'trip_plan_model.dart';

String _s(Object? v, [String d = '']) => v is String ? v : d;
String? _sn(Object? v) => v is String && v.isNotEmpty ? v : null;
double _d(Object? v) => v is num ? v.toDouble() : 0;
int? _i(Object? v) => v is num ? v.toInt() : null;

DateTime? _day(Object? v) {
  final d = v is String ? DateTime.tryParse(v) : null;
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String _wire(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TripJourneyLeg {
  final int legIndex;
  final String fromName;
  final String toName;
  final String? meetingPlace;
  final int? listedFare;
  final int carsNeeded;
  final bool partial;
  final bool driverAvailable;
  final String lastKnownStatus;
  final String? lastEnquiryId;
  final String? taxiId;
  final String driverName;
  final String? vehicleTypeName;
  final int? seats;
  final String? plateDisplay;
  final String? phone;
  final String? whatsApp;
  final String? backupTaxiId;
  final String? backupName;

  const TripJourneyLeg({
    required this.legIndex,
    required this.fromName,
    required this.toName,
    this.meetingPlace,
    this.listedFare,
    this.carsNeeded = 1,
    this.partial = false,
    this.driverAvailable = true,
    this.lastKnownStatus = 'Unknown',
    this.lastEnquiryId,
    this.taxiId,
    this.driverName = '',
    this.vehicleTypeName,
    this.seats,
    this.plateDisplay,
    this.phone,
    this.whatsApp,
    this.backupTaxiId,
    this.backupName,
  });

  bool get hasPhone => phone != null && phone!.isNotEmpty;

  bool get hasWhatsApp => whatsApp != null && whatsApp!.isNotEmpty;

  bool get isAsked => lastEnquiryId != null;

  String get changePlace => meetingPlace ?? fromName;

  factory TripJourneyLeg.fromJson(Map<String, dynamic> j) => TripJourneyLeg(
        legIndex: _i(j['legIndex']) ?? 1,
        fromName: _s(j['fromName']),
        toName: _s(j['toName']),
        meetingPlace: _sn(j['meetingPlace']),
        listedFare: _i(j['listedFare']),
        carsNeeded: _i(j['carsNeeded']) ?? 1,
        partial: j['partial'] == true,
        driverAvailable: j['driverAvailable'] is bool ? j['driverAvailable'] as bool : true,
        lastKnownStatus: _s(j['lastKnownStatus'], 'Unknown'),
        lastEnquiryId: _sn(j['lastEnquiryId']),
        taxiId: _sn(j['taxiId']),
        driverName: _s(j['driverName']),
        vehicleTypeName: _sn(j['vehicleTypeName']),
        seats: _i(j['seats']),
        plateDisplay: _sn(j['plateDisplay']),
        phone: _sn(j['phone']),
        whatsApp: _sn(j['whatsApp']),
        backupTaxiId: _sn(j['backupTaxiId']),
        backupName: _sn(j['backupName']),
      );

  factory TripJourneyLeg.fromSaved(SavedJourneyLeg l) {
    final backup = l.readyBackup;
    return TripJourneyLeg(
      legIndex: l.legIndex,
      fromName: l.fromName,
      toName: l.toName,
      meetingPlace: l.meetingPlace,
      listedFare: l.listedFare,
      partial: l.partial,
      driverAvailable: l.driverAvailable,
      lastKnownStatus: l.lastKnownStatus.wire,
      lastEnquiryId: l.lastEnquiryId,
      taxiId: l.driver.taxiId.isEmpty ? null : l.driver.taxiId,
      driverName: l.driver.driverName,
      vehicleTypeName: l.driver.vehicleTypeName.isEmpty ? null : l.driver.vehicleTypeName,
      seats: l.driver.seats,
      plateDisplay: l.driver.plateDisplay.isEmpty ? null : l.driver.plateDisplay,
      phone: l.driver.phone,
      whatsApp: l.driver.whatsApp,
      backupTaxiId: backup?.taxiId,
      backupName: backup?.driverName,
    );
  }

  Map<String, dynamic> toJson() => {
        'legIndex': legIndex,
        'fromName': fromName,
        'toName': toName,
        'meetingPlace': ?meetingPlace,
        'listedFare': ?listedFare,
        'carsNeeded': carsNeeded,
        'partial': partial,
        'driverAvailable': driverAvailable,
        'lastKnownStatus': lastKnownStatus,
        'lastEnquiryId': ?lastEnquiryId,
        'taxiId': ?taxiId,
        'driverName': driverName,
        'vehicleTypeName': ?vehicleTypeName,
        'seats': ?seats,
        'plateDisplay': ?plateDisplay,
        'phone': ?phone,
        'whatsApp': ?whatsApp,
        'backupTaxiId': ?backupTaxiId,
        'backupName': ?backupName,
      };
}

class TripJourney {
  final String id;
  final TripStepRole? role;
  final String fromName;
  final double fromLat;
  final double fromLng;
  final String toName;
  final double toLat;
  final double toLng;
  final DateTime date;
  final DateTime? expectedDate;
  final bool dateChanged;
  final bool startChanged;
  final int people;
  final int cars;
  final JourneyStatus status;
  final int? listedTotal;
  final bool anyAsked;
  final DateTime? lastRefreshedAt;
  final List<TripJourneyLeg> legs;

  const TripJourney({
    required this.id,
    this.role,
    required this.fromName,
    this.fromLat = 0,
    this.fromLng = 0,
    required this.toName,
    this.toLat = 0,
    this.toLng = 0,
    required this.date,
    this.expectedDate,
    this.dateChanged = false,
    this.startChanged = false,
    this.people = 1,
    this.cars = 1,
    this.status = JourneyStatus.notAsked,
    this.listedTotal,
    this.anyAsked = false,
    this.lastRefreshedAt,
    this.legs = const [],
  });

  bool get hasUnavailable => status == JourneyStatus.driverUnavailable || legs.any((l) => !l.driverAvailable);

  bool get needsAttention => hasUnavailable || dateChanged || startChanged;

  bool get isAsked => anyAsked || legs.any((l) => l.isAsked);

  List<String> get places => [
        fromName,
        for (final l in legs.skip(1)) l.changePlace,
        toName,
      ];

  TripJourneyLeg? get nextAfterFirst => legs.length > 1 ? legs[1] : null;

  TripJourney withFlags({TripStepRole? role, DateTime? expectedDate, required bool dateChanged, required bool startChanged}) =>
      TripJourney(
        id: id,
        role: role ?? this.role,
        fromName: fromName,
        fromLat: fromLat,
        fromLng: fromLng,
        toName: toName,
        toLat: toLat,
        toLng: toLng,
        date: date,
        expectedDate: expectedDate,
        dateChanged: dateChanged,
        startChanged: startChanged,
        people: people,
        cars: cars,
        status: status,
        listedTotal: listedTotal,
        anyAsked: anyAsked,
        lastRefreshedAt: lastRefreshedAt,
        legs: legs,
      );

  factory TripJourney.fromJson(Map<String, dynamic> j) {
    final legs = ((j['legs'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TripJourneyLeg.fromJson)
        .toList()
      ..sort((a, b) => a.legIndex.compareTo(b.legIndex));
    final now = DateTime.now();
    return TripJourney(
      id: _s(j['id']),
      role: TripStepRole.parse(j['role']),
      fromName: _s(j['fromName']),
      fromLat: _d(j['fromLat']),
      fromLng: _d(j['fromLng']),
      toName: _s(j['toName']),
      toLat: _d(j['toLat']),
      toLng: _d(j['toLng']),
      date: _day(j['date']) ?? DateTime(now.year, now.month, now.day),
      expectedDate: _day(j['expectedDate']),
      dateChanged: j['dateChanged'] == true,
      startChanged: j['startChanged'] == true,
      people: _i(j['people']) ?? 1,
      cars: _i(j['cars']) ?? (legs.isEmpty ? 1 : legs.length),
      status: JourneyStatus.parse(_sn(j['status'])),
      listedTotal: _i(j['listedTotal']),
      anyAsked: j['anyAsked'] == true,
      lastRefreshedAt: j['lastRefreshedAt'] is String ? DateTime.tryParse(j['lastRefreshedAt'] as String)?.toLocal() : null,
      legs: legs,
    );
  }

  factory TripJourney.fromSaved(SavedJourney j, TripStepRole role, {DateTime? expectedDate, TripStartFrom? startFrom}) {
    final legs = j.legs.map(TripJourneyLeg.fromSaved).toList();
    final base = TripJourney(
      id: j.id,
      role: role,
      fromName: j.fromName,
      fromLat: j.fromLat,
      fromLng: j.fromLng,
      toName: j.toName,
      toLat: j.toLat,
      toLng: j.toLng,
      date: j.date,
      people: j.people,
      cars: j.cars,
      status: j.status,
      listedTotal: j.listedTotal,
      anyAsked: j.anyAsked,
      lastRefreshedAt: j.lastRefreshedAt,
      legs: legs,
    );
    return base.withFlags(
      expectedDate: expectedDate,
      dateChanged: TripStepRules.dateChanged(expectedDate, j.date),
      startChanged: TripStepRules.startChanged(role, startFrom, base),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': ?role?.name,
        'fromName': fromName,
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toName': toName,
        'toLat': toLat,
        'toLng': toLng,
        'date': _wire(date),
        if (expectedDate != null) 'expectedDate': _wire(expectedDate!),
        'dateChanged': dateChanged,
        'startChanged': startChanged,
        'people': people,
        'cars': cars,
        'status': status.wire,
        'listedTotal': ?listedTotal,
        'anyAsked': anyAsked,
        'lastRefreshedAt': ?lastRefreshedAt?.toUtc().toIso8601String(),
        'legs': legs.map((l) => l.toJson()).toList(),
      };
}
