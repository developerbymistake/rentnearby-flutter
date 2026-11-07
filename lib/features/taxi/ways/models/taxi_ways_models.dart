import '../../../stay/models/stay_nearby_model.dart';
import '../../models/taxi_browse_item.dart';

typedef LatLngPair = ({double lat, double lng});

typedef WayDriverPage = ({List<WayDriver> items, bool hasMore, int total});

enum WaysSort { fewestCars, lowestPrice }

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _dn(Object? v) => (v as num?)?.toDouble();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
int? _in(Object? v) => (v as num?)?.toInt();
String _s(Object? v, [String fallback = '']) => v is String ? v : fallback;
String? _sn(Object? v) => v is String && v.isNotEmpty ? v : null;

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    v is List ? v.whereType<Map<String, dynamic>>().map(f).toList() : <T>[];

String wayNameOr(String? name, String key, {required bool start, required bool end}) {
  final t = name?.trim() ?? '';
  if (t.isNotEmpty) return t;
  if (key.startsWith('m:')) return 'My location';
  return start ? 'Pickup point' : (end ? 'Drop point' : 'Stop');
}

class WayPlace {
  final String key;
  final String name;
  final double lat;
  final double lng;
  final bool resolved;
  final String? districtId;

  const WayPlace({
    required this.key,
    required this.name,
    required this.lat,
    required this.lng,
    this.resolved = true,
    this.districtId,
  });

  factory WayPlace.fromJson(Map<String, dynamic> json) => WayPlace(
        key: _s(json['key']),
        name: _s(json['name']),
        lat: _d(json['lat']),
        lng: _d(json['lng']),
        resolved: json['resolved'] != false,
        districtId: _sn(json['districtId']),
      );

  static WayPlace? tryParse(Object? v) => v is Map<String, dynamic> ? WayPlace.fromJson(v) : null;

  bool get isVirtual => key.startsWith('v:') || key.startsWith('m:');

  WayPlace withName(String next) =>
      WayPlace(key: key, name: next, lat: lat, lng: lng, resolved: resolved, districtId: districtId);
}

class WayBest {
  final String kind;
  final String id;
  final String reason;

  const WayBest({required this.kind, required this.id, required this.reason});

  bool get isDriver => kind == 'driver';
  bool get isPlan => kind == 'plan';

  static WayBest? tryParse(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    final kind = v['kind'];
    final id = v['id'];
    if (kind is! String || id is! String || id.isEmpty) return null;
    return WayBest(kind: kind, id: id, reason: _s(v['reason']));
  }
}

class WayDriver {
  final String taxiId;
  final String driverName;
  final String vehicleTypeName;
  final String? vehicleCategory;
  final int? seats;
  final String plateDisplay;
  final String? cityName;
  final bool basedHere;
  final String tripReplyLabel;
  final int priorityRank;
  final bool isFeatured;
  final String? routeId;
  final String fromName;
  final String toName;
  final int listedFare;
  final int? estimatedFare;
  final String tripType;
  final bool partial;
  final bool reversed;
  final double? distanceKm;
  final int? minutes;
  final bool hasRoadLine;
  final String? phone;
  final String? whatsApp;

  const WayDriver({
    required this.taxiId,
    required this.driverName,
    required this.vehicleTypeName,
    this.vehicleCategory,
    this.seats,
    this.plateDisplay = '',
    this.cityName,
    this.basedHere = false,
    this.tripReplyLabel = 'new',
    this.priorityRank = 0,
    this.isFeatured = false,
    this.routeId,
    required this.fromName,
    required this.toName,
    required this.listedFare,
    this.estimatedFare,
    this.tripType = 'OneWay',
    this.partial = false,
    this.reversed = false,
    this.distanceKm,
    this.minutes,
    this.hasRoadLine = false,
    this.phone,
    this.whatsApp,
  });

  factory WayDriver.fromJson(Map<String, dynamic> json) => WayDriver(
        taxiId: _s(json['taxiId']),
        driverName: _s(json['driverName'], 'Driver'),
        vehicleTypeName: _s(json['vehicleTypeName'], 'Taxi'),
        vehicleCategory: _sn(json['vehicleCategory']),
        seats: _in(json['seats']),
        plateDisplay: _s(json['plateDisplay']),
        cityName: _sn(json['cityName']),
        basedHere: json['basedHere'] == true,
        tripReplyLabel: _s(json['tripReplyLabel'], 'new'),
        priorityRank: _i(json['priorityRank']),
        isFeatured: json['isFeatured'] == true,
        routeId: _sn(json['routeId']),
        fromName: _s(json['fromName']),
        toName: _s(json['toName']),
        listedFare: _i(json['listedFare']),
        estimatedFare: _in(json['estimatedFare']),
        tripType: _s(json['tripType'], 'OneWay'),
        partial: json['partial'] == true,
        reversed: json['reversed'] == true,
        distanceKm: _dn(json['distanceKm']),
        minutes: _in(json['minutes']),
        hasRoadLine: json['hasRoadLine'] == true,
        phone: _sn(json['phone']),
        whatsApp: _sn(json['whatsApp']),
      );

  bool get repliesInApp => tripReplyLabel == 'app';

  // Per car for this stretch: the road-share estimate of a partial route, else the driver's quote.
  int get fare => estimatedFare ?? listedFare;

  bool get isEstimate => estimatedFare != null;

  int carsFor(int people) => WayCars.needed(people, seats);

  int groupFare(int people) => fare * carsFor(people);

  bool get hasContact => phone != null || whatsApp != null;

  String get firstName {
    final t = driverName.trim();
    final i = t.indexOf(' ');
    return i > 0 ? t.substring(0, i) : t;
  }

  String get initial => driverName.trim().isEmpty ? '?' : driverName.trim()[0].toUpperCase();
}

class WayLeg {
  final String legKey;
  final int index;
  final WayPlace from;
  final WayPlace to;
  final String? meetingPlace;
  final int listedFare;
  final bool partial;
  final double? distanceKm;
  final List<String> passes;
  final List<WayDriver> topDrivers;
  final int driverCount;
  final bool hasRoadLine;
  final List<WayDriver> drivers;
  final List<LatLngPair>? geometry;
  final int carsNeeded;
  final String? seatsNote;
  final List<String> coverTaxiIds;
  final bool fareEstimated;

  const WayLeg({
    required this.legKey,
    required this.index,
    required this.from,
    required this.to,
    this.meetingPlace,
    required this.listedFare,
    this.partial = false,
    this.distanceKm,
    this.passes = const [],
    this.topDrivers = const [],
    this.driverCount = 0,
    this.hasRoadLine = false,
    this.drivers = const [],
    this.geometry,
    this.carsNeeded = 1,
    this.seatsNote,
    this.coverTaxiIds = const [],
    this.fareEstimated = false,
  });

  WayLeg withPlaces({WayPlace? from, WayPlace? to}) => WayLeg(
        legKey: legKey,
        index: index,
        from: from ?? this.from,
        to: to ?? this.to,
        meetingPlace: meetingPlace,
        listedFare: listedFare,
        partial: partial,
        distanceKm: distanceKm,
        passes: passes,
        topDrivers: topDrivers,
        driverCount: driverCount,
        hasRoadLine: hasRoadLine,
        drivers: drivers,
        geometry: geometry,
        carsNeeded: carsNeeded,
        seatsNote: seatsNote,
        coverTaxiIds: coverTaxiIds,
        fareEstimated: fareEstimated,
      );

  factory WayLeg.fromJson(Map<String, dynamic> json) => WayLeg(
        legKey: _s(json['legKey']),
        index: _i(json['index']),
        from: WayPlace.tryParse(json['from']) ?? const WayPlace(key: '', name: '', lat: 0, lng: 0),
        to: WayPlace.tryParse(json['to']) ?? const WayPlace(key: '', name: '', lat: 0, lng: 0),
        meetingPlace: _sn(json['meetingPlace']),
        listedFare: _i(json['listedFare']),
        partial: json['partial'] == true,
        distanceKm: _dn(json['distanceKm']),
        passes: json['passes'] is List ? (json['passes'] as List).whereType<String>().toList() : const [],
        topDrivers: _list(json['topDrivers'], WayDriver.fromJson),
        driverCount: _i(json['driverCount']),
        hasRoadLine: json['hasRoadLine'] == true,
        drivers: _list(json['drivers'], WayDriver.fromJson),
        geometry: _geometry(json['geometry']),
        carsNeeded: _i(json['carsNeeded']) < 1 ? 1 : _i(json['carsNeeded']),
        seatsNote: _sn(json['seatsNote']),
        coverTaxiIds: json['coverTaxiIds'] is List ? (json['coverTaxiIds'] as List).whereType<String>().toList() : const [],
        fareEstimated: json['fareEstimated'] == true,
      );

  static List<LatLngPair>? _geometry(Object? v) {
    if (v is! Map) return null;
    final coords = v['coordinates'];
    if (coords is! List) return null;
    final out = <LatLngPair>[];
    for (final c in coords) {
      if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
        out.add((lat: (c[1] as num).toDouble(), lng: (c[0] as num).toDouble()));
      }
    }
    return out.length >= 2 ? out : null;
  }

  List<WayDriver> get allDrivers => drivers.isNotEmpty ? drivers : topDrivers;

  WayDriver? get firstDriver {
    final all = allDrivers;
    return all.isEmpty ? null : all.first;
  }

  int get otherCount {
    final n = driverCount > 0 ? driverCount : allDrivers.length;
    return n > 1 ? n - 1 : 0;
  }

  List<String> get coverIds => WayCover.distinct(coverTaxiIds);

  bool get isMultiCarCover => coverIds.length >= 2;

  WayDriver? driverById(String id) {
    for (final d in allDrivers) {
      if (d.taxiId == id) return d;
    }
    return null;
  }

  // A manual pick, else the first car of the server's seat cover, else the top driver.
  WayDriver? driverFor(WayDriver? pick) {
    if (pick != null) return pick;
    for (final id in coverIds) {
      final d = driverById(id);
      if (d != null) return d;
    }
    return firstDriver;
  }

  // The other cars of the cover the saved driver rides with; a manual pick carries the group alone.
  List<String> coverOthersFor(WayDriver? pick) {
    if (pick != null) return const [];
    final d = driverFor(null);
    final ids = coverIds;
    if (d == null || !ids.contains(d.taxiId)) return const [];
    return [for (final id in ids) if (id != d.taxiId) id];
  }

  int carsWith(WayDriver? pick, int people) => pick == null ? carsNeeded : pick.carsFor(people);

  int fareWith(WayDriver? pick, int people) => pick == null ? listedFare : pick.groupFare(people);
}

class WayCars {
  const WayCars._();

  static int needed(int people, int? seats) {
    if (seats == null || seats < 1 || people <= seats) return 1;
    return (people + seats - 1) ~/ seats;
  }
}

// Mirrors the server's JourneyLegPricing: the seat cover is the only source of a stretch's cars.
class WayCover {
  const WayCover._();

  static List<String> distinct(Iterable<String> ids) {
    final out = <String>[];
    for (final id in ids) {
      if (id.isNotEmpty && !out.contains(id)) out.add(id);
    }
    return out;
  }

  static int carsOfLeg(int people, int? driverSeats, List<String> coverOthers) =>
      coverOthers.isNotEmpty ? 1 + coverOthers.length : WayCars.needed(people, driverSeats);

  static int carsFor(String taxiId, int? seats, int people, String driverTaxiId, List<String> coverOthers) =>
      coverOthers.isNotEmpty && (taxiId == driverTaxiId || coverOthers.contains(taxiId)) ? 1 : WayCars.needed(people, seats);

  // The asked cars of a stretch: the driver and his cover cars first, then backups, at most cap.
  static List<String> askIds(String driverTaxiId, List<String> coverOthers, Iterable<String> backups, int cap) {
    final ids = <String>[driverTaxiId];
    for (final id in [...coverOthers, ...backups]) {
      if (ids.length >= cap) break;
      if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }
}

class WayPlan {
  final String planKey;
  final int cars;
  final int total;
  final List<WayLeg> legs;

  const WayPlan({required this.planKey, required this.cars, required this.total, required this.legs});

  factory WayPlan.fromJson(Map<String, dynamic> json) {
    final legs = _list(json['legs'], WayLeg.fromJson)..sort((a, b) => a.index.compareTo(b.index));
    return WayPlan(
      planKey: _s(json['planKey']),
      cars: _in(json['cars']) ?? legs.length,
      total: _i(json['total']),
      legs: legs,
    );
  }

  factory WayPlan.single(WayPlace from, WayPlace to, List<WayDriver> drivers) {
    final fare = drivers.isEmpty ? 0 : drivers.first.fare;
    return WayPlan(
      planKey: 'p1~${from.key}~${to.key}',
      cars: 1,
      total: fare,
      legs: [
        WayLeg(
          legKey: 'l1~${from.key}~${to.key}',
          index: 1,
          from: from,
          to: to,
          listedFare: fare,
          partial: drivers.isNotEmpty && drivers.first.partial,
          distanceKm: drivers.isEmpty ? null : drivers.first.distanceKm,
          topDrivers: drivers,
          driverCount: drivers.length,
          hasRoadLine: drivers.isNotEmpty && drivers.first.hasRoadLine,
        ),
      ],
    );
  }

  WayPlace get from => legs.first.from;
  WayPlace get to => legs.last.to;

  // Names the traveller typed for a pinned start or end stay; a blank name is never shown.
  WayPlan withEndNames(WayPlace typedFrom, WayPlace typedTo) {
    if (legs.isEmpty) return this;
    final first = legs.first;
    final last = legs.last;
    final fromName = first.from.isVirtual && typedFrom.name.trim().isNotEmpty
        ? typedFrom.name.trim()
        : wayNameOr(first.from.name, first.from.key, start: true, end: false);
    final toName = last.to.isVirtual && typedTo.name.trim().isNotEmpty
        ? typedTo.name.trim()
        : wayNameOr(last.to.name, last.to.key, start: false, end: true);
    final next = [...legs];
    next[0] = first.withPlaces(from: first.from.withName(fromName));
    final lastIndex = next.length - 1;
    next[lastIndex] = next[lastIndex].withPlaces(to: next[lastIndex].to.withName(toName));
    return WayPlan(planKey: planKey, cars: cars, total: total, legs: next);
  }

  List<WayPlace> get changePlaces => [for (var i = 0; i < legs.length - 1; i++) legs[i].to];

  int get maxCarsNeeded => legs.fold(1, (m, l) => l.carsNeeded > m ? l.carsNeeded : m);

  // Cars hired over the whole way: each stretch's seat cover.
  int get carHires => legs.isEmpty ? cars : legs.fold(0, (sum, l) => sum + l.carsNeeded);

  // All the way with several drivers' cars and no change (server DirectCoverPlan).
  bool get isDirectCover => legs.length == 1 && legs.first.isMultiCarCover;

  // The server's seat cover for a leg left as is; a chosen driver carries the whole group in his own cars.
  int totalWith(Map<int, WayDriver> chosen, {int people = 1}) {
    var sum = 0;
    for (final leg in legs) {
      sum += leg.fareWith(chosen[leg.index], people);
    }
    return sum;
  }
}

typedef WayPlanDetail = WayPlan;

typedef WayFeedArgs = ({
  WayPlace from,
  WayPlace to,
  DateTime? date,
  int? people,
  String? tripId,
  String? tripRole,
  int? tripLegIndex,
});

class JourneyOpenArgs {
  static const String roleSegment = 'segment';
  static const List<String> stepRoles = ['gettingThere', 'comingBack'];

  final WayPlan plan;
  final String planKey;
  final WayPlace from;
  final WayPlace to;
  final DateTime date;
  final int people;
  final String? tripId;
  final String? tripRole;
  final int? tripLegIndex;
  final Map<int, WayDriver> chosen;
  final bool synthetic;
  final bool fromMyLocation;

  const JourneyOpenArgs({
    required this.plan,
    required this.planKey,
    required this.from,
    required this.to,
    required this.date,
    required this.people,
    this.tripId,
    this.tripRole,
    this.tripLegIndex,
    this.chosen = const {},
    this.synthetic = false,
    this.fromMyLocation = false,
  });

  bool get forTrip => tripId != null && stepRoles.contains(tripRole);

  bool get forSegment => tripId != null && tripLegIndex != null;

  bool get inTrip => forTrip || forSegment;

  JourneyOpenArgs withChosen(Map<int, WayDriver> next) => JourneyOpenArgs(
        plan: plan,
        planKey: planKey,
        from: from,
        to: to,
        date: date,
        people: people,
        tripId: tripId,
        tripRole: tripRole,
        tripLegIndex: tripLegIndex,
        chosen: Map.unmodifiable(next),
        synthetic: synthetic,
        fromMyLocation: fromMyLocation,
      );

  static String? invalidReason(Object? args) {
    if (args == null) return 'no arguments';
    if (args is! JourneyOpenArgs) return 'arguments are ${args.runtimeType}, not JourneyOpenArgs';
    if (args.planKey.isEmpty) return 'empty planKey';
    if (args.plan.planKey != args.planKey) return 'plan ${args.plan.planKey} does not match planKey ${args.planKey}';
    if (args.people < 1) return 'people ${args.people}';
    return null;
  }

  static JourneyOpenArgs? of(Object? args) => invalidReason(args) == null ? args as JourneyOpenArgs : null;

  static WayFeedArgs? feedOf(Object? args) {
    if (args is JourneyOpenArgs) {
      return (
        from: args.from,
        to: args.to,
        date: args.date,
        people: args.people,
        tripId: args.tripId,
        tripRole: args.tripRole,
        tripLegIndex: args.tripLegIndex,
      );
    }
    if (args is! Map) return null;
    final from = WayPlace.tryParse(args['from']);
    final to = WayPlace.tryParse(args['to']);
    if (from == null || to == null) return null;
    final rawDate = args['date'];
    final date = rawDate is DateTime ? rawDate : (rawDate is String ? DateTime.tryParse(rawDate) : null);
    final people = args['people'];
    final legIndex = args['tripLegIndex'];
    return (
      from: from,
      to: to,
      date: date,
      people: people is int && people > 0 ? people : null,
      tripId: args['tripId'] as String?,
      tripRole: args['tripRole'] as String?,
      tripLegIndex: legIndex is int ? legIndex : null,
    );
  }
}

class TaxiWaysResult {
  final String version;
  final WayPlace from;
  final WayPlace to;
  final WayBest? bestWay;
  final List<WayDriver> allTheWay;
  final bool allTheWayHasMore;
  final List<WayPlan> plans;
  final bool truncated;
  final List<TaxiBrowseItem> localTaxis;
  final List<StayNearbyModel> stays;
  final WayPlace? reachFirstPlace;
  final bool roadLines;

  const TaxiWaysResult({
    required this.version,
    required this.from,
    required this.to,
    this.bestWay,
    this.allTheWay = const [],
    this.allTheWayHasMore = false,
    this.plans = const [],
    this.truncated = false,
    this.localTaxis = const [],
    this.stays = const [],
    this.reachFirstPlace,
    this.roadLines = false,
  });

  factory TaxiWaysResult.fromJson(Map<String, dynamic> json) => TaxiWaysResult(
        version: '${json['version'] ?? ''}',
        from: WayPlace.tryParse(json['from']) ?? const WayPlace(key: '', name: '', lat: 0, lng: 0, resolved: false),
        to: WayPlace.tryParse(json['to']) ?? const WayPlace(key: '', name: '', lat: 0, lng: 0, resolved: false),
        bestWay: WayBest.tryParse(json['bestWay']),
        allTheWay: _list(json['allTheWay'], WayDriver.fromJson),
        allTheWayHasMore: json['allTheWayHasMore'] == true,
        plans: _list(json['plans'], WayPlan.fromJson),
        truncated: json['truncated'] == true,
        localTaxis: _list(json['localTaxis'], TaxiBrowseItem.fromJson),
        stays: _list(json['stays'], StayNearbyModel.fromJson),
        reachFirstPlace: WayPlace.tryParse(json['reachFirstPlace']),
        roadLines: json['roadLines'] == true,
      );

  bool get hasWays => allTheWay.isNotEmpty || plans.isNotEmpty;
}

int rowCars(Object o, int people) => o is WayDriver ? o.carsFor(people) : (o as WayPlan).carHires;

// The whole group's price for a row: a driver's fare x his cars, a plan's total.
int rowPrice(Object o, int people) => o is WayDriver ? o.groupFare(people) : (o as WayPlan).total;

// Fewest cars: by cars, plans by total inside a car count, drivers keep the server order. Lowest price: by group
// price, then cars. Both stable.
List<Object> sortedRows(TaxiWaysResult r, WaysSort s, {int people = 1}) {
  final rows = <Object>[...r.allTheWay, ...r.plans];
  if (s == WaysSort.fewestCars) {
    _stableSort(rows, (a, b) {
      final c = rowCars(a, people).compareTo(rowCars(b, people));
      if (c != 0) return c;
      if (a is WayPlan && b is WayPlan) return a.total.compareTo(b.total);
      if (a is WayDriver && b is WayPlan) return -1;
      if (a is WayPlan && b is WayDriver) return 1;
      return 0;
    });
    return rows;
  }
  _stableSort(rows, (a, b) {
    final c = rowPrice(a, people).compareTo(rowPrice(b, people));
    return c != 0 ? c : rowCars(a, people).compareTo(rowCars(b, people));
  });
  return rows;
}

void _stableSort<T>(List<T> list, int Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < indexed.length; i++) {
    list[i] = indexed[i].$2;
  }
}
