import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a1.dart';
import 'package:bakhli/features/trip/utils/trip_leg_draft.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'support/engine_rig.dart';

class _LockedApi implements HttpClientAdapter {
  _LockedApi(this.tripAfter, {this.lockedPuts = 1 << 30});

  final Map<String, dynamic> tripAfter;
  final int lockedPuts;
  final List<RequestOptions> seen = [];

  int count(String method, String path) =>
      seen.where((o) => o.method.toUpperCase() == method && o.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final json = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (options.method.toUpperCase() == 'PUT') {
      if (count('PUT', options.path) <= lockedPuts) {
        return ResponseBody.fromString(contractSampleText('error_plan_locked.json'), 409, headers: json);
      }
      return ResponseBody.fromString(jsonEncode({'status': '200', 'code': 200, 'data': tripAfter}), 200, headers: json);
    }
    if (options.method.toUpperCase() == 'GET' && options.path == '/trips/t1') {
      return ResponseBody.fromString(jsonEncode({'status': '200', 'code': 200, 'data': tripAfter}), 200, headers: json);
    }
    return ResponseBody.fromString(
        jsonEncode({'status': '503', 'code': 503, 'error': {'message': 'Down', 'type': 'Down'}}), 503,
        headers: json);
  }

  @override
  void close({bool force = false}) {}
}

const _spotModel = TripSpotModel(
  id: 'new1',
  source: 'atlas',
  name: 'New place',
  latitude: 29.4,
  longitude: 79.4,
  category: 'attraction',
  visitMinutes: 60,
);

Future<void> _until(bool Function() done) async {
  final sw = Stopwatch()..start();
  while (!done() && sw.elapsed < const Duration(seconds: 5)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('lock_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  test('every_structure_method_is_refused_while_locked', () async {
    final c = engineRig(enginePlan([[2, 2], [1, 1]]), lock: lockedByRequest);
    final before = jsonEncode(c.plan.value!.toJson());
    expect(c.isPlanLocked, isTrue);
    expect(c.canEditStructure, isFalse);
    expect(c.isReadOnly, isFalse);
    expect(c.needsUpdate.value, isFalse);

    expect(c.moveSpot('L1d1s0', 2), isFalse);
    c.reorder(1, 0, 2);
    c.removeSpot('L1d1s0');
    c.insertSpotAt(engineSpot('x'), 1, 0);
    expect(c.addSpots([_spotModel], legIndex: 1), isFalse);
    expect(c.addSpots([_spotModel], day: 2), isFalse);
    expect(c.canAddDay, isFalse);
    expect(c.addDay(), TripDayAddBlock.locked);
    expect(c.addDay(afterDay: 1), TripDayAddBlock.locked);
    expect(c.removeDay(2), TripDayRemoveBlock.readOnly);
    c.setRestDay(4, true);
    expect(c.canSetLegDays(1, 3), TripLegEditBlock.readOnly);
    expect(await c.setLegDays(1, 3), isFalse);
    expect(c.canAddLeg(const TripCityModel(cityKey: 9, name: 'Ranikhet', latitude: 29.6, longitude: 79.4)),
        TripLegEditBlock.readOnly);
    expect(await c.addLeg(const TripCityModel(cityKey: 9, name: 'Ranikhet', latitude: 29.6, longitude: 79.4), const []),
        TripLegEditBlock.readOnly);
    expect(c.canRemoveLeg(2), TripLegEditBlock.readOnly);
    expect(c.removeLeg(2), TripLegEditBlock.readOnly);
    final r = await c.saveSettings(c.settings.copyWith(startDate: DateTime(2030, 12, 1), adults: 4));
    expect(r.saved, isFalse);
    final p = c.plan.value!;
    final draft = TripLegDraft.from(p, 1, frozenDays: 0, otherLegsDayCount: 2, otherLegsSpotCount: 2);
    draft.move('L1d1s0', 1, 0);
    expect(c.applyLegDraft(1, draft), TripLegApplyBlock.locked);
    expect(c.canEditLeg(1), isFalse);
    expect(c.canAddPlaces(1), isFalse);
    expect(c.canMarkRow(const TripEasyRowKey(TripEasyRowKind.taxi)), isFalse);
    expect(await c.markOwn(const TripEasyRowKey(TripEasyRowKind.taxi)), isA<TripMarked>());
    c.skipRow(const TripEasyRowKey(TripEasyRowKind.taxi));

    expect(jsonEncode(c.plan.value!.toJson()), before);
  });

  test('marks_cancel_and_complete_still_work_while_locked', () async {
    final plan = enginePlan([[2, 2]]);
    final c = engineRig(
      TripPlan(legs: plan.legs, days: plan.days, settings: const TripSettings()),
      lock: lockedByRequest,
    );
    const stay = TripEasyRowKey(TripEasyRowKind.stay, 1);
    expect(c.isReadOnly, isFalse);
    expect(c.canMarkRow(stay), isTrue);
    expect(await c.markOwn(stay), isA<TripMarked>());
    expect(c.plan.value!.legAt(1)!.stayMark?.isOwn, isTrue);
    c.undoMark(stay);
    expect(c.plan.value!.legAt(1)!.stayMark, isNull);
    c.skipRow(stay);
    expect(c.plan.value!.legAt(1)!.stayMark?.isSkipped, isTrue);
    expect(c.canComplete, isTrue);
    final cancel = await c.cancelLegRows(const LegImpact.empty());
    expect(cancel.ok, isTrue);
  });

  test('plan_locked_save_error_sets_the_lock_and_does_not_retry', () async {
    final plan = enginePlan([[2, 2]]);
    final after = engineTripJson(plan, extra: contractSample('trip_taxi_fields.json'));
    ApiService.init();
    final api = _LockedApi(after);
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(plan);
    expect(c.isPlanLocked, isFalse);
    c.plan.value = plan.copyWith(days: [
      plan.days[0].copyWith(spots: [...plan.days[0].spots, ...plan.days[1].spots]),
      plan.days[1].copyWith(spots: const []),
    ]);
    final edited = c.plan.value;

    expect(await c.saveNow(), isFalse);
    expect(api.count('PUT', '/trips/t1'), 1);
    expect(c.isPlanLocked, isTrue);
    expect(c.planLockReason, TripPlanLockReasons.taxiRequestActive);
    expect(c.planLockRequestId, '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101');
    expect(c.canEditStructure, isFalse);
    expect(c.saveFailed.value, isTrue);
    expect(c.notSavedMessage, TripStringsDayplan.lockedByRequest);
    expect(identical(c.plan.value, edited), isTrue);

    c.scheduleSave();
    expect(await c.flushPendingSave(), isFalse);
    expect(await c.flushPendingSave(), isFalse);
    await _until(() => c.trip.value?.taxiRequest != null && !c.saveFailed.value);
    expect(api.count('PUT', '/trips/t1'), 1);
    expect(api.count('GET', '/trips/t1'), 1);
    expect(c.trip.value!.taxiRequest?.view, 'Collecting');
    expect(c.trip.value!.taxiRequest?.version, 6);
    expect(c.isPlanLocked, isTrue);
    expect(jsonEncode(c.plan.value!.toJson()), jsonEncode(plan.toJson()));
    expect(c.saveFailed.value, isFalse);
  });

  test('stay_mark_after_plan_locked_saves_with_one_put', () async {
    final plan = enginePlan([[2, 2]]);
    final after = engineTripJson(plan, extra: contractSample('trip_taxi_fields.json'));
    ApiService.init();
    final api = _LockedApi(after, lockedPuts: 1);
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(plan);
    c.plan.value = plan.copyWith(days: [
      plan.days[0].copyWith(spots: [...plan.days[0].spots, ...plan.days[1].spots]),
      plan.days[1].copyWith(spots: const []),
    ]);
    expect(await c.saveNow(), isFalse);
    await _until(() => c.trip.value?.taxiRequest != null && !c.saveFailed.value);
    expect(api.count('GET', '/trips/t1'), 1);
    expect(c.isPlanLocked, isTrue);

    const stay = TripEasyRowKey(TripEasyRowKind.stay, 1);
    expect(await c.markOwn(stay), isA<TripMarked>());
    expect(await c.flushPendingSave(), isTrue);
    expect(api.count('PUT', '/trips/t1'), 2);
    final body = api.seen.lastWhere((o) => o.method.toUpperCase() == 'PUT').data;
    final sent = TripPlan.fromJson(Map<String, dynamic>.from((body is String ? jsonDecode(body) : body)['plan'] as Map));
    expect(jsonEncode([for (final d in sent.days) d.toJson()]), jsonEncode([for (final d in plan.days) d.toJson()]));
    expect(sent.legAt(1)!.stayMark?.isOwn, isTrue);
    expect(c.saveFailed.value, isFalse);
    expect(c.isPlanLocked, isTrue);
  });

  test('keep_server_structure_keeps_local_marks_only', () {
    final server = enginePlan([[2, 2], [1]]);
    final local = server
        .copyWith(days: [server.days[1], server.days[0], server.days[2]])
        .withStayMark(1, const TripRowMark.own())
        .withTaxiMark(const TripRowMark.own());
    final merged = TripPlanController.keepServerStructure(local, server);
    expect(jsonEncode([for (final d in merged.days) d.toJson()]), jsonEncode([for (final d in server.days) d.toJson()]));
    expect(merged.legAt(1)!.stayMark?.isOwn, isTrue);
    expect(merged.taxiMark, isNull);
  });

  test('keep_server_structure_keeps_the_local_taxi_mark_under_a_stay_lock', () {
    final server = enginePlan([[2, 2], [1]]);
    final local = server
        .copyWith(days: [server.days[1], server.days[0], server.days[2]])
        .withTaxiMark(const TripRowMark.skipped());
    final merged = TripPlanController.keepServerStructure(local, server, keepTaxiMark: true);
    expect(jsonEncode([for (final d in merged.days) d.toJson()]), jsonEncode([for (final d in server.days) d.toJson()]));
    expect(merged.taxiMark?.isSkipped, isTrue);
  });

  test('stay_lock_parses_reason_and_enquiry_id', () {
    final plan = enginePlan([[1]]);
    final t = TripModel.fromJson(engineTripJson(plan, extra: {
      'planLock': {'locked': true, 'reason': 'StayBookingActive', 'requestId': null, 'enquiryId': 'e9'},
    }));
    expect(t.planLock.byStay, isTrue);
    expect(t.planLock.byBooking, isFalse);
    expect(t.planLock.enquiryId, 'e9');
    expect(t.planLock.requestId, isNull);
    final c = engineRig(plan, lock: t.planLock);
    expect(c.planLockMessage, TripStringsDayplan.lockedByStay);
    expect(c.planLockEnquiryId, 'e9');
    expect(c.canMarkRow(const TripEasyRowKey(TripEasyRowKind.taxi)), isTrue);

    final err = TripPlanLock.fromError({'reason': 'StayBookingActive', 'enquiryId': 'e9'}, message: 'From server');
    expect((err.byStay, err.enquiryId, err.requestId, err.message), (true, 'e9', null, 'From server'));
    expect(engineRig(plan, lock: err).planLockMessage, 'From server');

    final taxi = TripPlanLock.fromError({'reason': 'TaxiRequestActive', 'requestId': 'r1'});
    expect((taxi.byStay, taxi.requestId, taxi.enquiryId, taxi.message), (false, 'r1', null, null));
    final rc = engineRig(plan, lock: taxi);
    expect(rc.planLockMessage, TripStringsDayplan.lockedByRequest);
    expect(rc.canMarkRow(const TripEasyRowKey(TripEasyRowKind.taxi)), isFalse);
  });

  test('trip_fields_parse_the_contract_sample', () {
    final plan = enginePlan([[1]]);
    final locked = TripModel.fromJson(engineTripJson(plan, extra: contractSample('trip_taxi_fields.json')));
    expect(locked.planLock.locked, isTrue);
    expect(locked.planLock.reason, TripPlanLockReasons.taxiRequestActive);
    expect(locked.planLock.requestId, '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101');
    expect(locked.planLock.byBooking, isFalse);
    final t = locked.taxiRequest!;
    expect(t.requestId, '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101');
    expect(t.state, 'Collecting');
    expect(t.view, 'Collecting');
    expect(t.version, 6);

    final open = TripModel.fromJson(engineTripJson(plan, extra: {
      'planLock': {'locked': false, 'reason': null, 'requestId': null},
      'taxiRequest': null,
    }));
    expect(open.planLock.locked, isFalse);
    expect(open.planLock.reason, isNull);
    expect(open.taxiRequest, isNull);

    final old = TripModel.fromJson(engineTripJson(plan));
    expect(old.planLock.locked, isFalse);
    expect(old.taxiRequest, isNull);
    expect(old.nameChosen, isFalse);

    final booking = TripPlanLock.parse({'locked': true, 'reason': 'TaxiBookingActive', 'requestId': 'r1'});
    expect(booking.byBooking, isTrue);
    final c = engineRig(plan, lock: booking);
    expect(c.planLockMessage, TripStringsDayplan.lockedByBooking);
  });

  test('trip_name_fields_parse_the_contract_sample', () {
    final plan = enginePlan([[1], [1]]);
    final chosen = TripModel.fromJson(engineTripJson(plan, extra: contractSample('trip_name_fields.json')));
    expect(chosen.title, 'Uttarakhand Hills Trip');
    expect(chosen.nameChosen, isTrue);
    expect(chosen.copyWith(status: TripStatuses.planned).nameChosen, isTrue);

    final defaultText = TripStringsMcaA1.defaultTitle(['Nainital']);
    final c = engineRig(plan);
    c.trip.value = TripModel.fromJson(engineTripJson(plan, extra: {'title': defaultText, 'nameChosen': true}));
    expect(c.title, defaultText);
    c.trip.value = TripModel.fromJson(engineTripJson(plan, extra: {'title': defaultText, 'nameChosen': false}));
    expect(c.title, TripStringsMcaA1.defaultTitle(['Nainital', 'Almora']));
  });
}
