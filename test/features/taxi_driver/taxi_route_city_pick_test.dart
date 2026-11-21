import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_route_city_sheet.dart';
import 'package:bakhli/features/taxi/setup/taxi_route_strings.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';
import '../../support/owner_fakes.dart';
import '../../support/real_phone.dart';

class _Auth extends JAuth {
  @override
  bool get taxisEnabled {
    user.value;
    return true;
  }

  @override
  Future<void> refreshProfile() async {}
}

class _Taxi extends TaxiSetupController {
  final List<List<Map<String, dynamic>>> saved = [];

  @override
  Future<bool> load() async => true;

  @override
  Future<bool> saveRoutes(List<Map<String, dynamic>> routes) async {
    saved.add(routes);
    return true;
  }
}

const _haldwani = TripCityModel(cityKey: 210108988, name: 'Haldwani', districtName: 'Nainital', stateName: 'Uttarakhand', latitude: 29.22, longitude: 79.51);
const _nainital = TripCityModel(cityKey: 210109088, name: 'Nainital', districtName: 'Nainital', stateName: 'Uttarakhand', latitude: 29.39, longitude: 79.45);
const _almora = TripCityModel(cityKey: 210003898, name: 'Almora', districtName: 'Almora', stateName: 'Uttarakhand', latitude: 29.6, longitude: 79.66);

Map<String, dynamic> _routeJson(String id, String from, String to,
        {int? fromKey, int? toKey, bool fromOther = false, bool toOther = false, double toLat = 29.39}) =>
    {
      'id': id,
      'routeIndex': 1,
      'fromName': from,
      'fromLatitude': 29.22,
      'fromLongitude': 79.51,
      'toName': to,
      'toLatitude': toLat,
      'toLongitude': 79.45,
      'fare': 1500,
      'tripType': 'OneWay',
      'fromCityKey': ?fromKey,
      'toCityKey': ?toKey,
      if (fromOther) 'fromOtherPlace': true,
      if (toOther) 'toOtherPlace': true,
    };

TaxiOwnerModel _taxi(List<Map<String, dynamic>> routes, {String? city}) => TaxiOwnerModel.fromJson({
      'id': 't1',
      'status': 'Draft',
      'step1Done': true,
      'localDayRate': 2500,
      'localDayKm': 120,
      'cityName': ?city,
      'latitude': 29.22,
      'longitude': 79.51,
      'routes': routes,
    });

_Taxi _setup(TaxiOwnerModel model) {
  Get.reset();
  Get.put<LocationController>(JLoc());
  Get.put<AuthController>(_Auth()).user.value =
      UserModel.fromJson({'id': 'u1', 'phoneNumber': '9876543210', 'name': 'Pradeep', 'createdAt': '2026-01-01T00:00:00Z'});
  Get.put<TabConfigController>(JTabs());
  Get.put<TripCityCatalog>(TripCityCatalog()..seedForTest(const [_haldwani, _nainital, _almora]), permanent: true);
  final c = Get.put<TaxiSetupController>(_Taxi()) as _Taxi;
  c.taxi.value = model;
  return c;
}

Future<void> _open(WidgetTester t, {Size size = const Size(360, 800), double scale = 1}) async {
  await pumpPhone(t, const TaxiRoutesScreen(), size: size, textScale: scale, toastHost: true);
  await settlePhone(t);
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _save(WidgetTester t) async {
  await t.tap(find.text('Save').last);
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _clearToasts(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() => PlanGate.debugPlan = OwnerPlans.paymentOff);
  tearDown(() {
    PlanGate.debugPlan = null;
    Get.reset();
  });

  group('route model', () {
    test('reads chosen keys, other place flags and the active flag', () {
      final r = TaxiRouteModel.fromJson(_routeJson('a', 'Haldwani', 'Nainital', fromKey: 210108988, toKey: 210109088)..['activeInRequests'] = true);
      expect((r.fromCityKey, r.toCityKey, r.activeInRequests, r.fromOtherPlace), (210108988, 210109088, true, false));
      final other = TaxiRouteModel.fromJson(_routeJson('b', 'Haldwani', 'Small place', fromKey: 210108988, toOther: true));
      expect((other.toCityKey, other.toOtherPlace, other.activeInRequests), (null, true, false));
    });

    test('old server without the field: active follows both keys', () {
      expect(TaxiRouteModel.fromJson(_routeJson('a', 'H', 'N', fromKey: 1, toKey: 2)).activeInRequests, isTrue);
      expect(TaxiRouteModel.fromJson(_routeJson('a', 'H', 'N', toKey: 2)).activeInRequests, isFalse);
      expect(TaxiRouteModel.fromJson(_routeJson('a', 'H', 'N', fromKey: 0, toKey: 2)).fromCityKey, isNull);
    });
  });

  group('city sheet', () {
    testWidgets('lists the live cities, a tap returns the city with its key', (t) async {
      _setup(_taxi(const []));
      TaxiRouteCityChoice? got;
      await pumpPhone(
        t,
        Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: TextButton(
                onPressed: () async => got = await TaxiRouteCitySheet.pick(c, title: TaxiRouteStrings.toCity),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await settlePhone(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.text(TaxiRouteStrings.toCity), findsOneWidget);
      expect(find.text('Almora'), findsOneWidget);
      await t.enterText(find.byType(EditableText), 'naini');
      await t.pump();
      expect(find.text('Almora'), findsNothing);
      await t.tap(find.text('Nainital').last);
      await settlePhone(t);
      expect(got, isA<TaxiRouteCityPicked>());
      expect((got as TaxiRouteCityPicked).city.cityKey, 210109088);
    });

    testWidgets('Other place returns the explicit other place choice', (t) async {
      _setup(_taxi(const []));
      TaxiRouteCityChoice? got;
      await pumpPhone(
        t,
        Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: TextButton(
                onPressed: () async => got = await TaxiRouteCitySheet.pick(c, title: TaxiRouteStrings.fromCity),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await settlePhone(t);
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(TaxiRouteStrings.otherPlace));
      await settlePhone(t);
      expect(got, isA<TaxiRouteOtherPlace>());
    });

    testWidgets('no match shows the empty line', (t) async {
      _setup(_taxi(const []));
      await pumpPhone(t, Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => TaxiRouteCitySheet.pick(c, title: 'x'), child: const Text('open')))));
      await t.tap(find.text('open'));
      await settlePhone(t);
      await t.pump(const Duration(seconds: 1));
      await t.enterText(find.byType(EditableText), 'zzzz');
      await t.pump();
      expect(find.text(TaxiRouteStrings.noCityMatch('zzzz')), findsOneWidget);
    });
  });

  group('route screen', () {
    testWidgets('a new route picked from the list sends both city keys', (t) async {
      final c = _setup(_taxi(const [], city: 'Haldwani'));
      await _open(t);
      expect(find.text('Haldwani'), findsOneWidget, reason: 'first From comes from the list when the base city is live');
      await _tapText(t, TaxiRouteStrings.chooseCity);
      await settlePhone(t);
      await t.tap(find.text('Nainital').last);
      await settlePhone(t);
      await t.enterText(find.byType(EditableText).at(2), '1800');
      await _tapText(t, 'One way');
      await _save(t);
      expect(c.saved, hasLength(1));
      final body = c.saved.single.single;
      expect(body['fromCityKey'], 210108988);
      expect(body['toCityKey'], 210109088);
      expect(body['fromOtherPlace'], isFalse);
      expect(body['toOtherPlace'], isFalse);
      expect(body['toLatitude'], _nainital.latitude);
      expect(t.takeException(), isNull);
      await _clearToasts(t);
    });

    testWidgets('keyed and other place routes show their state and resend their choice', (t) async {
      final c = _setup(_taxi([
        _routeJson('r1', 'Haldwani', 'Nainital', fromKey: 210108988, toKey: 210109088),
        _routeJson('r2', 'Haldwani', 'Kainchi', fromKey: 210108988, toOther: true, toLat: 29.42),
      ]));
      await _open(t, size: const Size(360, 1400));
      expect(find.text(TaxiRouteStrings.activeInRequests), findsOneWidget);
      expect(find.text(TaxiRouteStrings.notActive), findsOneWidget);
      await _save(t);
      final sent = c.saved.single;
      expect((sent[0]['fromCityKey'], sent[0]['toCityKey'], sent[0]['toOtherPlace']), (210108988, 210109088, false));
      expect((sent[1]['fromCityKey'], sent[1]['toCityKey'], sent[1]['toOtherPlace']), (210108988, null, true));
      await _clearToasts(t);
    });

    testWidgets('an old route without keys is resent as before, with no city fields', (t) async {
      final c = _setup(_taxi([_routeJson('r1', 'Haldwani', 'Almora', fromKey: 210108988)]));
      await _open(t, size: const Size(360, 1400));
      expect(find.text(TaxiRouteStrings.notActive), findsOneWidget);
      await _save(t);
      final body = c.saved.single.single;
      expect(body.containsKey('fromCityKey'), isFalse);
      expect(body.containsKey('toOtherPlace'), isFalse);
      await _clearToasts(t);
    });

    testWidgets('editing an old route asks for the city from the list', (t) async {
      final c = _setup(_taxi([_routeJson('r1', 'Haldwani', 'Almora', fromKey: 210108988)]));
      await _open(t, size: const Size(360, 1400));
      await t.tap(find.byTooltip('Edit route').first);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text(TaxiRouteStrings.otherPlaceNote), findsOneWidget);
      await t.tap(find.text('Save').last);
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 600));
      expect(c.saved, isEmpty);
      expect(find.text(TaxiRouteStrings.chooseToAgain), findsOneWidget);
      await _clearToasts(t);
    });

    for (final cfg in const [(1.0, 360.0), (1.3, 360.0), (1.0, 300.0), (1.15, 412.0), (2.0, 360.0)]) {
      testWidgets('route list fits at scale ${cfg.$1} width ${cfg.$2}', (t) async {
        _setup(_taxi([
          _routeJson('r1', 'Haldwani', 'Nainital', fromKey: 210108988, toKey: 210109088),
          _routeJson('r2', 'Haldwani', 'Kainchi Dham', fromKey: 210108988, toOther: true, toLat: 29.42),
        ]));
        await _open(t, size: Size(cfg.$2, 1600), scale: cfg.$1);
        expect(find.text(TaxiRouteStrings.activeInRequests), findsOneWidget);
        expect(find.text(TaxiRouteStrings.notActive), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });
}
