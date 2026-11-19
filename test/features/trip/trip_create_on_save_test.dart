import 'dart:io';

import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import 'support/engine_rig.dart';

const _nainital = TripCityModel(cityKey: 1, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.4, longitude: 79.4);
const _almora = TripCityModel(cityKey: 2, name: 'Almora', stateName: 'Uttarakhand', latitude: 29.6, longitude: 79.6);

TripSpotModel _spot(String id) => TripSpotModel.fromJson({
      'id': id,
      'name': id,
      'latitude': 29.4,
      'longitude': 79.4,
      'category': 'attraction',
      'visitMinutes': 60,
    });

FakeRoute _planRoute() => FakeRoute('POST', '/trips/plan', (o) {
      final body = o.data as Map;
      final ids = [for (final s in body['spots'] as List) (s as Map)['id'] as String];
      return {
        'days': [
          {'day': 1, 'spotIds': ids, 'visitMinutes': 120, 'totalMinutes': 150},
        ],
        'osrmAvailable': true,
        'dayLimitMinutes': 300,
      };
    });

Map<String, dynamic> _echo(RequestOptions o) {
  final body = o.data as Map;
  return engineTripJson(
    TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
    extra: {'title': body['name'] ?? 'Family Hills', 'nameChosen': true},
  );
}

List<FakeRoute> _ok() => [
      _planRoute(),
      FakeRoute('POST', '/trips', _echo),
      FakeRoute('PUT', '/trips/{id}', _echo),
    ];

Map<String, dynamic> _sent(FakeTripAdapter api, String method, String path) =>
    Map<String, dynamic>.from(api.calls(method, path).last.data as Map);

Future<TripPlanController> _unsaved({TripCityModel city = _nainital}) async {
  final c = TripPlanController();
  addTearDown(c.onClose);
  await c.startFromSelection(city, [_spot('a'), _spot('b')]);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('create_on_save_gs').path);
    await GetStorage.init();
  });
  setUp(StorageService.clearTripNewDraft);
  tearDown(Get.reset);

  test('make_plan_creates_nothing', () async {
    final api = installFakeApi(_ok());
    final c = await _unsaved();
    expect(c.plan.value, isNotNull);
    expect(api.calls('POST', '/trips'), isEmpty);
    expect(c.trip.value, isNull);
    expect(c.isNewUnsaved, isTrue);
  });

  test('edits_before_save_create_nothing', () async {
    final api = installFakeApi(_ok());
    final c = await _unsaved();
    c.scheduleSave();
    expect(await c.saveNow(), isFalse);
    expect(await c.flushPendingSave(), isFalse);
    await c.flushForBackground();
    await c.releaseIfIdle();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.calls('POST', '/trips'), isEmpty);
    expect(c.saveFailed.value, isFalse);
  });

  test('new_plan_after_unsaved_plan_creates_nothing', () async {
    final api = installFakeApi(_ok());
    final c = await _unsaved();
    c.scheduleSave();
    await c.startFromSelection(_almora, [_spot('c')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.calls('POST', '/trips'), isEmpty);
    expect(c.isNewUnsaved, isTrue);
  });

  test('create_new_sends_name_dates_travellers_and_clears_draft', () async {
    final api = installFakeApi(_ok());
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b'])]);
    final c = await _unsaved();
    final start = daysFromToday(20);
    final r = await c.createNew(name: '  Family   Hills ', startDate: start, adults: 3, kids: 1);
    expect(r, TripCreateOutcome.ok);
    expect(api.calls('POST', '/trips'), hasLength(1));
    final body = _sent(api, 'POST', '/trips');
    expect(body['name'], 'Family Hills');
    expect(body['clientTripId'], isA<String>());
    final s = TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)).settings;
    expect(s.startDate, start);
    expect(s.adults, 3);
    expect(s.kids, 1);
    expect(StorageService.getTripNewDraft(), isNull);
    expect(c.isNewUnsaved, isFalse);
    expect(c.trip.value?.id, 't1');
    expect(c.title, 'Family Hills');
  });

  test('create_new_without_date_is_allowed', () async {
    final api = installFakeApi(_ok());
    final c = await _unsaved();
    expect(await c.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.ok);
    final s = TripPlan.fromJson(Map<String, dynamic>.from(_sent(api, 'POST', '/trips')['plan'] as Map)).settings;
    expect(s.startDate, isNull);
  });

  test('invalid_name_is_refused_without_a_call', () async {
    final api = installFakeApi(_ok());
    final c = await _unsaved();
    expect(await c.createNew(name: '   ', adults: 2, kids: 0), TripCreateOutcome.nameRejected);
    expect(await c.createNew(name: 'see www.x.com', adults: 2, kids: 0), TripCreateOutcome.nameRejected);
    expect(api.calls('POST', '/trips'), isEmpty);
    expect(c.isNewUnsaved, isTrue);
  });

  test('server_name_refusal_returns_name_rejected_and_no_banner', () async {
    installFakeApi([_planRoute(), FakeRoute.value('POST', '/trips', null, code: 400, errorType: 'TripNameInvalid')]);
    final c = await _unsaved();
    expect(await c.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.nameRejected);
    expect(c.isNewUnsaved, isTrue);
    expect(c.saveFailed.value, isFalse);
    expect(c.trip.value, isNull);
  });

  test('retry_after_failure_reuses_client_trip_id', () async {
    final down = installFakeApi([_planRoute(), FakeRoute.value('POST', '/trips', null, code: 500, errorType: 'ServerError')]);
    final c = await _unsaved();
    expect(await c.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.failed);
    expect(c.saveFailed.value, isFalse);
    expect(c.isNewUnsaved, isTrue);
    final first = _sent(down, 'POST', '/trips')['clientTripId'];

    final up = installFakeApi(_ok());
    expect(await c.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.ok);
    expect(_sent(up, 'POST', '/trips')['clientTripId'], first);
    expect(up.calls('POST', '/trips'), hasLength(1));
  });

  test('app_killed_before_create_reply_reuses_client_trip_id_after_reopen', () async {
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b'])]);
    final down = installFakeApi([_planRoute(), FakeRoute.value('POST', '/trips', null, code: 500, errorType: 'ServerError')]);
    final first = await _unsaved();
    expect(await first.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.failed);
    final sentId = _sent(down, 'POST', '/trips')['clientTripId'];
    expect(TripNewDraft.read()!.clientTripId, sentId);

    Get.reset();
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b'])]);
    final up = installFakeApi(_ok());
    final reopened = await _unsaved();
    expect(await reopened.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.ok);
    expect(_sent(up, 'POST', '/trips')['clientTripId'], sentId);
  });

  test('changed_places_after_a_lost_save_get_a_new_client_trip_id', () async {
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b'])]);
    final down = installFakeApi([_planRoute(), FakeRoute.value('POST', '/trips', null, code: 500, errorType: 'ServerError')]);
    final first = await _unsaved();
    await first.createNew(name: 'Lake Days', adults: 2, kids: 0);
    final sentId = _sent(down, 'POST', '/trips')['clientTripId'];

    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b', 'c'])]);
    expect(TripNewDraft.read()!.clientTripId, isNull);
    Get.reset();
    final up = installFakeApi(_ok());
    final c = TripPlanController();
    addTearDown(c.onClose);
    await c.startFromSelection(_nainital, [_spot('a'), _spot('b'), _spot('c')]);
    expect(await c.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.ok);
    expect(_sent(up, 'POST', '/trips')['clientTripId'], isNot(sentId));
  });

  test('after_create_edits_autosave_as_update', () async {
    final api = installFakeApi(_ok());
    final c = await _unsaved();
    expect(await c.createNew(name: 'Lake Days', adults: 2, kids: 0), TripCreateOutcome.ok);
    c.scheduleSave();
    expect(await c.saveNow(), isTrue);
    expect(api.calls('POST', '/trips'), hasLength(1));
    expect(api.calls('PUT', '/trips/t1'), hasLength(1));
    expect(await c.createNew(name: 'Again', adults: 2, kids: 0), TripCreateOutcome.failed);
    expect(api.calls('POST', '/trips'), hasLength(1));
  });

  test('resumed_local_draft_keeps_places_without_name', () {
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b'])], days: 3);
    final stored = StorageService.getTripNewDraft()!;
    expect(stored.containsKey('name'), isFalse);
    final d = TripNewDraft.read()!;
    expect(d.legs.single.ids, ['a', 'b']);
    expect(d.days, 3);

    StorageService.saveTripNewDraft({...stored, 'name': 'Old Build Name'});
    expect(TripNewDraft.read()!.legs.single.ids, ['a', 'b']);
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b', 'c'])]);
    expect(StorageService.getTripNewDraft()!.containsKey('name'), isFalse);
    TripNewDraft.save(const []);
    expect(StorageService.getTripNewDraft(), isNull);
  });
}
