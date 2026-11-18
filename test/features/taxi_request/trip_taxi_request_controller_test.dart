import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import 'taxi_request_controller_fakes.dart';

const _requestId = '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101';
const _pickupKey = 6377270;

TripTaxiRequestController _controller(
  FakeTaxiRepo repo, {
  FakeEnquiries? enquiries,
  Future<bool> Function(String tripId)? refreshPlan,
  void Function()? onLegacyClosed,
}) {
  var n = 0;
  return TripTaxiRequestController(
    repo: repo,
    enquiries: enquiries ?? FakeEnquiries(),
    realtime: null,
    refreshPlan: refreshPlan ?? (_) async => true,
    onLegacyClosed: onLegacyClosed ?? () {},
    newClientId: () => 'client-${++n}',
  );
}

Future<TripTaxiRequestController> _readyForm(FakeTaxiRepo repo,
    {FakeEnquiries? enquiries, Future<bool> Function(String)? refreshPlan, void Function()? onLegacyClosed}) async {
  final c = _controller(repo, enquiries: enquiries, refreshPlan: refreshPlan, onLegacyClosed: onLegacyClosed);
  await c.loadPlaces('t1', planDays: planDays);
  c.editForm((f) => f.choosePickup(_pickupKey));
  return c;
}

class _TripApi implements HttpClientAdapter {
  Map<String, dynamic> lock = const {'locked': false, 'reason': null, 'requestId': null};
  Map<String, dynamic>? taxi;
  int gets = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    gets++;
    final body = {
      'data': {
        'id': 't1',
        'title': 'Uttarakhand Hills Trip',
        'status': 'Planned',
        'cityKey': 1,
        'cityName': 'Nainital',
        'plan': _plan().toJson(),
        'planLock': lock,
        'taxiRequest': taxi,
      },
      'status': '200',
      'code': 200,
    };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

TripPlan _plan() => TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      settings: const TripSettings(),
      days: const [TripDay(day: 1, spots: [])],
    );

DioException _refusal(String message) {
  final req = RequestOptions(path: '/trips/enquiries/e1/withdraw');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: 409, data: {
      'data': null,
      'status': '409',
      'code': 409,
      'error': {'message': message, 'type': 'EnquiryStateInvalid'},
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('taxi_ctrl_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  test('higher_version_replaces_lower_is_ignored', () {
    final c = _controller(FakeTaxiRepo());
    expect(c.apply(sampleRequest('taxi_request_collecting.json')), isTrue);
    expect(c.apply(sampleRequest('taxi_request_finding.json')), isFalse);
    expect(c.apply(sampleRequest('taxi_request_finding.json', change: {'version': 6})), isFalse);
    expect(c.request.value!.view, RequestView.collecting);
    expect(c.request.value!.version, 6);
    expect(c.apply(sampleRequest('taxi_request_booked.json')), isTrue);
    expect(c.request.value!.view, RequestView.booked);
    expect(c.apply(sampleRequest('taxi_request_collecting.json', change: {'version': 9})), isFalse);
    expect(c.request.value!.view, RequestView.booked);
  });

  test('send_retries_with_the_same_client_id', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo);
    repo.createAnswers.addAll([
      const TaxiOffline<TaxiRequest>(),
      const TaxiRefused<TaxiRequest>(type: null, statusCode: 503),
      TaxiOk(sampleRequest('taxi_request_finding.json')),
    ]);

    expect(await c.send(), isA<TaxiOffline<TaxiRequest>>());
    expect(c.hasFailed(TaxiAction.send), isTrue);
    expect(await c.send(), isA<TaxiRefused<TaxiRequest>>());
    expect(await c.send(), isA<TaxiOk<TaxiRequest>>());

    expect([for (final b in repo.createBodies) b['clientRequestId']], ['client-1', 'client-1', 'client-1']);
    expect(repo.createBodies.first['pickup'], {'on': true, 'cityKey': _pickupKey});
    expect(c.hasFailed(TaxiAction.send), isFalse);
    expect(c.pendingClientRequestId, isNull);
    expect(c.request.value!.id, _requestId);
  });

  test('send_after_a_form_change_uses_a_new_client_id', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo);
    repo.createAnswers.addAll([const TaxiOffline<TaxiRequest>(), TaxiOk(sampleRequest('taxi_request_finding.json'))]);
    await c.send();
    c.editForm((f) => f.setSeats(6));
    await c.send();
    expect([for (final b in repo.createBodies) b['clientRequestId']], ['client-1', 'client-2']);
    expect(repo.createBodies.last['seats'], 6);
  });

  test('double_tap_send_posts_once', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo);
    repo.createAnswers.add(TaxiOk(sampleRequest('taxi_request_finding.json')));
    final a = c.send();
    final b = c.send();
    expect(c.isBusy(TaxiAction.send), isTrue);
    await Future.wait([a, b]);
    expect(repo.createBodies.length, 1);
    expect(c.isBusy(TaxiAction.send), isFalse);
  });

  test('plan_locked_after_send_and_unlocked_after_cancel', () async {
    ApiService.init();
    final api = _TripApi();
    ApiService.dio.httpClientAdapter = api;
    final plan = TripPlanController();
    plan.trip.value = TripModel(
      id: 't1',
      title: 'Uttarakhand Hills Trip',
      status: TripStatuses.planned,
      cityKey: 1,
      cityName: 'Nainital',
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: 1,
      spotCount: 0,
      plan: _plan(),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    expect(plan.isPlanLocked, isFalse);

    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo, refreshPlan: (id) => plan.refreshTaxiState(tripId: id));
    final created = sampleRequest('taxi_request_finding.json', change: {'tripId': 't1'});
    repo.createAnswers.add(TaxiOk(created));
    api.lock = {'locked': true, 'reason': 'TaxiRequestActive', 'requestId': _requestId};
    api.taxi = {'requestId': _requestId, 'state': 'Open', 'view': 'Finding', 'version': 2};

    await c.send();
    await pumpEventQueue();
    expect(api.gets, 1);
    expect(plan.isPlanLocked, isTrue);
    expect(plan.planLockRequestId, _requestId);
    expect(plan.trip.value!.taxiRequest!.view, 'Finding');

    repo.actionAnswer = TaxiOk(sampleRequest('taxi_request_finding.json',
        change: {'tripId': 't1', 'state': 'Cancelled', 'view': 'Ended', 'version': 3, 'endReason': 'TravellerCancelled'}));
    api.lock = {'locked': false, 'reason': null, 'requestId': null};
    api.taxi = {'requestId': _requestId, 'state': 'Cancelled', 'view': 'Ended', 'version': 3};

    expect(await c.cancel(), isA<TaxiOk<TaxiRequest>>());
    await pumpEventQueue();
    expect(repo.actions, ['cancel:TravellerCancelled:null']);
    expect(api.gets, 2);
    expect(plan.isPlanLocked, isFalse);
    expect(plan.trip.value!.taxiRequest!.state, 'Cancelled');
  });

  test('already_active_opens_the_existing_request', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo);
    repo.createAnswers.add(const TaxiAlreadyActive<TaxiRequest>(requestId: _requestId));

    final r = await c.send();
    expect(r, isA<TaxiAlreadyActive<TaxiRequest>>());
    expect(repo.getIds, [_requestId]);
    expect(c.request.value!.id, _requestId);
    expect(c.request.value!.view, RequestView.collecting);
    expect(c.hasFailed(TaxiAction.send), isFalse);
  });

  test('paused_sets_the_flag', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo);
    expect(c.paused.value, isFalse);
    repo.createAnswers.add(const TaxiPaused<TaxiRequest>(message: 'Trip bookings are paused.'));
    expect(await c.send(), isA<TaxiPaused<TaxiRequest>>());
    expect(c.paused.value, isTrue);
    expect(c.hasFailed(TaxiAction.send), isTrue);

    final again = FakeTaxiRepo()
      ..placesAnswer = TaxiOk(TaxiPickupPlaces.fromJson({...sampleJson('pickup_places.json'), 'paused': true}));
    final d = _controller(again);
    await d.loadPlaces('t1', planDays: planDays);
    expect(d.paused.value, isTrue);
  });

  test('legacy_taxi_active_keeps_the_form_and_offers_cancel', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo);
    final before = c.form.value;
    repo.createAnswers.add(const TaxiLegacyActive<TaxiRequest>(
        rows: [TaxiLegacyRow(id: 'c7d1e2f3-4a5b-4c6d-8e9f-0a1b2c3d4e5f', booked: false)]));

    expect(await c.send(), isA<TaxiLegacyActive<TaxiRequest>>());
    expect(identical(c.form.value, before), isTrue);
    expect(c.form.value!.pickupCityKey, _pickupKey);
    expect(c.legacyRows.map((r) => r.id), ['c7d1e2f3-4a5b-4c6d-8e9f-0a1b2c3d4e5f']);
    expect(c.request.value, isNull);
  });

  test('cancel_legacy_then_send_again_once', () async {
    final repo = FakeTaxiRepo();
    final enquiries = FakeEnquiries();
    var closed = 0;
    final c = await _readyForm(repo, enquiries: enquiries, onLegacyClosed: () => closed++);
    repo.createAnswers.addAll([
      const TaxiLegacyActive<TaxiRequest>(rows: [TaxiLegacyRow(id: 'e1', booked: false), TaxiLegacyRow(id: 'e2', booked: true)]),
      TaxiOk(sampleRequest('taxi_request_finding.json')),
    ]);
    await c.send();

    final r = await c.cancelLegacyTaxi();
    expect(r, isA<TaxiOk<TaxiRequest>>());
    expect(enquiries.withdrawn, ['e1']);
    expect(enquiries.cancelled, ['e2']);
    expect(closed, 1);
    expect(repo.createBodies.length, 2);
    expect(repo.createBodies[1]['clientRequestId'], repo.createBodies[0]['clientRequestId']);
    expect(c.legacyRows, isEmpty);
    expect(c.request.value!.id, _requestId);
  });

  test('cancel_legacy_twice_refused_does_not_loop', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo);
    const legacy = TaxiLegacyActive<TaxiRequest>(rows: [TaxiLegacyRow(id: 'e1', booked: false)]);
    repo.createAnswers.addAll([legacy, legacy]);
    await c.send();
    expect(await c.cancelLegacyTaxi(), isA<TaxiLegacyActive<TaxiRequest>>());
    expect(repo.createBodies.length, 2);
    expect(c.legacyRows.length, 1);
  });

  test('cancel_legacy_failure_shows_the_message_and_sends_nothing', () async {
    final repo = FakeTaxiRepo();
    final c = await _readyForm(repo, enquiries: FakeEnquiries(fail: _refusal('This ask cannot be withdrawn now')));
    repo.createAnswers.add(const TaxiLegacyActive<TaxiRequest>(rows: [TaxiLegacyRow(id: 'e1', booked: false)]));
    await c.send();

    final r = await c.cancelLegacyTaxi();
    expect(r, isA<TaxiRefused<TaxiRequest>>());
    expect((r as TaxiRefused<TaxiRequest>).message, 'This ask cannot be withdrawn now');
    expect(repo.createBodies.length, 1);
    expect(c.legacyRows.length, 1);
    expect(c.hasFailed(TaxiAction.cancelLegacy), isTrue);
    expect(c.request.value, isNull);
  });

  test('status_actions_call_the_routes_and_apply_the_answer', () async {
    final repo = FakeTaxiRepo();
    final c = _controller(repo);
    c.apply(sampleRequest('taxi_request_collecting.json'));
    repo.actionAnswer = TaxiOk(sampleRequest('taxi_request_selected.json'));
    await c.select('o1');
    expect(c.request.value!.view, RequestView.selected);
    await c.notAgreed('o2');
    await c.askMore();
    await c.changePickup();
    await c.endTrip();
    await c.rate(5);
    await c.cancel(chip: ReasonChip.changedPlan);
    expect(repo.actions, [
      'select:o1',
      'notAgreed:o2',
      'askMore',
      'cancel:PickupChanged:null',
      'end',
      'rate:5',
      'cancel:TravellerCancelled:ChangedPlan',
    ]);
  });

  test('state_invalid_answer_reloads_the_request', () async {
    final repo = FakeTaxiRepo();
    final c = _controller(repo);
    c.apply(sampleRequest('taxi_request_finding.json'));
    repo.actionAnswer = const TaxiStateInvalid<TaxiRequest>(state: 'Collecting', version: 6);
    final r = await c.select('o1');
    await pumpEventQueue();
    expect(r, isA<TaxiStateInvalid<TaxiRequest>>());
    expect(c.hasFailed(TaxiAction.select), isTrue);
    expect(repo.getIds, [_requestId]);
    expect(c.request.value!.view, RequestView.collecting);
  });

  test('no_shared_last_error_fields', () {
    final src = File('lib/features/trip/controllers/trip_taxi_request_controller.dart').readAsStringSync();
    expect(src.contains('lastError'), isFalse);
    expect(src.toLowerCase().contains('errormessage'), isFalse);
    expect(src.contains('RxnString'), isFalse);
    expect(src.contains('RxString'), isFalse);
    expect(RegExp(r'catch \(_\)').hasMatch(src), isFalse);
  });
}
