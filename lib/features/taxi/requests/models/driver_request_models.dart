import '../../../trip/models/taxi_request_models.dart';

export '../../../trip/models/taxi_request_models.dart' show BookingState, OfferState, ReasonChip, TaxiRequestSections, WireEnum;

enum OfferBucket with WireEnum {
  newOffers('New'),
  booked('Booked'),
  earlier('Earlier'),
  unknown('');

  const OfferBucket(this.wire);
  @override
  final String wire;

  static OfferBucket parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

enum OfferEndReason with WireEnum {
  expired('Expired'),
  filled('Filled'),
  confirmTimeout('ConfirmTimeout'),
  declinedBooking('DeclinedBooking'),
  requestCancelled('RequestCancelled'),
  requestExpired('RequestExpired'),
  booked('Booked'),
  driverOffline('DriverOffline'),
  listingRemoved('ListingRemoved'),
  unknown('');

  const OfferEndReason(this.wire);
  @override
  final String wire;

  static OfferEndReason parse(Object? raw) => parseWireEnum(values, raw, unknown);
}

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

bool _bool(Object? v) => v == true;

String _str(Object? v) => v is String ? v : '';

String? _strOrNull(Object? v) => v is String ? v : null;

double? _doubleOrNull(Object? v) => v is num ? v.toDouble() : null;

Map<String, dynamic> _map(Object? v) => v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : const {});

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) =>
    v is List ? [for (final e in v) if (e is Map) parse(_map(e))] : const [];

DateTime? _instant(String? raw) => raw == null ? null : DateTime.tryParse(raw)?.toUtc();

DateTime? _day(String? raw) => raw == null ? null : DateTime.tryParse(raw);

class DriverTraveller {
  final String name;
  final String? phone;

  const DriverTraveller({required this.name, required this.phone});

  factory DriverTraveller.fromJson(Map<String, dynamic> j) =>
      DriverTraveller(name: _str(j['name']), phone: _strOrNull(j['phone']));

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

class DriverDatesConflict {
  final String from;
  final String to;

  const DriverDatesConflict({required this.from, required this.to});

  factory DriverDatesConflict.fromJson(Map<String, dynamic> j) =>
      DriverDatesConflict(from: _str(j['from']), to: _str(j['to']));

  Map<String, dynamic> toJson() => {'from': from, 'to': to};

  DateTime? get fromDay => _day(from);

  DateTime? get toDay => _day(to);
}

class DriverTripStop {
  final String name;
  final String date;

  const DriverTripStop({required this.name, required this.date});

  factory DriverTripStop.fromJson(Map<String, dynamic> j) => DriverTripStop(name: _str(j['name']), date: _str(j['date']));

  Map<String, dynamic> toJson() => {'name': name, 'date': date};
}

class DriverTripDrop {
  final String name;
  final bool sameAsPickup;
  final String date;

  const DriverTripDrop({required this.name, required this.sameAsPickup, required this.date});

  factory DriverTripDrop.fromJson(Map<String, dynamic> j) =>
      DriverTripDrop(name: _str(j['name']), sameAsPickup: _bool(j['sameAsPickup']), date: _str(j['date']));

  Map<String, dynamic> toJson() => {'name': name, 'sameAsPickup': sameAsPickup, 'date': date};
}

class DriverTripCity {
  final String name;
  final int nights;
  final String from;
  final String to;

  const DriverTripCity({required this.name, required this.nights, required this.from, required this.to});

  factory DriverTripCity.fromJson(Map<String, dynamic> j) =>
      DriverTripCity(name: _str(j['name']), nights: _int(j['nights']), from: _str(j['from']), to: _str(j['to']));

  Map<String, dynamic> toJson() => {'name': name, 'nights': nights, 'from': from, 'to': to};
}

class DriverTripDay {
  final int day;
  final String date;
  final String city;
  final bool taxi;
  final int km;
  final int minutes;
  final List<String> places;

  const DriverTripDay({
    required this.day,
    required this.date,
    required this.city,
    required this.taxi,
    required this.km,
    required this.minutes,
    required this.places,
  });

  factory DriverTripDay.fromJson(Map<String, dynamic> j) => DriverTripDay(
        day: _int(j['day']),
        date: _str(j['date']),
        city: _str(j['city']),
        taxi: _bool(j['taxi']),
        km: _int(j['km']),
        minutes: _int(j['minutes']),
        places: [for (final p in (j['places'] is List ? j['places'] as List : const [])) if (p is String) p],
      );

  Map<String, dynamic> toJson() =>
      {'day': day, 'date': date, 'city': city, 'taxi': taxi, 'km': km, 'minutes': minutes, 'places': places};
}

class DriverTrip {
  final String name;
  final DriverTripStop pickup;
  final DriverTripDrop drop;
  final List<DriverTripCity> cities;
  final List<DriverTripDay> days;

  const DriverTrip({required this.name, required this.pickup, required this.drop, required this.cities, required this.days});

  factory DriverTrip.fromJson(Map<String, dynamic> j) => DriverTrip(
        name: _str(j['name']),
        pickup: DriverTripStop.fromJson(_map(j['pickup'])),
        drop: DriverTripDrop.fromJson(_map(j['drop'])),
        cities: _list(j['cities'], DriverTripCity.fromJson),
        days: _list(j['days'], DriverTripDay.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'pickup': pickup.toJson(),
        'drop': drop.toJson(),
        'cities': [for (final c in cities) c.toJson()],
        'days': [for (final d in days) d.toJson()],
      };
}

class DriverOffer {
  final String offerId;
  final String requestId;
  final String? bookingId;
  final String stateText;
  final String? endReasonText;
  final String bucketText;
  final String? expiresAt;
  final String? confirmBy;
  final String pickupName;
  final TaxiRequestSections sections;
  final int sightseeingDayCount;
  final String dateFrom;
  final String dateTo;
  final int dayCount;
  final int nightCount;
  final String routeLine;
  final int seats;
  final int travellers;
  final DriverTraveller? traveller;
  final DriverDatesConflict? datesConflict;
  final DriverTrip? trip;

  const DriverOffer({
    required this.offerId,
    required this.requestId,
    required this.bookingId,
    required this.stateText,
    required this.endReasonText,
    required this.bucketText,
    required this.expiresAt,
    required this.confirmBy,
    required this.pickupName,
    required this.sections,
    required this.sightseeingDayCount,
    required this.dateFrom,
    required this.dateTo,
    required this.dayCount,
    required this.nightCount,
    required this.routeLine,
    required this.seats,
    required this.travellers,
    required this.traveller,
    required this.datesConflict,
    required this.trip,
  });

  factory DriverOffer.fromJson(Map<String, dynamic> j) => DriverOffer(
        offerId: _str(j['offerId']),
        requestId: _str(j['requestId']),
        bookingId: _strOrNull(j['bookingId']),
        stateText: _str(j['state']),
        endReasonText: _strOrNull(j['endReason']),
        bucketText: _str(j['bucket']),
        expiresAt: _strOrNull(j['expiresAt']),
        confirmBy: _strOrNull(j['confirmBy']),
        pickupName: _str(j['pickupName']),
        sections: TaxiRequestSections.fromJson(_map(j['sections'])),
        sightseeingDayCount: _int(j['sightseeingDayCount']),
        dateFrom: _str(j['dateFrom']),
        dateTo: _str(j['dateTo']),
        dayCount: _int(j['dayCount']),
        nightCount: _int(j['nightCount']),
        routeLine: _str(j['routeLine']),
        seats: _int(j['seats']),
        travellers: _int(j['travellers']),
        traveller: j['traveller'] is Map ? DriverTraveller.fromJson(_map(j['traveller'])) : null,
        datesConflict: j['datesConflict'] is Map ? DriverDatesConflict.fromJson(_map(j['datesConflict'])) : null,
        trip: j['trip'] is Map ? DriverTrip.fromJson(_map(j['trip'])) : null,
      );

  Map<String, dynamic> toJson() => {
        'offerId': offerId,
        'requestId': requestId,
        'bookingId': bookingId,
        'state': stateText,
        'endReason': endReasonText,
        'bucket': bucketText,
        'expiresAt': expiresAt,
        'confirmBy': confirmBy,
        'pickupName': pickupName,
        'sections': sections.toJson(),
        'sightseeingDayCount': sightseeingDayCount,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'dayCount': dayCount,
        'nightCount': nightCount,
        'routeLine': routeLine,
        'seats': seats,
        'travellers': travellers,
        'traveller': traveller?.toJson(),
        'datesConflict': datesConflict?.toJson(),
        'trip': trip?.toJson(),
      };

  OfferState get state => OfferState.parse(stateText);

  OfferBucket get bucket => OfferBucket.parse(bucketText);

  OfferEndReason get endReason => OfferEndReason.parse(endReasonText);

  DateTime? get expiresAtInstant => _instant(expiresAt);

  DateTime? get confirmByInstant => _instant(confirmBy);

  DateTime? get fromDay => _day(dateFrom);

  DateTime? get toDay => _day(dateTo);

  DriverOffer copyWith({OfferState? state, DriverDatesConflict? datesConflict, DriverTrip? trip}) => DriverOffer(
        offerId: offerId,
        requestId: requestId,
        bookingId: bookingId,
        stateText: state?.wire ?? stateText,
        endReasonText: endReasonText,
        bucketText: bucketText,
        expiresAt: expiresAt,
        confirmBy: confirmBy,
        pickupName: pickupName,
        sections: sections,
        sightseeingDayCount: sightseeingDayCount,
        dateFrom: dateFrom,
        dateTo: dateTo,
        dayCount: dayCount,
        nightCount: nightCount,
        routeLine: routeLine,
        seats: seats,
        travellers: travellers,
        traveller: traveller,
        datesConflict: datesConflict ?? this.datesConflict,
        trip: trip ?? this.trip,
      );
}

class DriverOfferCounts {
  final int newCount;
  final int booked;

  const DriverOfferCounts({required this.newCount, required this.booked});

  factory DriverOfferCounts.fromJson(Map<String, dynamic> j) =>
      DriverOfferCounts(newCount: _int(j['new']), booked: _int(j['booked']));

  Map<String, dynamic> toJson() => {'new': newCount, 'booked': booked};
}

class DriverOfferList {
  final String serverNow;
  final DriverOfferCounts counts;
  final String? nextCursor;
  final List<DriverOffer> items;

  const DriverOfferList({required this.serverNow, required this.counts, required this.nextCursor, required this.items});

  factory DriverOfferList.fromJson(Map<String, dynamic> j) => DriverOfferList(
        serverNow: _str(j['serverNow']),
        counts: DriverOfferCounts.fromJson(_map(j['counts'])),
        nextCursor: _strOrNull(j['nextCursor']),
        items: _list(j['items'], DriverOffer.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'serverNow': serverNow,
        'counts': counts.toJson(),
        'nextCursor': nextCursor,
        'items': [for (final i in items) i.toJson()],
      };

  DateTime? get serverNowInstant => _instant(serverNow);

  Duration? clockOffset(DateTime deviceNow) => serverNowInstant?.difference(deviceNow.toUtc());
}

class DriverOccupiedRange {
  final String bookingId;
  final String from;
  final String to;

  const DriverOccupiedRange({required this.bookingId, required this.from, required this.to});

  factory DriverOccupiedRange.fromJson(Map<String, dynamic> j) =>
      DriverOccupiedRange(bookingId: _str(j['bookingId']), from: _str(j['from']), to: _str(j['to']));

  Map<String, dynamic> toJson() => {'bookingId': bookingId, 'from': from, 'to': to};

  DateTime? get fromDay => _day(from);

  DateTime? get toDay => _day(to);
}

class DriverBooking {
  final String bookingId;
  final String offerId;
  final String requestId;
  final String stateText;
  final String dateFrom;
  final String dateTo;
  final String pickupName;
  final String travellerName;
  final String? travellerPhone;
  final bool canWithdraw;
  final bool canEnd;

  const DriverBooking({
    required this.bookingId,
    required this.offerId,
    required this.requestId,
    required this.stateText,
    required this.dateFrom,
    required this.dateTo,
    required this.pickupName,
    required this.travellerName,
    required this.travellerPhone,
    required this.canWithdraw,
    required this.canEnd,
  });

  factory DriverBooking.fromJson(Map<String, dynamic> j) => DriverBooking(
        bookingId: _str(j['bookingId']),
        offerId: _str(j['offerId']),
        requestId: _str(j['requestId']),
        stateText: _str(j['state']),
        dateFrom: _str(j['dateFrom']),
        dateTo: _str(j['dateTo']),
        pickupName: _str(j['pickupName']),
        travellerName: _str(j['travellerName']),
        travellerPhone: _strOrNull(j['travellerPhone']),
        canWithdraw: _bool(j['canWithdraw']),
        canEnd: _bool(j['canEnd']),
      );

  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'offerId': offerId,
        'requestId': requestId,
        'state': stateText,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'pickupName': pickupName,
        'travellerName': travellerName,
        'travellerPhone': travellerPhone,
        'canWithdraw': canWithdraw,
        'canEnd': canEnd,
      };

  BookingState get state => BookingState.parse(stateText);

  DateTime? get fromDay => _day(dateFrom);

  DateTime? get toDay => _day(dateTo);
}

class DriverBookings {
  final String from;
  final String to;
  final List<DriverOccupiedRange> occupied;
  final List<DriverBooking> items;

  const DriverBookings({required this.from, required this.to, required this.occupied, required this.items});

  factory DriverBookings.fromJson(Map<String, dynamic> j) => DriverBookings(
        from: _str(j['from']),
        to: _str(j['to']),
        occupied: _list(j['occupied'], DriverOccupiedRange.fromJson),
        items: _list(j['items'], DriverBooking.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'occupied': [for (final o in occupied) o.toJson()],
        'items': [for (final i in items) i.toJson()],
      };
}

class DriverRatingRow {
  final String date;
  final int stars;

  const DriverRatingRow({required this.date, required this.stars});

  factory DriverRatingRow.fromJson(Map<String, dynamic> j) => DriverRatingRow(date: _str(j['date']), stars: _int(j['stars']));

  Map<String, dynamic> toJson() => {'date': date, 'stars': stars};
}

class DriverRating {
  final double? average;
  final int ratingCount;
  final int ridesCompleted;
  final List<DriverRatingRow> latest;

  const DriverRating({required this.average, required this.ratingCount, required this.ridesCompleted, required this.latest});

  factory DriverRating.fromJson(Map<String, dynamic> j) => DriverRating(
        average: _doubleOrNull(j['average']),
        ratingCount: _int(j['ratingCount']),
        ridesCompleted: _int(j['ridesCompleted']),
        latest: _list(j['latest'], DriverRatingRow.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'average': average,
        'ratingCount': ratingCount,
        'ridesCompleted': ridesCompleted,
        'latest': [for (final r in latest) r.toJson()],
      };
}

class DriverReadiness {
  final bool approved;
  final bool online;
  final bool ringReady;
  final bool notificationsOn;
  final bool hasValidToken;
  final bool missedRings;
  final int routesWithoutCity;

  const DriverReadiness({
    required this.approved,
    required this.online,
    required this.ringReady,
    required this.notificationsOn,
    required this.hasValidToken,
    required this.missedRings,
    required this.routesWithoutCity,
  });

  factory DriverReadiness.fromJson(Map<String, dynamic> j) => DriverReadiness(
        approved: _bool(j['approved']),
        online: _bool(j['online']),
        ringReady: _bool(j['ringReady']),
        notificationsOn: _bool(j['notificationsOn']),
        hasValidToken: _bool(j['hasValidToken']),
        missedRings: _bool(j['missedRings']),
        routesWithoutCity: _int(j['routesWithoutCity']),
      );

  Map<String, dynamic> toJson() => {
        'approved': approved,
        'online': online,
        'ringReady': ringReady,
        'notificationsOn': notificationsOn,
        'hasValidToken': hasValidToken,
        'missedRings': missedRings,
        'routesWithoutCity': routesWithoutCity,
      };
}

class DriverDeviceState {
  final int appBuild;
  final bool notificationsOn;
  final bool ringChannelOn;
  final bool batteryUnrestricted;
  final String manufacturer;
  final int androidSdk;
  final bool ringTested;

  const DriverDeviceState({
    required this.appBuild,
    required this.notificationsOn,
    required this.ringChannelOn,
    required this.batteryUnrestricted,
    required this.manufacturer,
    required this.androidSdk,
    this.ringTested = false,
  });

  factory DriverDeviceState.fromJson(Map<String, dynamic> j) => DriverDeviceState(
        appBuild: _int(j['appBuild']),
        notificationsOn: _bool(j['notificationsOn']),
        ringChannelOn: _bool(j['ringChannelOn']),
        batteryUnrestricted: _bool(j['batteryUnrestricted']),
        manufacturer: _str(j['manufacturer']),
        androidSdk: _int(j['androidSdk']),
        ringTested: _bool(j['ringTested']),
      );

  Map<String, dynamic> toJson() => {
        'appBuild': appBuild,
        'notificationsOn': notificationsOn,
        'ringChannelOn': ringChannelOn,
        'batteryUnrestricted': batteryUnrestricted,
        'manufacturer': manufacturer,
        'androidSdk': androidSdk,
        'ringTested': ringTested,
      };

  DriverDeviceState copyWith({bool? ringTested}) => DriverDeviceState(
        appBuild: appBuild,
        notificationsOn: notificationsOn,
        ringChannelOn: ringChannelOn,
        batteryUnrestricted: batteryUnrestricted,
        manufacturer: manufacturer,
        androidSdk: androidSdk,
        ringTested: ringTested ?? this.ringTested,
      );
}
