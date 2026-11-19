import 'dart:io';

import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/widgets/trip_add_city_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'support/engine_rig.dart';

const _uk = 'Uttarakhand';
const _hp = 'Himachal Pradesh';
const _pb = 'Punjab';

TripCityModel _c(int k, String name, String state, {double lat = 29.5, double lng = 79.5}) =>
    TripCityModel(cityKey: k, name: name, stateName: state, latitude: lat, longitude: lng);

final _nainital = _c(1, 'Nainital', _uk, lat: 29.4, lng: 79.4);
final _almora = _c(2, 'Almora', _uk, lat: 29.6, lng: 79.6);
final _kausani = _c(3, 'Kausani', _hp, lat: 29.8, lng: 79.6);
final _bhimtal = _c(10, 'Bhimtal', _uk, lat: 29.35, lng: 79.55);
final _shimla = _c(20, 'Shimla', _hp, lat: 29.41, lng: 79.41);
final _amritsar = _c(30, 'Amritsar', _pb, lat: 29.42, lng: 79.42);

void _seed(List<TripCityModel> cities) => TripCityCatalog.to.seedForTest(cities);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('state_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  test('a city of another state is blocked, the same state is allowed', () {
    _seed([_nainital, _almora, _bhimtal, _shimla]);
    final c = engineRig(enginePlan([[1]]));
    expect(c.canAddLeg(_shimla), TripLegEditBlock.otherState);
    expect(c.canAddLeg(_bhimtal), TripLegEditBlock.none);
    expect(c.canAddLeg(null), TripLegEditBlock.none);
  });

  test('the candidate state is read from the catalog, not from the passed model', () {
    _seed([_nainital, _shimla]);
    final c = engineRig(enginePlan([[1]]));
    expect(c.canAddLeg(_c(20, 'Shimla', _uk)), TripLegEditBlock.otherState);
  });

  test('empty catalog allows the city', () {
    _seed(const []);
    final c = engineRig(enginePlan([[1]]));
    expect(c.canAddLeg(_shimla), TripLegEditBlock.none);
  });

  test('a candidate missing from the catalog is allowed', () {
    _seed([_nainital]);
    final c = engineRig(enginePlan([[1]]));
    expect(c.canAddLeg(_shimla), TripLegEditBlock.none);
  });

  test('plan cities unknown to the catalog allow any state', () {
    _seed([_shimla]);
    final c = engineRig(enginePlan([[1]]));
    expect(c.canAddLeg(_shimla), TripLegEditBlock.none);
  });

  test('an old two-state plan allows both its states and blocks a third', () {
    _seed([_nainital, _almora, _kausani, _bhimtal, _shimla, _amritsar]);
    final c = engineRig(enginePlan([[1], [1], [1]]));
    expect(c.canAddLeg(_bhimtal), TripLegEditBlock.none);
    expect(c.canAddLeg(_shimla), TripLegEditBlock.none);
    expect(c.canAddLeg(_amritsar), TripLegEditBlock.otherState);
  });

  test('addLeg refuses a city of another state and keeps the plan', () async {
    _seed([_nainital, _shimla]);
    final c = engineRig(enginePlan([[1]]));
    final before = c.plan.value;
    expect(await c.addLeg(_shimla, const []), TripLegEditBlock.otherState);
    expect(identical(c.plan.value, before), isTrue);
  });

  test('Add a city card names only cities of the plan state', () {
    _seed([_nainital, _almora, _bhimtal, _shimla, _amritsar]);
    expect(TripAddCityCard.nearbyNames(enginePlan([[1]])), ['Bhimtal', 'Almora']);
  });

  test('Add a city card falls back to every state when the plan state is unknown', () {
    _seed([_bhimtal, _shimla]);
    expect(TripAddCityCard.nearbyNames(enginePlan([[1]])), ['Shimla', 'Bhimtal']);
  });
}
