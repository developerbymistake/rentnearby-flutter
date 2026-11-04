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
  });

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
    final fare = drivers.isEmpty ? 0 : drivers.first.listedFare;
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

  List<WayPlace> get changePlaces => [for (var i = 0; i < legs.length - 1; i++) legs[i].to];

  int totalWith(Map<int, WayDriver> chosen) {
    var sum = 0;
    for (final leg in legs) {
      sum += chosen[leg.index]?.listedFare ?? leg.listedFare;
    }
    return sum;
  }
}

typedef WayPlanDetail = WayPlan;

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

List<Object> sortedRows(TaxiWaysResult r, WaysSort s) {
  final rows = <Object>[...r.allTheWay];
  final plans = [...r.plans];
  _stableSort(plans, (a, b) {
    final c = a.cars.compareTo(b.cars);
    return c != 0 ? c : a.total.compareTo(b.total);
  });
  rows.addAll(plans);
  if (s == WaysSort.fewestCars) return rows;
  int price(Object o) => o is WayDriver ? o.listedFare : (o as WayPlan).total;
  _stableSort(rows, (a, b) => price(a).compareTo(price(b)));
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
