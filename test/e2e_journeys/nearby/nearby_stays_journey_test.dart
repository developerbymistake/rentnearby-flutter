import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../ui_golden/golden_support.dart';
import 'nearby_support.dart';

Map<String, dynamic> _stay(String id, {double km = 3.2, String label = 'near', String? city = 'Nainital', String? state = 'Uttarakhand', bool featured = false}) => {
      'id': id,
      'userId': 'u',
      'name': 'Stay $id',
      'cityName': city,
      'districtName': 'Nainital',
      'stateName': state,
      'minPricePerNight': 1200,
      'isFeatured': featured,
      'distanceKm': km,
      'labelKey': label,
    };

StayFeedItem _item(String id, {double km = 3.2, String label = 'near', String? city = 'Nainital', bool featured = false}) =>
    StayFeedItem.fromJson(_stay(id, km: km, label: label, city: city, featured: featured));

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

class _Stays extends StayLandingControllerV2 {
  final centres = <LatLng>[];
  final tokens = <String?>[];
  NearbyPage<StayFeedItem> Function(LatLng centre, String? token) answer = (_, _) => const NearbyPage();

  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async {
    final c = NearbyCentreController.to.centre;
    centres.add(c);
    tokens.add(token);
    return answer(c, token);
  }
}

late JLoc _loc;
late _Stays _ctrl;

void _setUpApp({LatLng gps = const LatLng(29.2, 79.5)}) {
  Get.reset();
  _loc = Get.put<LocationController>(JLoc()) as JLoc;
  _loc.userLocation.value = gps;
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put<StayTypesController>(_Types());
  Get.put(NearbyCentreController());
  _ctrl = Get.put<StayLandingControllerV2>(_Stays(), tag: StayLandingControllerV2.tag) as _Stays;
}

Future<void> _open(WidgetTester t, {double w = 360, double s = 1, double h = 2600}) {
  _ctrl.reload();
  return pumpJourney(t, const StayLandingScreenV2(), width: w, scale: s, height: h);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  testWidgets('Haldwani: nearest stays with city and distance, no far wording', (t) async {
    _setUpApp();
    _ctrl.answer = (_, _) => NearbyPage(items: [
          _item('a', km: 1, label: 'inCity', city: 'Haldwani'),
          _item('b', km: 12, city: 'Kathgodam'),
          _item('c', km: 25, label: 'far', city: 'Nainital'),
        ]);
    await _open(t);
    expect(find.text('Stays near you'), findsOneWidget);
    expect(find.text('In Haldwani'), findsOneWidget);
    expect(find.text('Kathgodam. About 12 km away'), findsOneWidget);
    expect(find.textContaining('We are live in'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Village pin: nearest town line shows, list still opens', (t) async {
    _setUpApp();
    _ctrl.answer = (_, _) => NearbyPage(
          header: const NearbyHeader(centreCityName: 'Nainital', centreCityKm: 12),
          items: [_item('a', km: 9, city: 'Bhimtal'), _item('b', km: 14, city: 'Nainital')],
        );
    await _open(t);
    NearbyCentreController.to.setPin(const LatLng(29.45, 79.55), 'Satkhol village');
    await flush(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Showing near Satkhol village'), findsNothing);
    expect(find.text('Search any place'), findsNothing);
    expect(find.text('Nearest town: Nainital, about 12 km'), findsOneWidget);
    expect(find.text('Stays near Satkhol village'), findsOneWidget);
    expect(find.text('Bhimtal. About 9 km away'), findsOneWidget);
  });

  testWidgets('Delhi: far label, live-in line, never near you', (t) async {
    _setUpApp(gps: const LatLng(28.6, 77.2));
    _ctrl.answer = (_, _) => NearbyPage(
          header: const NearbyHeader(farAway: true, nearestKm: 210),
          items: [_item('a', km: 210, label: 'far', city: 'Haridwar'), _item('b', km: 420, label: 'near', city: 'Haldwani')],
        );
    await _open(t);
    expect(find.text('Nearest stays'), findsOneWidget);
    expect(find.textContaining('Haridwar, Uttarakhand. About 210 km away'), findsOneWidget);
    expect(find.textContaining('Haldwani, Uttarakhand. About 420 km away'), findsOneWidget);
    expect(find.textContaining('By road it can take longer.'), findsNWidgets(2));
    expect(find.text('Using my location'), findsNothing);
    expect(find.text('Stays near you'), findsNothing);
    expect(find.text('Showing near you'), findsNothing);
  });

  testWidgets('whole system empty is the only empty state', (t) async {
    _setUpApp(gps: const LatLng(28.6, 77.2));
    await _open(t);
    expect(find.text('No stays listed yet'), findsOneWidget);
  });

  testWidgets('paging: scrolling loads the next page once, no duplicates', (t) async {
    _setUpApp();
    _ctrl.answer = (_, tok) => tok == null
        ? NearbyPage(items: [for (var i = 0; i < 12; i++) _item('p1_$i', km: i + 1.0)], hasMore: true, nextToken: 't2')
        : NearbyPage(items: [_item('p1_11', km: 12), for (var i = 0; i < 4; i++) _item('p2_$i', km: 13 + i.toDouble())]);
    await _open(t, h: 700);
    expect(_ctrl.items.length, 12);
    expect(_ctrl.hasMore.value, true);
    for (var i = 0; i < 6 && _ctrl.items.length < 16; i++) {
      await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(_ctrl.tokens.where((x) => x == 't2').length, 1);
    expect(_ctrl.tokens.last, 't2');
    expect(_ctrl.items.length, 16);
    expect(_ctrl.hasMore.value, false);
    expect(t.takeException(), isNull);
  });

  testWidgets('featured slot: one clearly labelled card above the list', (t) async {
    _setUpApp();
    _ctrl.answer = (_, _) => NearbyPage(featured: [_item('f', km: 4, featured: true)], items: [_item('f', km: 4, featured: true), _item('a', km: 1), _item('b', km: 2)]);
    await _open(t);
    expect(find.text('Featured near you'), findsOneWidget);
    expect(_ctrl.items.length, 2);
    expect(find.text('Stay f'), findsOneWidget);
    final slot = t.getTopLeft(find.text('Featured near you')).dy;
    final first = t.getTopLeft(find.text('Stay a')).dy;
    expect(slot, lessThan(first));
  });

  testWidgets('Photon pin sets the centre, even one from an OFF district', (t) async {
    _setUpApp();
    _loc.selectedDistrict.value = DistrictModel(id: 'd', name: 'Nainital');
    _loc.autoCity.value = CityModel(id: 'c', districtId: 'd', name: 'Haldwani', latitude: 29.2, longitude: 79.5);
    _ctrl.answer = (c, _) => NearbyPage(items: [_item('a', km: c.latitude > 30 ? 250 : 2, label: c.latitude > 30 ? 'far' : 'near')]);
    await _open(t);
    expect(_ctrl.centres.last.latitude, 29.2);
    NearbyCentreController.to.setPin(const LatLng(31.1, 77.17), 'Shimla');
    await flush(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(_ctrl.centres.last.latitude, 31.1);
    expect(_ctrl.centres.last.longitude, closeTo(77.17, 0.001));
    expect(find.text('Stays near Shimla'), findsOneWidget);
    expect(find.text('Showing near Shimla'), findsNothing);
    NearbyCentreController.to.clearPin();
    await flush(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(_ctrl.centres.last.latitude, 29.2);
    expect(find.text('Stays near you'), findsOneWidget);
    expect(find.text('Showing near you'), findsNothing);
  });

  testWidgets('top area has only the old controls: Search, location pill, Filter & Sort', (t) async {
    _setUpApp();
    _ctrl.answer = (_, _) => NearbyPage(items: [_item('a'), _item('b')]);
    await _open(t);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(find.text('Filter & Sort'), findsOneWidget);
    for (final gone in ['Showing near you', 'Search any place', 'Use my location', 'Using my location']) {
      expect(find.text(gone), findsNothing);
    }
    expect(find.byType(TextField), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Filter & Sort opens, meals filter reloads the feed, price sort reorders', (t) async {
    _setUpApp();
    _ctrl.answer = (_, _) => NearbyPage(items: [_item('a'), _item('b')]);
    await _open(t, h: 760);
    final before = _ctrl.centres.length;
    await t.tap(find.text('Filter & Sort'));
    await t.pump(const Duration(milliseconds: 800));
    await t.pump(const Duration(milliseconds: 800));
    expect(find.text('Filter & Sort · Stays'), findsOneWidget);
    await t.tap(find.text('All meals'));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('Apply'));
    await t.pump(const Duration(milliseconds: 800));
    await t.pump(const Duration(milliseconds: 800));
    expect(find.text('Apply'), findsNothing);
    await flush(t);
    expect(_ctrl.selectedMeals.value, 'AllMeals');
    expect(_ctrl.centres.length, greaterThan(before));
    expect(_ctrl.sorted([StayFeedItem.fromJson(_stay('x'))]).length, 1);
    _ctrl.sortBy.value = 'price_desc';
    final cheap = StayFeedItem.fromJson({..._stay('c'), 'minPricePerNight': 500});
    final dear = StayFeedItem.fromJson({..._stay('d'), 'minPricePerNight': 3000});
    expect(_ctrl.sorted([cheap, dear]).first.id, 'd');
    _ctrl.sortBy.value = 'price_asc';
    expect(_ctrl.sorted([dear, cheap]).first.id, 'c');
  });

  testWidgets('Search opens the existing location search', (t) async {
    _setUpApp();
    _ctrl.answer = (_, _) => NearbyPage(items: [_item('a')]);
    await _open(t);
    await t.tap(find.bySemanticsLabel('Search'));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('load failure offers retry', (t) async {
    _setUpApp();
    var fail = true;
    _ctrl.answer = (_, _) {
      if (fail) throw Exception('x');
      return NearbyPage(items: [_item('a')]);
    };
    await _open(t);
    expect(find.text('Could not load the list'), findsOneWidget);
    fail = false;
    await t.tap(find.text('Try again'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Could not load the list'), findsNothing);
    expect(find.text('Stay a'), findsOneWidget);
  });

  for (final w in journeyWidths) {
    for (final s in journeyScales) {
      testWidgets('far list with featured and pin fits at ${w.toInt()} dp, text scale $s', (t) async {
        _setUpApp(gps: const LatLng(28.6, 77.2));
        _ctrl.answer = (_, _) => NearbyPage(
              header: const NearbyHeader(
                farAway: true,
                centreCityName: 'A very long town name in the hills',
                centreCityKm: 14,
              ),
              featured: [_item('f', km: 210, label: 'far', city: 'Haridwar', featured: true)],
              items: [for (var i = 0; i < 6; i++) _item('a$i', km: 300.0 + i, label: 'far', city: 'Haldwani')],
            );
        await _open(t, w: w, s: s);
        NearbyCentreController.to.setPin(const LatLng(30, 78), 'A very long place name in the hills, Uttarakhand');
        await flush(t);
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('Featured near you'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
