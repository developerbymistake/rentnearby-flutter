import '../ways/taxi_ways_strings.dart';
import 'journey_strings.dart';

String _str(dynamic v, [String d = '']) => v is String ? v : d;
String? _strN(dynamic v) => v is String && v.isNotEmpty ? v : null;
double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int? _int(dynamic v) => v is num ? v.toInt() : null;
bool _bool(dynamic v, bool d) => v is bool ? v : d;
DateTime? _time(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

DateTime _day(dynamic v) {
  final parsed = v is String ? DateTime.tryParse(v) : null;
  final d = parsed ?? DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

String _dayWire(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

typedef JourneyPhones = Map<String, Map<String, String>>;

enum JourneyStatus {
  ready,
  driverUnavailable,
  notAsked,
  completed;

  static JourneyStatus parse(String? wire) => switch (wire) {
        'DriverUnavailable' => driverUnavailable,
        'NotAsked' => notAsked,
        'Completed' => completed,
        _ => ready,
      };

  String get wire => switch (this) {
        ready => 'Ready',
        driverUnavailable => 'DriverUnavailable',
        notAsked => 'NotAsked',
        completed => 'Completed',
      };
}

enum LegStatus {
  free,
  notFree,
  noAnswer,
  unknown;

  static LegStatus parse(String? wire) => switch (wire) {
        'Free' => free,
        'NotFree' => notFree,
        'NoAnswer' => noAnswer,
        _ => unknown,
      };

  String get wire => switch (this) {
        free => 'Free',
        notFree => 'NotFree',
        noAnswer => 'NoAnswer',
        unknown => 'Unknown',
      };
}

class JourneyContact {
  final String taxiId;
  final String driverName;
  final String vehicleTypeName;
  final int? seats;
  final String plateDisplay;
  final String? cityName;
  final String tripReplyLabel;
  final String? phone;
  final String? whatsApp;
  final bool available;

  const JourneyContact({
    required this.taxiId,
    required this.driverName,
    this.vehicleTypeName = '',
    this.seats,
    this.plateDisplay = '',
    this.cityName,
    this.tripReplyLabel = 'new',
    this.phone,
    this.whatsApp,
    this.available = true,
  });

  factory JourneyContact.fromJson(Map<String, dynamic> j) => JourneyContact(
        taxiId: _str(j['taxiId']),
        driverName: _str(j['driverName'], 'Driver'),
        vehicleTypeName: _str(j['vehicleTypeName']),
        seats: _int(j['seats']),
        plateDisplay: _str(j['plateDisplay']),
        cityName: _strN(j['cityName']),
        tripReplyLabel: _str(j['tripReplyLabel'], 'new'),
        phone: _strN(j['phone']),
        whatsApp: _strN(j['whatsApp']),
        available: _bool(j['available'], true),
      );

  Map<String, dynamic> toJson({bool includeContacts = true}) => {
        'taxiId': taxiId,
        'driverName': driverName,
        'vehicleTypeName': vehicleTypeName,
        'seats': ?seats,
        'plateDisplay': plateDisplay,
        'cityName': ?cityName,
        'tripReplyLabel': tripReplyLabel,
        'phone': ?(includeContacts ? phone : null),
        'whatsApp': ?(includeContacts ? whatsApp : null),
        'available': available,
      };

  bool get hasPhone => phone != null && phone!.isNotEmpty;
  bool get hasWhatsApp => whatsApp != null && whatsApp!.isNotEmpty;

  String get initial => driverName.trim().isEmpty ? '?' : driverName.trim()[0].toUpperCase();

  JourneyContact withPhones(String? p, String? w) => JourneyContact(
        taxiId: taxiId,
        driverName: driverName,
        vehicleTypeName: vehicleTypeName,
        seats: seats,
        plateDisplay: plateDisplay,
        cityName: cityName,
        tripReplyLabel: tripReplyLabel,
        phone: phone ?? p,
        whatsApp: whatsApp ?? w,
        available: available,
      );
}

class SavedJourneyLeg {
  final int legIndex;
  final String legKey;
  final String fromName;
  final double fromLat;
  final double fromLng;
  final String toName;
  final double toLat;
  final double toLng;
  final String? meetingPlace;
  final JourneyContact driver;
  final List<JourneyContact> backups;
  final int? listedFare;
  final bool partial;
  final String? lastEnquiryId;
  final LegStatus lastKnownStatus;
  final int? lastQuotedFare;
  final DateTime? lastKnownAt;
  final bool driverAvailable;
  final bool fareChanged;
  final int? previousFare;

  const SavedJourneyLeg({
    required this.legIndex,
    required this.legKey,
    required this.fromName,
    this.fromLat = 0,
    this.fromLng = 0,
    required this.toName,
    this.toLat = 0,
    this.toLng = 0,
    this.meetingPlace,
    required this.driver,
    this.backups = const [],
    this.listedFare,
    this.partial = false,
    this.lastEnquiryId,
    this.lastKnownStatus = LegStatus.unknown,
    this.lastQuotedFare,
    this.lastKnownAt,
    this.driverAvailable = true,
    this.fareChanged = false,
    this.previousFare,
  });

  factory SavedJourneyLeg.fromJson(Map<String, dynamic> j) {
    final driver = j['driver'];
    final backups = j['backups'];
    return SavedJourneyLeg(
      legIndex: _int(j['legIndex']) ?? 1,
      legKey: _str(j['legKey']),
      fromName: _str(j['fromName']),
      fromLat: _num(j['fromLat']),
      fromLng: _num(j['fromLng']),
      toName: _str(j['toName']),
      toLat: _num(j['toLat']),
      toLng: _num(j['toLng']),
      meetingPlace: _strN(j['meetingPlace']),
      driver: JourneyContact.fromJson(driver is Map<String, dynamic> ? driver : const {}),
      backups: backups is List
          ? backups.whereType<Map<String, dynamic>>().map(JourneyContact.fromJson).toList()
          : const [],
      listedFare: _int(j['listedFare']),
      partial: _bool(j['partial'], false),
      lastEnquiryId: _strN(j['lastEnquiryId']),
      lastKnownStatus: LegStatus.parse(_strN(j['lastKnownStatus'])),
      lastQuotedFare: _int(j['lastQuotedFare']),
      lastKnownAt: _time(j['lastKnownAt']),
      driverAvailable: _bool(j['driverAvailable'], true),
      fareChanged: _bool(j['fareChanged'], false),
      previousFare: _int(j['previousFare']),
    );
  }

  Map<String, dynamic> toJson({bool includeContacts = true}) => {
        'legIndex': legIndex,
        'legKey': legKey,
        'fromName': fromName,
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toName': toName,
        'toLat': toLat,
        'toLng': toLng,
        'meetingPlace': ?meetingPlace,
        'driver': driver.toJson(includeContacts: includeContacts),
        'backups': backups.map((b) => b.toJson(includeContacts: includeContacts)).toList(),
        'listedFare': ?listedFare,
        'partial': partial,
        'lastEnquiryId': ?lastEnquiryId,
        'lastKnownStatus': lastKnownStatus.wire,
        'lastQuotedFare': ?lastQuotedFare,
        'lastKnownAt': ?lastKnownAt?.toUtc().toIso8601String(),
        'driverAvailable': driverAvailable,
        'fareChanged': fareChanged,
        'previousFare': ?previousFare,
      };

  SavedJourneyLeg copyWith({
    JourneyContact? driver,
    List<JourneyContact>? backups,
    String? lastEnquiryId,
    LegStatus? lastKnownStatus,
    int? lastQuotedFare,
    DateTime? lastKnownAt,
    int? previousFare,
    bool clearPreviousFare = false,
  }) =>
      SavedJourneyLeg(
        legIndex: legIndex,
        legKey: legKey,
        fromName: fromName,
        fromLat: fromLat,
        fromLng: fromLng,
        toName: toName,
        toLat: toLat,
        toLng: toLng,
        meetingPlace: meetingPlace,
        driver: driver ?? this.driver,
        backups: backups ?? this.backups,
        listedFare: listedFare,
        partial: partial,
        lastEnquiryId: lastEnquiryId ?? this.lastEnquiryId,
        lastKnownStatus: lastKnownStatus ?? this.lastKnownStatus,
        lastQuotedFare: lastQuotedFare ?? this.lastQuotedFare,
        lastKnownAt: lastKnownAt ?? this.lastKnownAt,
        driverAvailable: driverAvailable,
        fareChanged: fareChanged,
        previousFare: clearPreviousFare ? null : (previousFare ?? this.previousFare),
      );

  SavedJourneyLeg withContacts(JourneyPhones phones) {
    JourneyContact fill(JourneyContact c) {
      final p = phones[c.taxiId];
      return p == null ? c : c.withPhones(p['phone'], p['whatsApp']);
    }

    return SavedJourneyLeg(
      legIndex: legIndex,
      legKey: legKey,
      fromName: fromName,
      fromLat: fromLat,
      fromLng: fromLng,
      toName: toName,
      toLat: toLat,
      toLng: toLng,
      meetingPlace: meetingPlace,
      driver: fill(driver),
      backups: backups.map(fill).toList(),
      listedFare: listedFare,
      partial: partial,
      lastEnquiryId: lastEnquiryId,
      lastKnownStatus: lastKnownStatus,
      lastQuotedFare: lastQuotedFare,
      lastKnownAt: lastKnownAt,
      driverAvailable: driverAvailable,
      fareChanged: fareChanged,
      previousFare: previousFare,
    );
  }

  bool get isAsked => lastEnquiryId != null;

  JourneyContact? get readyBackup {
    for (final b in backups) {
      if (b.available) return b;
    }
    return null;
  }

  Iterable<JourneyContact> get contacts => [driver, ...backups];
}

class SavedJourney {
  final String id;
  final String fromName;
  final double fromLat;
  final double fromLng;
  final String toName;
  final double toLat;
  final double toLng;
  final DateTime date;
  final int people;
  final String planKey;
  final int cars;
  final JourneyStatus status;
  final int? listedTotal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRefreshedAt;
  final List<SavedJourneyLeg> legs;
  final DateTime? savedLocallyAt;

  const SavedJourney({
    required this.id,
    required this.fromName,
    this.fromLat = 0,
    this.fromLng = 0,
    required this.toName,
    this.toLat = 0,
    this.toLng = 0,
    required this.date,
    required this.people,
    this.planKey = '',
    required this.cars,
    required this.status,
    this.listedTotal,
    required this.createdAt,
    required this.updatedAt,
    this.lastRefreshedAt,
    this.legs = const [],
    this.savedLocallyAt,
  });

  factory SavedJourney.fromJson(Map<String, dynamic> j) {
    final legs = j['legs'] is List
        ? (j['legs'] as List).whereType<Map<String, dynamic>>().map(SavedJourneyLeg.fromJson).toList()
        : <SavedJourneyLeg>[];
    legs.sort((a, b) => a.legIndex.compareTo(b.legIndex));
    final now = DateTime.now();
    return SavedJourney(
      id: _str(j['id']),
      fromName: _str(j['fromName']),
      fromLat: _num(j['fromLat']),
      fromLng: _num(j['fromLng']),
      toName: _str(j['toName']),
      toLat: _num(j['toLat']),
      toLng: _num(j['toLng']),
      date: _day(j['date']),
      people: _int(j['people']) ?? 1,
      planKey: _str(j['planKey']),
      cars: _int(j['cars']) ?? legs.length,
      status: JourneyStatus.parse(_strN(j['status'])),
      listedTotal: _int(j['listedTotal']),
      createdAt: _time(j['createdAt']) ?? now,
      updatedAt: _time(j['updatedAt']) ?? now,
      lastRefreshedAt: _time(j['lastRefreshedAt']),
      legs: legs,
      savedLocallyAt: _time(j['savedLocallyAt']),
    );
  }

  Map<String, dynamic> toJson({bool includeContacts = true}) => {
        'id': id,
        'fromName': fromName,
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toName': toName,
        'toLat': toLat,
        'toLng': toLng,
        'date': _dayWire(date),
        'people': people,
        'planKey': planKey,
        'cars': cars,
        'status': status.wire,
        'listedTotal': ?listedTotal,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'lastRefreshedAt': ?lastRefreshedAt?.toUtc().toIso8601String(),
        'legs': legs.map((l) => l.toJson(includeContacts: includeContacts)).toList(),
        'savedLocallyAt': ?savedLocallyAt?.toUtc().toIso8601String(),
      };

  SavedJourney copyWith({JourneyStatus? status, List<SavedJourneyLeg>? legs, DateTime? savedLocallyAt}) => SavedJourney(
        id: id,
        fromName: fromName,
        fromLat: fromLat,
        fromLng: fromLng,
        toName: toName,
        toLat: toLat,
        toLng: toLng,
        date: date,
        people: people,
        planKey: planKey,
        cars: cars,
        status: status ?? this.status,
        listedTotal: listedTotal,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastRefreshedAt: lastRefreshedAt,
        legs: legs ?? this.legs,
        savedLocallyAt: savedLocallyAt ?? this.savedLocallyAt,
      );

  SavedJourney withContacts(JourneyPhones phones) => copyWith(legs: legs.map((l) => l.withContacts(phones)).toList());

  bool get isCompleted => status == JourneyStatus.completed;
  int get unavailableCount => legs.where((l) => !l.driverAvailable).length;
  bool get hasUnavailable => unavailableCount > 0;
  bool get anyAsked => legs.any((l) => l.isAsked);

  SavedJourneyLeg? get firstUnavailable {
    for (final l in legs) {
      if (!l.driverAvailable) return l;
    }
    return null;
  }

  SavedJourneyLeg? leg(int index) {
    for (final l in legs) {
      if (l.legIndex == index) return l;
    }
    return null;
  }

  static int compare(SavedJourney a, SavedJourney b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    if (a.isCompleted) return b.date.compareTo(a.date);
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : b.updatedAt.compareTo(a.updatedAt);
  }
}

class JourneyFormat {
  const JourneyFormat._();

  static String wireDate(DateTime d) => _dayWire(d);

  static String route(SavedJourney j) => TaxiWaysStrings.subtitle(j.fromName, j.toName);

  static String line(SavedJourney j) => TaxiWaysStrings.journeyLine(j.date, j.cars, j.people);

  static String statusText(SavedJourney j) => switch (j.status) {
        JourneyStatus.ready => TaxiWaysStrings.statusReady,
        JourneyStatus.driverUnavailable => TaxiWaysStrings.statusUnavailable(j.unavailableCount < 1 ? 1 : j.unavailableCount),
        JourneyStatus.notAsked => TaxiWaysStrings.statusNotAsked,
        JourneyStatus.completed => TaxiWaysStrings.statusCompleted,
      };

  static String statusLine(SavedJourneyLeg leg, DateTime now) {
    final ago = TaxiWaysStrings.ago(leg.lastKnownAt ?? now, now: now);
    return switch (leg.lastKnownStatus) {
      LegStatus.free => TaxiWaysStrings.legFree(ago),
      LegStatus.notFree => TaxiWaysStrings.legNotFree,
      LegStatus.noAnswer => TaxiWaysStrings.legNoAnswer(ago),
      LegStatus.unknown => TaxiWaysStrings.legNotAsked,
    };
  }

  static String driverLine(JourneyContact c) => [
        if (c.vehicleTypeName.isNotEmpty) c.vehicleTypeName,
        if (c.seats != null) JourneyStrings.seatsLabel(c.seats!),
        if (c.plateDisplay.isNotEmpty) c.plateDisplay,
      ].join(' · ');

  static String? checked(SavedJourney j, DateTime now) {
    final at = j.lastRefreshedAt;
    return at == null ? null : TaxiWaysStrings.checkedAgo(TaxiWaysStrings.ago(at, now: now));
  }

  static String askLabel(SavedJourney j) {
    final n = j.legs.length;
    if (n <= 1) return TaxiWaysStrings.askOne;
    return n == 2 ? TaxiWaysStrings.askBoth : TaxiWaysStrings.askAll(n);
  }
}
