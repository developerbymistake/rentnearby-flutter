mixin WireEnum on Enum {
  String get wire;
}

T parseWireEnum<T extends WireEnum>(List<T> values, Object? raw, T unknown) {
  if (raw is! String) return unknown;
  for (final v in values) {
    if (v.wire == raw) return v;
  }
  return unknown;
}

enum RequestState with WireEnum {
  open('Open'),
  collecting('Collecting'),
  selected('Selected'),
  booked('Booked'),
  inProgress('InProgress'),
  completed('Completed'),
  cancelled('Cancelled'),
  expired('Expired'),
  unknown('');

  const RequestState(this.wire);
  @override
  final String wire;

  bool get active => index <= RequestState.inProgress.index;

  static RequestState parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

enum RequestView with WireEnum {
  finding('Finding'),
  findingWaiting('FindingWaiting'),
  noReply('NoReply'),
  collecting('Collecting'),
  selected('Selected'),
  booked('Booked'),
  inProgress('InProgress'),
  rate('Rate'),
  done('Done'),
  busy('Busy'),
  ended('Ended'),
  unknown('');

  const RequestView(this.wire);
  @override
  final String wire;

  static RequestView parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

enum RequestEndReason with WireEnum {
  travellerCancelled('TravellerCancelled'),
  pickupChanged('PickupChanged'),
  bookingCancelledByTraveller('BookingCancelledByTraveller'),
  driverLeftTrip('DriverLeftTrip'),
  adminCancelled('AdminCancelled'),
  accountClosed('AccountClosed'),
  allDriversBusy('AllDriversBusy'),
  notBooked('NotBooked'),
  unknown('');

  const RequestEndReason(this.wire);
  @override
  final String wire;

  static RequestEndReason parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

enum OfferState with WireEnum {
  ringing('Ringing'),
  accepted('Accepted'),
  declined('Declined'),
  missed('Missed'),
  selected('Selected'),
  notSelected('NotSelected'),
  notAgreed('NotAgreed'),
  confirmed('Confirmed'),
  withdrawn('Withdrawn'),
  closed('Closed'),
  unknown('');

  const OfferState(this.wire);
  @override
  final String wire;

  static OfferState parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

enum BookingState with WireEnum {
  booked('Booked'),
  inProgress('InProgress'),
  completed('Completed'),
  cancelled('Cancelled'),
  unknown('');

  const BookingState(this.wire);
  @override
  final String wire;

  static BookingState parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

enum ReasonChip with WireEnum {
  changedPlan('ChangedPlan'),
  notReachable('NotReachable'),
  priceNotAgreed('PriceNotAgreed'),
  vehicleIssue('VehicleIssue'),
  other('Other'),
  unknown('');

  const ReasonChip(this.wire);
  @override
  final String wire;

  static ReasonChip parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

class TaxiSeats {
  static const List<int> options = [4, 6, 7];

  static int forTravellers(int travellers) => travellers <= 4 ? 4 : (travellers <= 6 ? 6 : 7);

  static int snap(int seats) => options.contains(seats) ? seats : forTravellers(seats);
}

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

bool _bool(Object? v) => v == true;

String _str(Object? v) => v is String ? v : '';

String? _strOrNull(Object? v) => v is String ? v : null;

Map<String, dynamic> _map(Object? v) => v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : const {});

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) =>
    v is List ? [for (final e in v) if (e is Map) parse(_map(e))] : const [];

class TaxiCityRef {
  final int cityKey;
  final String name;

  const TaxiCityRef({required this.cityKey, required this.name});

  factory TaxiCityRef.fromJson(Map<String, dynamic> j) => TaxiCityRef(cityKey: _int(j['cityKey']), name: _str(j['name']));

  Map<String, dynamic> toJson() => {'cityKey': cityKey, 'name': name};
}

class TaxiPickupPlace {
  final int cityKey;
  final String name;
  final int drivers;

  const TaxiPickupPlace({required this.cityKey, required this.name, required this.drivers});

  factory TaxiPickupPlace.fromJson(Map<String, dynamic> j) =>
      TaxiPickupPlace(cityKey: _int(j['cityKey']), name: _str(j['name']), drivers: _int(j['drivers']));

  Map<String, dynamic> toJson() => {'cityKey': cityKey, 'name': name, 'drivers': drivers};
}

class TaxiPickupPlaces {
  final bool paused;
  final TaxiCityRef firstCity;
  final TaxiCityRef lastCity;
  final List<TaxiPickupPlace> pickup;
  final List<TaxiPickupPlace> drop;
  final int sightseeingDrivers;
  final int travellers;
  final int suggestedSeats;

  const TaxiPickupPlaces({
    required this.paused,
    required this.firstCity,
    required this.lastCity,
    required this.pickup,
    required this.drop,
    required this.sightseeingDrivers,
    required this.travellers,
    required this.suggestedSeats,
  });

  factory TaxiPickupPlaces.fromJson(Map<String, dynamic> j) => TaxiPickupPlaces(
        paused: _bool(j['paused']),
        firstCity: TaxiCityRef.fromJson(_map(j['firstCity'])),
        lastCity: TaxiCityRef.fromJson(_map(j['lastCity'])),
        pickup: _list(j['pickup'], TaxiPickupPlace.fromJson),
        drop: _list(j['drop'], TaxiPickupPlace.fromJson),
        sightseeingDrivers: _int(j['sightseeingDrivers']),
        travellers: _int(j['travellers']),
        suggestedSeats: TaxiSeats.snap(_int(j['suggestedSeats'], 4)),
      );

  Map<String, dynamic> toJson() => {
        'paused': paused,
        'firstCity': firstCity.toJson(),
        'lastCity': lastCity.toJson(),
        'pickup': [for (final p in pickup) p.toJson()],
        'drop': [for (final p in drop) p.toJson()],
        'sightseeingDrivers': sightseeingDrivers,
        'travellers': travellers,
        'suggestedSeats': suggestedSeats,
      };

  TaxiPickupPlace? pickupByKey(int? key) => _byKey(pickup, key);

  TaxiPickupPlace? dropByKey(int? key) => _byKey(drop, key);

  static TaxiPickupPlace? _byKey(List<TaxiPickupPlace> list, int? key) {
    if (key == null) return null;
    for (final p in list) {
      if (p.cityKey == key) return p;
    }
    return null;
  }
}

class TaxiDayStat {
  final int day;
  final int km;
  final int minutes;

  const TaxiDayStat({required this.day, required this.km, required this.minutes});

  Map<String, dynamic> toJson() => {'day': day, 'km': km, 'minutes': minutes};
}

class TaxiRequestSections {
  final bool pickup;
  final bool sightseeing;
  final bool drop;

  const TaxiRequestSections({required this.pickup, required this.sightseeing, required this.drop});

  factory TaxiRequestSections.fromJson(Map<String, dynamic> j) =>
      TaxiRequestSections(pickup: _bool(j['pickup']), sightseeing: _bool(j['sightseeing']), drop: _bool(j['drop']));

  Map<String, dynamic> toJson() => {'pickup': pickup, 'sightseeing': sightseeing, 'drop': drop};
}

class TaxiRequestDrop {
  final int cityKey;
  final String name;
  final bool sameAsPickup;

  const TaxiRequestDrop({required this.cityKey, required this.name, required this.sameAsPickup});

  factory TaxiRequestDrop.fromJson(Map<String, dynamic> j) =>
      TaxiRequestDrop(cityKey: _int(j['cityKey']), name: _str(j['name']), sameAsPickup: _bool(j['sameAsPickup']));

  Map<String, dynamic> toJson() => {'cityKey': cityKey, 'name': name, 'sameAsPickup': sameAsPickup};
}

class TaxiDriverCard {
  final String offerId;
  final String stateText;
  final String name;
  final String? phone;
  final String vehicle;
  final int seats;
  final double? ratingAverage;
  final int ratingCount;
  final int ridesCompleted;
  final bool canSelect;
  final String? confirmBy;

  const TaxiDriverCard({
    required this.offerId,
    required this.stateText,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.seats,
    required this.ratingAverage,
    required this.ratingCount,
    required this.ridesCompleted,
    required this.canSelect,
    required this.confirmBy,
  });

  factory TaxiDriverCard.fromJson(Map<String, dynamic> j) => TaxiDriverCard(
        offerId: _str(j['offerId']),
        stateText: _str(j['state']),
        name: _str(j['name']),
        phone: _strOrNull(j['phone']),
        vehicle: _str(j['vehicle']),
        seats: _int(j['seats']),
        ratingAverage: j['ratingAverage'] is num ? (j['ratingAverage'] as num).toDouble() : null,
        ratingCount: _int(j['ratingCount']),
        ridesCompleted: _int(j['ridesCompleted']),
        canSelect: _bool(j['canSelect']),
        confirmBy: _strOrNull(j['confirmBy']),
      );

  Map<String, dynamic> toJson() => {
        'offerId': offerId,
        'state': stateText,
        'name': name,
        'phone': phone,
        'vehicle': vehicle,
        'seats': seats,
        'ratingAverage': ratingAverage,
        'ratingCount': ratingCount,
        'ridesCompleted': ridesCompleted,
        'canSelect': canSelect,
        'confirmBy': confirmBy,
      };

  OfferState get state => OfferState.parse(stateText);

  DateTime? get confirmByAt => _instant(confirmBy);
}

class TaxiBooking {
  final String id;
  final String stateText;
  final String dateFrom;
  final String dateTo;
  final int? dayNumber;
  final bool canCancel;
  final bool canEnd;

  const TaxiBooking({
    required this.id,
    required this.stateText,
    required this.dateFrom,
    required this.dateTo,
    required this.dayNumber,
    required this.canCancel,
    required this.canEnd,
  });

  factory TaxiBooking.fromJson(Map<String, dynamic> j) => TaxiBooking(
        id: _str(j['id']),
        stateText: _str(j['state']),
        dateFrom: _str(j['dateFrom']),
        dateTo: _str(j['dateTo']),
        dayNumber: j['dayNumber'] is num ? (j['dayNumber'] as num).toInt() : null,
        canCancel: _bool(j['canCancel']),
        canEnd: _bool(j['canEnd']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': stateText,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'dayNumber': dayNumber,
        'canCancel': canCancel,
        'canEnd': canEnd,
      };

  BookingState get state => BookingState.parse(stateText);

  DateTime? get from => _day(dateFrom);

  DateTime? get to => _day(dateTo);
}

class TaxiRating {
  final int stars;
  final String ratedAt;

  const TaxiRating({required this.stars, required this.ratedAt});

  factory TaxiRating.fromJson(Map<String, dynamic> j) => TaxiRating(stars: _int(j['stars']), ratedAt: _str(j['ratedAt']));

  Map<String, dynamic> toJson() => {'stars': stars, 'ratedAt': ratedAt};
}

DateTime? _instant(String? raw) => raw == null ? null : DateTime.tryParse(raw)?.toUtc();

DateTime? _day(String raw) {
  final d = DateTime.tryParse(raw);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

class TaxiRequest {
  final String id;
  final String tripId;
  final String tripName;
  final String stateText;
  final String viewText;
  final int version;
  final String? endReasonText;
  final TaxiRequestSections sections;
  final TaxiCityRef? pickup;
  final TaxiRequestDrop? drop;
  final int seats;
  final int travellers;
  final String dateFrom;
  final String dateTo;
  final int dayCount;
  final List<int> sightseeingDays;
  final int askedCount;
  final int ringingCount;
  final int acceptedCount;
  final bool stillAsking;
  final bool canAskMore;
  final bool canCancel;
  final String? waitUntil;
  final List<TaxiDriverCard> drivers;
  final TaxiBooking? booking;
  final TaxiRating? rating;
  final String createdAt;
  final String updatedAt;

  const TaxiRequest({
    required this.id,
    required this.tripId,
    required this.tripName,
    required this.stateText,
    required this.viewText,
    required this.version,
    required this.endReasonText,
    required this.sections,
    required this.pickup,
    required this.drop,
    required this.seats,
    required this.travellers,
    required this.dateFrom,
    required this.dateTo,
    required this.dayCount,
    required this.sightseeingDays,
    required this.askedCount,
    required this.ringingCount,
    required this.acceptedCount,
    required this.stillAsking,
    required this.canAskMore,
    required this.canCancel,
    required this.waitUntil,
    required this.drivers,
    required this.booking,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaxiRequest.fromJson(Map<String, dynamic> j) => TaxiRequest(
        id: _str(j['id']),
        tripId: _str(j['tripId']),
        tripName: _str(j['tripName']),
        stateText: _str(j['state']),
        viewText: _str(j['view']),
        version: _int(j['version']),
        endReasonText: _strOrNull(j['endReason']),
        sections: TaxiRequestSections.fromJson(_map(j['sections'])),
        pickup: j['pickup'] is Map ? TaxiCityRef.fromJson(_map(j['pickup'])) : null,
        drop: j['drop'] is Map ? TaxiRequestDrop.fromJson(_map(j['drop'])) : null,
        seats: _int(j['seats']),
        travellers: _int(j['travellers']),
        dateFrom: _str(j['dateFrom']),
        dateTo: _str(j['dateTo']),
        dayCount: _int(j['dayCount']),
        sightseeingDays: [for (final d in (j['sightseeingDays'] is List ? j['sightseeingDays'] as List : const [])) _int(d)],
        askedCount: _int(j['askedCount']),
        ringingCount: _int(j['ringingCount']),
        acceptedCount: _int(j['acceptedCount']),
        stillAsking: _bool(j['stillAsking']),
        canAskMore: _bool(j['canAskMore']),
        canCancel: _bool(j['canCancel']),
        waitUntil: _strOrNull(j['waitUntil']),
        drivers: _list(j['drivers'], TaxiDriverCard.fromJson),
        booking: j['booking'] is Map ? TaxiBooking.fromJson(_map(j['booking'])) : null,
        rating: j['rating'] is Map ? TaxiRating.fromJson(_map(j['rating'])) : null,
        createdAt: _str(j['createdAt']),
        updatedAt: _str(j['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'tripName': tripName,
        'state': stateText,
        'view': viewText,
        'version': version,
        'endReason': endReasonText,
        'sections': sections.toJson(),
        'pickup': pickup?.toJson(),
        'drop': drop?.toJson(),
        'seats': seats,
        'travellers': travellers,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'dayCount': dayCount,
        'sightseeingDays': sightseeingDays,
        'askedCount': askedCount,
        'ringingCount': ringingCount,
        'acceptedCount': acceptedCount,
        'stillAsking': stillAsking,
        'canAskMore': canAskMore,
        'canCancel': canCancel,
        'waitUntil': waitUntil,
        'drivers': [for (final d in drivers) d.toJson()],
        'booking': booking?.toJson(),
        'rating': rating?.toJson(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  RequestState get state => RequestState.parse(stateText);

  RequestView get view => RequestView.parse(viewText);

  RequestEndReason? get endReason => endReasonText == null ? null : RequestEndReason.parse(endReasonText);

  DateTime? get from => _day(dateFrom);

  DateTime? get to => _day(dateTo);

  DateTime? get waitUntilAt => _instant(waitUntil);

  TaxiDriverCard? get selectedDriver {
    for (final d in drivers) {
      if (d.state == OfferState.selected || d.state == OfferState.confirmed) return d;
    }
    return null;
  }
}
