import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/features/stay/guest/stay_guest_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../journeys/fake_api.dart';

Map<String, Object?> _item(String id) => {'id': id, 'latitude': 30.0, 'longitude': 79.0, 'distanceKm': 1.0};

void main() {
  late FakeTripAdapter api;
  late StayGuestController c;

  setUp(() {
    Get.testMode = true;
    api = installFakeApi([
      FakeRoute('GET', '/stays/nearby', (o) => {'items': [_item('r${o.queryParameters['radius']}')]}),
      FakeRoute.value('GET', '/stays/nearest', {'items': [_item('n1')]}),
    ]);
    c = StayGuestController();
  });

  test('radius options and default', () {
    expect(AppConstants.radiusOptions, [1.0, 6.0, 12.0, 20.0]);
    expect(AppConstants.defaultRadiusKm, 12.0);
  });

  test('nearby sends only latitude, longitude and radius', () async {
    await c.loadNearby(30.0, 79.0, 12);
    final q = api.calls('GET', '/stays/nearby').single.queryParameters;
    expect(q.keys.toSet(), {'latitude', 'longitude', 'radius'});
    expect(q['radius'], 12.0);
    expect(c.nearbyStays.single.id, 'r12.0');
  });

  test('nearest sends only latitude, longitude and count', () async {
    await c.loadNearest(30.0, 79.0);
    final q = api.calls('GET', '/stays/nearest').single.queryParameters;
    expect(q.keys.toSet(), {'latitude', 'longitude', 'count'});
    expect(q['count'], AppConstants.nearestFallbackCount);
    expect(api.calls('GET', '/trips/cities/nearest'), isEmpty);
  });

  test('cache serves repeat and rounded-equal calls, refresh refetches', () async {
    await c.loadNearby(30.0001, 79.0001, 6);
    await c.loadNearby(30.0004, 79.0002, 6);
    expect(api.calls('GET', '/stays/nearby').length, 1);
    await c.loadNearby(30.0, 79.0, 12);
    await c.loadNearby(30.0, 79.0, 6);
    expect(api.calls('GET', '/stays/nearby').length, 2);
    expect(c.nearbyStays.single.id, 'r6.0');
    await c.loadNearby(30.0, 79.0, 6, refresh: true);
    expect(api.calls('GET', '/stays/nearby').length, 3);
    c.clearNearbyCache();
    await c.loadNearby(30.0, 79.0, 6);
    expect(api.calls('GET', '/stays/nearby').length, 4);
  });

  test('stale nearby response does not overwrite the newer one', () async {
    final first = c.loadNearby(30.0, 79.0, 1);
    final second = c.loadNearby(30.0, 79.0, 20);
    await Future.wait([first, second]);
    expect(c.nearbyStays.single.id, 'r20.0');
    expect(c.isLoading.value, false);
  });
}
