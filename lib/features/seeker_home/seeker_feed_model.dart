import '../owner_core/json/owner_dates.dart';
import '../owner_core/json/owner_json.dart';

enum SeekerTripState { none, inProgress, onTrip }

enum SeekerStepKind { stay, taxi, journey, plan, unknown }

enum SeekerStatusKind { reply, confirmed, unknown }

class SeekerNextStep {
  final String key;
  final SeekerStepKind kind;
  final String? cityName;

  const SeekerNextStep({required this.key, required this.kind, this.cityName});

  static SeekerNextStep? fromJson(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    return SeekerNextStep(
      key: OwnerJson.str(j['key']),
      kind: OwnerJson.pick(j['kind'], const {
        'Stay': SeekerStepKind.stay,
        'Taxi': SeekerStepKind.taxi,
        'Journey': SeekerStepKind.journey,
        'Plan': SeekerStepKind.plan,
      }, SeekerStepKind.unknown),
      cityName: OwnerJson.strOrNull(j['cityName']),
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'kind': _kindName(kind), 'cityName': cityName};

  static String? _kindName(SeekerStepKind k) => switch (k) {
        SeekerStepKind.stay => 'Stay',
        SeekerStepKind.taxi => 'Taxi',
        SeekerStepKind.journey => 'Journey',
        SeekerStepKind.plan => 'Plan',
        SeekerStepKind.unknown => null,
      };
}

class SeekerPlace {
  final String id;
  final String name;

  const SeekerPlace({required this.id, required this.name});

  factory SeekerPlace.fromJson(Map<String, dynamic> j) => SeekerPlace(id: OwnerJson.str(j['id']), name: OwnerJson.str(j['name']));

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class SeekerToday {
  final int dayNumber;
  final int totalDays;
  final String? cityName;
  final int placeCount;
  final List<SeekerPlace> places;
  final int? placesSeen;

  const SeekerToday({
    required this.dayNumber,
    required this.totalDays,
    this.cityName,
    required this.placeCount,
    this.places = const [],
    this.placesSeen,
  });

  static SeekerToday? fromJson(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    final places = OwnerJson.list(j['places'], SeekerPlace.fromJson);
    final count = OwnerJson.intOrNull(j['placeCount']) ?? places.length;
    return SeekerToday(
      dayNumber: OwnerJson.integer(j['dayNumber']),
      totalDays: OwnerJson.integer(j['totalDays']),
      cityName: OwnerJson.strOrNull(j['cityName']),
      placeCount: count < 0 ? 0 : count,
      places: places,
      placesSeen: OwnerJson.intOrNull(j['placesSeen']),
    );
  }

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'totalDays': totalDays,
        'cityName': cityName,
        'placeCount': placeCount,
        'places': [for (final p in places) p.toJson()],
        'placesSeen': placesSeen,
      };
}

class SeekerTripCard {
  final SeekerTripState state;
  final String? tripId;
  final String title;
  final String? destinationName;
  final DateTime? startDate;
  final DateTime? endDate;
  final int done;
  final int total;
  final SeekerNextStep? nextStep;
  final SeekerToday? today;

  const SeekerTripCard({
    this.state = SeekerTripState.none,
    this.tripId,
    this.title = '',
    this.destinationName,
    this.startDate,
    this.endDate,
    this.done = 0,
    this.total = 0,
    this.nextStep,
    this.today,
  });

  static const SeekerTripCard empty = SeekerTripCard();

  factory SeekerTripCard.fromJson(Object? raw) {
    final j = OwnerJson.map(raw);
    final state = OwnerJson.pick(j['state'], const {
      'None': SeekerTripState.none,
      'InProgress': SeekerTripState.inProgress,
      'OnTrip': SeekerTripState.onTrip,
    }, SeekerTripState.none);
    final tripId = OwnerJson.strOrNull(j['tripId']);
    final done = OwnerJson.integer(j['done']);
    final total = OwnerJson.integer(j['total']);
    final today = SeekerToday.fromJson(j['today']);
    final usable = state != SeekerTripState.none && tripId != null;
    final onTrip = state == SeekerTripState.onTrip && today != null;
    return SeekerTripCard(
      state: !usable ? SeekerTripState.none : (state == SeekerTripState.onTrip && !onTrip ? SeekerTripState.inProgress : state),
      tripId: usable ? tripId : null,
      title: OwnerJson.str(j['title']).trim(),
      destinationName: OwnerJson.strOrNull(j['destinationName']),
      startDate: OwnerDates.day(j['startDate']),
      endDate: OwnerDates.day(j['endDate']),
      done: done < 0 ? 0 : done,
      total: total < 0 ? 0 : total,
      nextStep: SeekerNextStep.fromJson(j['nextStep']),
      today: onTrip ? today : null,
    );
  }

  bool get hasTrip => state != SeekerTripState.none && tripId != null;

  String get displayTitle {
    if (title.isNotEmpty) return title;
    return destinationName?.trim() ?? '';
  }

  Map<String, dynamic> toJson() => {
        'state': switch (state) {
          SeekerTripState.none => 'None',
          SeekerTripState.inProgress => 'InProgress',
          SeekerTripState.onTrip => 'OnTrip',
        },
        'tripId': tripId,
        'title': title,
        'destinationName': destinationName,
        'startDate': OwnerDates.dayTextOrNull(startDate),
        'endDate': OwnerDates.dayTextOrNull(endDate),
        'done': done,
        'total': total,
        'nextStep': nextStep?.toJson(),
        'today': today?.toJson(),
      };
}

class SeekerStatus {
  final SeekerStatusKind kind;
  final int count;
  final String listingName;
  final String? enquiryId;
  final String? tripId;
  final String key;

  const SeekerStatus({required this.kind, this.count = 0, this.listingName = '', this.enquiryId, this.tripId, required this.key});

  static SeekerStatus? fromJson(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    final kind = OwnerJson.pick(j['kind'], const {'Reply': SeekerStatusKind.reply, 'Confirmed': SeekerStatusKind.confirmed}, SeekerStatusKind.unknown);
    final key = OwnerJson.str(j['key']);
    if (kind == SeekerStatusKind.unknown || key.isEmpty) return null;
    final count = OwnerJson.integer(j['count']);
    final name = OwnerJson.str(j['listingName']).trim();
    if (kind == SeekerStatusKind.reply && count < 1) return null;
    if (kind == SeekerStatusKind.confirmed && name.isEmpty) return null;
    return SeekerStatus(
      kind: kind,
      count: count,
      listingName: name,
      enquiryId: OwnerJson.strOrNull(j['enquiryId']),
      tripId: OwnerJson.strOrNull(j['tripId']),
      key: key,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind == SeekerStatusKind.reply ? 'Reply' : 'Confirmed',
        'count': count,
        'listingName': listingName,
        'enquiryId': enquiryId,
        'tripId': tripId,
        'key': key,
      };
}

class SeekerSlots {
  final int count;
  final int limit;
  final bool full;

  const SeekerSlots({required this.count, required this.limit, required this.full});

  static SeekerSlots? fromJson(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    final count = OwnerJson.intOrNull(j['count']);
    final limit = OwnerJson.intOrNull(j['limit']);
    if (count == null || limit == null || limit < 1 || count < 0) return null;
    return SeekerSlots(count: count, limit: limit, full: OwnerJson.boolOrNull(j['full']) ?? count >= limit);
  }

  Map<String, dynamic> toJson() => {'count': count, 'limit': limit, 'full': full};
}

class SeekerFeed {
  final SeekerTripCard tripCard;
  final SeekerStatus? status;
  final SeekerSlots? slots;

  const SeekerFeed({this.tripCard = SeekerTripCard.empty, this.status, this.slots});

  static const SeekerFeed empty = SeekerFeed();

  factory SeekerFeed.fromJson(Object? raw) {
    final j = OwnerJson.map(raw);
    return SeekerFeed(
      tripCard: SeekerTripCard.fromJson(j['tripCard']),
      status: SeekerStatus.fromJson(j['status']),
      slots: SeekerSlots.fromJson(j['slots']),
    );
  }

  bool get plansFull => slots?.full == true;

  Map<String, dynamic> toJson() => {
        'tripCard': tripCard.toJson(),
        'status': status?.toJson(),
        'slots': slots?.toJson(),
      };
}
