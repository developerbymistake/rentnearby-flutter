import 'dart:async';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_journey_date.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

TaxiFeedItem fi(String id) => TaxiFeedItem(
      item: TaxiBrowseItem(
        id: id,
        driverName: id,
        vehicleTypeName: 'Sedan',
        plateDisplay: '',
        routeCount: 1,
        matchReversed: false,
        createdAt: DateTime(2026),
      ),
    );

class FakeRepo extends TaxiFeedRepository {
  final localCalls = <({double lat, String? token, String? date})>[];
  final routeCalls = <({double fromLat, double toLat, String? date, String sort, TaxiCityPair? cities})>[];
  final tierCalls = <String>[];
  final tierCities = <TaxiCityPair?>[];
  int popularCalls = 0;
  Completer<NearbyPage<TaxiFeedItem>>? gate;
  NearbyPage<TaxiFeedItem> Function(String? token) localPage = (t) => NearbyPage(items: [fi('a'), fi('b')]);
  TaxiRouteFeed routeFeed = const TaxiRouteFeed();
  TaxiRouteFeed Function(String? date, String sort)? routeFor;
  final routeGates = <Completer<TaxiRouteFeed>>[];
  bool gateRoutes = false;
  Object? routeError;
  bool rejectDate = false;
  bool rejectTierDate = false;
  Completer<TaxiTier?>? tierGate;
  List<TaxiPopularRoute> popular = const [];
  Object? popularError;
  Completer<List<TaxiPopularRoute>>? popularGate;

  @override
  Future<NearbyPage<TaxiFeedItem>> local({
    required double lat,
    required double lng,
    String? pageToken,
    int pageSize = 20,
    String? category,
    String? date,
  }) {
    localCalls.add((lat: lat, token: pageToken, date: date));
    if (rejectDate && date != null) return Future.error(const TaxiInvalidDateError());
    final g = gate;
    if (g != null && pageToken == null) {
      gate = null;
      return g.future;
    }
    try {
      return Future.value(localPage(pageToken));
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<TaxiRouteFeed> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
    String? date,
    String sort = 'nearest',
    TaxiCityPair? cities,
  }) {
    routeCalls.add((fromLat: fromLat, toLat: toLat, date: date, sort: sort, cities: cities));
    if (rejectDate && date != null) return Future.error(const TaxiInvalidDateError());
    final e = routeError;
    if (e != null) return Future.error(e);
    if (gateRoutes) {
      final c = Completer<TaxiRouteFeed>();
      routeGates.add(c);
      return c.future;
    }
    final f = routeFor;
    return Future.value(f != null ? f(date, sort) : routeFeed);
  }

  @override
  Future<TaxiTier?> routeTier({
    required String tier,
    required String pageToken,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
    String? date,
    String sort = 'nearest',
    TaxiCityPair? cities,
  }) {
    tierCalls.add('$tier:$pageToken:$date:$sort');
    tierCities.add(cities);
    if (rejectTierDate && date != null) return Future.error(const TaxiInvalidDateError());
    final g = tierGate;
    if (g != null) {
      tierGate = null;
      return g.future;
    }
    return Future.value(TaxiTier(key: tier, items: [fi('n1'), fi('r1')]));
  }

  @override
  Future<List<TaxiPopularRoute>> popularRoutes() {
    popularCalls++;
    final g = popularGate;
    if (g != null) return g.future;
    final e = popularError;
    return e != null ? Future.error(e) : Future.value(popular);
  }
}

PlaceResult place(String n, double lat) => PlaceResult(name: n, subtitle: '', latLng: LatLng(lat, 79));

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
