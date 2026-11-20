import 'dart:io';

import 'package:bakhli/features/trip/data/taxi_request_repository.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

String _text(String name) => File('test/features/taxi_request/samples/$name').readAsStringSync();

class _Api implements HttpClientAdapter {
  _Api(this.answer);

  final (int, String) Function(RequestOptions) answer;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final (code, body) = answer(options);
    return ResponseBody.fromString(body, code, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

String _ok(String sample) => '{"data": ${_text(sample)}, "status": "200", "code": 200}';

_Api _use((int, String) Function(RequestOptions) answer) {
  ApiService.init();
  final api = _Api(answer);
  ApiService.dio.httpClientAdapter = api;
  return api;
}

Future<TaxiResult<TaxiRequest>> _createWithError(String sample, int code) {
  _use((_) => (code, _text(sample)));
  return const TaxiRequestRepository().create('t1', const {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('taxi_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  test('success_samples_map_to_ok_with_data', () async {
    final api = _use((o) {
      final places = o.path.endsWith('pickup-places');
      return (places ? 200 : 201, _ok(places ? 'pickup_places.json' : 'taxi_request_finding.json'));
    });
    const repo = TaxiRequestRepository();
    final places = await repo.pickupPlaces('t1');
    expect((places as TaxiOk<TaxiPickupPlaces>).value.pickup.length, 2);
    final created = await repo.create('t1', const {'seats': 4});
    expect((created as TaxiOk<TaxiRequest>).value.view, RequestView.finding);
    expect(api.seen.last.path, '/trips/t1/taxi-request');
    expect(api.seen.last.method, 'POST');
  });

  test('for_trip_null_data_is_ok_null', () async {
    _use((_) => (200, '{"data": null, "status": "200", "code": 200}'));
    final r = await const TaxiRequestRepository().forTrip('t1');
    expect(r, isA<TaxiOk<TaxiRequest?>>());
    expect(r.valueOrNull, isNull);
  });

  test('actions_hit_the_contract_routes', () async {
    final api = _use((_) => (200, _ok('taxi_request_collecting.json')));
    const repo = TaxiRequestRepository();
    await repo.cancel('r1');
    await repo.askMore('r1');
    await repo.select('r1', 'o1');
    await repo.notAgreed('r1', 'o1');
    await repo.end('r1');
    await repo.rate('r1', 5);
    await repo.get('r1');
    expect([for (final o in api.seen) '${o.method} ${o.path}'], [
      'POST /taxi-requests/r1/cancel',
      'POST /taxi-requests/r1/ask-more',
      'POST /taxi-requests/r1/offers/o1/select',
      'POST /taxi-requests/r1/offers/o1/not-agreed',
      'POST /taxi-requests/r1/end',
      'POST /taxi-requests/r1/rating',
      'GET /taxi-requests/r1',
    ]);
    expect(api.seen[0].data, {'reason': 'TravellerCancelled', 'chip': null});
    expect(api.seen[5].data, {'stars': 5});
  });

  test('legacy_taxi_error_sample_maps_to_a_typed_result_with_rows', () async {
    final r = await _createWithError('error_legacy_taxi_active.json', 409);
    final legacy = r as TaxiLegacyActive<TaxiRequest>;
    expect(legacy.rows.single.id, 'c7d1e2f3-4a5b-4c6d-8e9f-0a1b2c3d4e5f');
    expect(legacy.rows.single.booked, isFalse);
  });

  test('plan_locked_sample_maps_with_data', () async {
    final r = await _createWithError('error_plan_locked.json', 409) as TaxiPlanLocked<TaxiRequest>;
    expect(r.reason, 'TaxiRequestActive');
    expect(r.requestId, '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101');
  });

  test('all_drivers_busy_sample_maps', () async {
    final r = await _createWithError('error_all_drivers_busy.json', 409);
    expect(r, isA<TaxiAllDriversBusy<TaxiRequest>>());
  });

  test('no_ready_driver_maps_to_its_own_result', () async {
    _use((_) => (409, '{"error":{"message":"No driver is ready for this route right now.","type":"NoReadyDriver"}}'));
    final r = await const TaxiRequestRepository().create('t1', const {});
    expect(r, isA<TaxiNoReadyDriver<TaxiRequest>>());
    expect((r as TaxiNoReadyDriver<TaxiRequest>).message, 'No driver is ready for this route right now.');
  });

  test('already_active_and_state_invalid_carry_data', () async {
    _use((_) => (409, '{"data":{"requestId":"r9"},"error":{"message":"m","type":"TaxiRequestAlreadyActive"}}'));
    final a = await const TaxiRequestRepository().create('t1', const {}) as TaxiAlreadyActive<TaxiRequest>;
    expect(a.requestId, 'r9');
    _use((_) => (409, '{"data":{"state":"Booked","version":4},"error":{"message":"m","type":"TaxiRequestStateInvalid"}}'));
    final s = await const TaxiRequestRepository().cancel('r1') as TaxiStateInvalid<TaxiRequest>;
    expect(s.state, 'Booked');
    expect(s.version, 4);
  });

  test('403_trip_execution_disabled_maps_to_paused', () async {
    _use((_) => (403, '{"data":null,"error":{"message":"Trip bookings are paused.","type":"TripExecutionDisabled"}}'));
    final r = await const TaxiRequestRepository().create('t1', const {});
    expect(r, isA<TaxiPaused<TaxiRequest>>());
    expect((r as TaxiPaused).message, 'Trip bookings are paused.');
  });

  test('other_errors_map_to_refused_and_unknown_body_stays_refused', () async {
    _use((_) => (400, '{"data":null,"error":{"message":"Turn on at least one section","type":"TaxiSectionsRequired"}}'));
    final r = await const TaxiRequestRepository().create('t1', const {}) as TaxiRefused<TaxiRequest>;
    expect(r.type, 'TaxiSectionsRequired');
    expect(r.statusCode, 400);
    _use((_) => (500, '{}'));
    final u = await const TaxiRequestRepository().get('r1') as TaxiRefused<TaxiRequest>;
    expect(u.type, isNull);
    expect(u.statusCode, 500);
  });
}
