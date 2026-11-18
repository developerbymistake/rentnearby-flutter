import 'dart:io';

import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/trip_strings_taxi_driver.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('taxi_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  const repo = DriverRequestRepository();

  test('offer_missed_maps_to_a_typed_result_with_data', () async {
    _use((_) => (409, '{"data":{"state":"Missed"},"error":{"message":"This request went to the next drivers","type":"OfferMissed"}}'));
    final r = await repo.accept('o1') as TaxiOfferMissed<DriverOffer>;
    expect(r.state, 'Missed');
    expect(r.message, 'This request went to the next drivers');
    expect(r, isA<TaxiRefused<DriverOffer>>());
  });

  test('dates_already_booked_sample_maps_with_range', () async {
    _use((_) => (409, _text('error_dates_already_booked.json')));
    final r = await repo.confirm('o1') as TaxiDatesAlreadyBooked<DriverOffer>;
    expect(r.from, '2026-12-20');
    expect(r.to, '2026-12-24');
    expect(r.conflict!.toDay, DateTime(2026, 12, 24));
  });

  test('confirm_window_passed_maps', () async {
    _use((_) => (409, '{"data":null,"error":{"message":"Time to confirm is over","type":"ConfirmWindowPassed"}}'));
    final r = await repo.confirm('o1');
    expect(r, isA<TaxiConfirmWindowPassed<DriverOffer>>());
    expect((r as TaxiConfirmWindowPassed).message, 'Time to confirm is over');
  });

  test('paused_maps_to_paused', () async {
    _use((_) => (403, '{"data":null,"error":{"message":"Trip bookings are paused.","type":"TripExecutionDisabled"}}'));
    final r = await repo.accept('o1');
    expect(r, isA<TaxiPaused<DriverOffer>>());
  });

  test('other_types_stay_refused_and_offline_stays_offline', () async {
    _use((_) => (403, '{"data":null,"error":{"message":"m","type":"NotOfferDriver"}}'));
    final r = await repo.decline('o1') as TaxiRefused<DriverOffer>;
    expect(r.type, 'NotOfferDriver');
    expect(r.statusCode, 403);
    final off = DriverRequestRepository.mapError<DriverOffer>(
        DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError));
    expect(off, isA<TaxiOffline<DriverOffer>>());
  });

  test('success_samples_map_to_ok_with_data', () async {
    final api = _use((o) {
      final p = o.path;
      final sample = p.endsWith('/offers')
          ? 'driver_offer_list.json'
          : p.endsWith('/bookings')
              ? 'driver_bookings.json'
              : p.endsWith('/rating')
                  ? 'driver_rating.json'
                  : p.endsWith('/readiness')
                      ? 'driver_readiness.json'
                      : 'driver_offer_detail_ringing.json';
      return (200, _ok(sample));
    });
    expect(((await repo.offers(cursor: 'c1')) as TaxiOk<DriverOfferList>).value.items.length, 4);
    expect(api.seen.last.queryParameters, {'cursor': 'c1'});
    expect(((await repo.offer('o1')) as TaxiOk<DriverOffer>).value.trip, isNotNull);
    final b = await repo.bookings(DateTime(2026, 12, 1), DateTime(2026, 12, 31)) as TaxiOk<DriverBookings>;
    expect(b.value.items.length, 2);
    expect(api.seen.last.queryParameters, {'from': '2026-12-01', 'to': '2026-12-31'});
    expect(((await repo.rating()) as TaxiOk<DriverRating>).value.ratingCount, 72);
    expect(((await repo.readiness()) as TaxiOk<DriverReadiness>).value.ringReady, isTrue);
    const sent = DriverDeviceState(
        appBuild: 69, notificationsOn: true, ringChannelOn: true, batteryUnrestricted: false, manufacturer: 'Xiaomi', androidSdk: 34, ringTested: true);
    await repo.reportDevice(sent);
    expect(api.seen.last.method, 'PUT');
    expect(api.seen.last.path, '/taxi-requests/driver/readiness');
    expect((api.seen.last.data as Map)['ringTested'], isTrue);
  });

  test('actions_hit_the_contract_routes', () async {
    final api = _use((o) => o.path.endsWith('test-ring') ? (204, '') : (200, _ok('driver_offer_detail_ringing.json')));
    await repo.accept('o1');
    await repo.decline('o1');
    await repo.decline('o1', chip: ReasonChip.vehicleIssue);
    await repo.confirm('o1');
    await repo.withdraw('o1', ReasonChip.changedPlan);
    final ring = await repo.testRing();
    expect(ring, isA<TaxiOk<void>>());
    expect([for (final o in api.seen) '${o.method} ${o.path}'], [
      'POST /taxi-requests/driver/offers/o1/accept',
      'POST /taxi-requests/driver/offers/o1/decline',
      'POST /taxi-requests/driver/offers/o1/decline',
      'POST /taxi-requests/driver/offers/o1/confirm',
      'POST /taxi-requests/driver/offers/o1/withdraw',
      'POST /taxi-requests/driver/test-ring',
    ]);
    expect(api.seen[1].data, {'chip': null});
    expect(api.seen[2].data, {'chip': 'VehicleIssue'});
    expect(api.seen[4].data, {'chip': 'ChangedPlan'});
  });

  test('end_booking_posts_to_the_booking_route', () async {
    final api = _use((_) => (200, '{"data":{"bookingId":"b1","state":"Completed"}}'));
    final r = await repo.endBooking('b1') as TaxiOk<DriverBooking>;
    expect(api.seen.single.path, '/taxi-requests/driver/bookings/b1/end');
    expect(r.value.state, BookingState.completed);
  });

  test('shared_driver_words', () {
    expect(TripStringsTaxiDriver.pickupCity('Kathgodam'), 'Kathgodam pickup');
    expect(TripStringsTaxiDriver.sectionSightseeing(6), 'Sightseeing 6 days');
    expect(TripStringsTaxiDriver.sectionSightseeing(1), 'Sightseeing 1 day');
    expect(TripStringsTaxiDriver.lengthLine(9, 8, '18', '26 Dec'), '9 days · 8 nights · 18 to 26 Dec');
    expect(TripStringsTaxiDriver.fromToCities('Kathgodam', ['Nainital', 'Ranikhet', 'Kausani'], more: 2),
        'Kathgodam to Nainital, Ranikhet, Kausani +2');
    expect(TripStringsTaxiDriver.seatsLine(4, 2), '4 seater · 2 travellers');
    expect(TripStringsTaxiDriver.seatsLine(4, 1), '4 seater · 1 traveller');
    expect([for (final c in TripStringsTaxiDriver.reasonOrder) TripStringsTaxiDriver.reasonLabel(c)],
        ['Changed plan', 'Not reachable', 'Price not agreed', 'Vehicle issue', 'Other']);
  });
}
