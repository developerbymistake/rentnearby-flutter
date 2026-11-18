import 'package:bakhli/config/app_map_state.dart';
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart' show AppTabKeys;
import 'package:bakhli/services/map_pause_observer.dart';
import 'package:bakhli/widgets/global_location_gates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _contract = <String, String>{
  'tripName': '/trip-name',
  'tripCustomize': '/trip-customize',
  'tripOverview': '/trip-overview',
  'tripTaxiRequest': '/trip-taxi-request',
  'tripTaxiStatus': '/trip-taxi-status',
  'taxiRequestRing': '/taxi-request-ring',
  'taxiRequests': '/taxi-requests',
  'taxiRequestDetail': '/taxi-request-detail',
  'taxiBookings': '/taxi-bookings',
  'taxiRating': '/taxi-rating',
  'taxiReady': '/taxi-ready',
};

final _constants = <String, String>{
  'tripName': AppRoutes.tripName,
  'tripCustomize': AppRoutes.tripCustomize,
  'tripOverview': AppRoutes.tripOverview,
  'tripTaxiRequest': AppRoutes.tripTaxiRequest,
  'tripTaxiStatus': AppRoutes.tripTaxiStatus,
  'taxiRequestRing': AppRoutes.taxiRequestRing,
  'taxiRequests': AppRoutes.taxiRequests,
  'taxiRequestDetail': AppRoutes.taxiRequestDetail,
  'taxiBookings': AppRoutes.taxiBookings,
  'taxiRating': AppRoutes.taxiRating,
  'taxiReady': AppRoutes.taxiReady,
};

const _travellerFive = {'/trip-name', '/trip-customize', '/trip-overview', '/trip-taxi-request', '/trip-taxi-status'};

const _driverSix = [
  '/taxi-request-ring',
  '/taxi-requests',
  '/taxi-request-detail',
  '/taxi-bookings',
  '/taxi-rating',
  '/taxi-ready',
];

void main() {
  test('every_new_route_constant_has_the_contract_value', () {
    expect(_constants, _contract);
    expect(_constants.length, 11);
  });

  test('all_six_driver_routes_are_driver_only_and_taxi_tab_keyed', () {
    for (final r in _driverSix) {
      expect(AppRoutes.taxiDriverOnly.contains(r), isTrue, reason: r);
      expect(AppRoutes.tabKeyForRoute(r), AppTabKeys.taxi, reason: r);
    }
    expect(AppRoutes.taxiDriverOnly.contains('/trip-taxi-status'), isFalse);
    expect(AppRoutes.tabKeyForRoute(AppRoutes.tripLeads), AppTabKeys.taxi);
  });

  test('map_pauses_on_every_new_full_page_route', () {
    final observer = MapPauseObserver();
    for (final name in [..._contract.values, AppRoutes.tripTaxiReplies]) {
      mapShouldPause.value = false;
      final route = MaterialPageRoute<void>(settings: RouteSettings(name: name), builder: (_) => const SizedBox());
      observer.didPush(route, null);
      expect(mapShouldPause.value, isTrue, reason: name);
      observer.didPop(route, null);
      expect(mapShouldPause.value, isFalse, reason: name);
    }
    mapShouldPause.value = false;
  });

  test('trip_pages_skip_the_location_gates_and_driver_pages_do_not', () {
    for (final r in _contract.values.where((r) => r.startsWith('/trip-'))) {
      expect(GlobalLocationGates.locationExempt(r), isTrue, reason: r);
    }
    for (final r in _driverSix) {
      expect(GlobalLocationGates.locationExempt(r), isFalse, reason: r);
    }
  });

  test('can_open_route_is_false_until_a_page_is_registered', () {
    final auth = AuthController();
    expect(_travellerFive.length + _driverSix.length, _contract.length);
    for (final r in _contract.values) {
      expect(AppRoutes.isRegistered(r), isTrue, reason: r);
    }
    for (final r in _travellerFive) {
      expect(auth.canOpenRoute(r), isTrue, reason: r);
    }
    const unregistered = '/taxi-request-unknown';
    expect(AppRoutes.isRegistered(unregistered), isFalse);
    expect(auth.canOpenRoute(unregistered), isFalse);
  });

  test('a_seeker_cannot_open_the_registered_driver_pages', () {
    final auth = AuthController();
    expect(auth.canListTaxis.value, isFalse);
    for (final r in _driverSix) {
      expect(auth.canOpenRoute(r), isFalse, reason: r);
    }
  });
}
