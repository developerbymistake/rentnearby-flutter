import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_supply_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/features/trip/widgets/trip_map_day_card.dart';
import 'package:bakhli/features/trip/widgets/trip_today_card.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../../support/five_sizes.dart';
import 'taxi_request_controller_fakes.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _StaysAdapter implements HttpClientAdapter {
  _StaysAdapter(this.answer);

  final Future<ResponseBody> Function() answer;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    calls++;
    return answer();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int code, Map<String, Object?> body) => ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

TripModel _trip(TripPlan plan, {String id = 't1', TripTaxiRequestRef? taxiRequest}) => TripModel(
      id: id,
      title: 'Hills trip',
      status: TripStatuses.planned,
      cityKey: plan.cityKey,
      cityName: plan.cityName,
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: plan.days.length,
      spotCount: plan.spotCount,
      plan: plan,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      taxiRequest: taxiRequest,
    );

TripPlanController _plan(TripPlan p, {TripModel? trip}) {
  if (!Get.isRegistered<TabConfigController>()) Get.put<TabConfigController>(_Tabs());
  final c = Get.put(TripPlanController());
  c.plan.value = p;
  c.trip.value = trip ?? _trip(p);
  return c;
}

String _src(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _member(String src, String signature) {
  final start = src.indexOf(signature);
  if (start < 0) return '';
  var depth = 0;
  var opened = false;
  for (var i = start; i < src.length; i++) {
    final ch = src[i];
    if (ch == '{') {
      depth++;
      opened = true;
    } else if (ch == '}') {
      depth--;
      if (opened && depth == 0) return src.substring(start, i + 1);
    }
  }
  return src.substring(start);
}

Future<String?> _headSource(String path) async {
  try {
    final r = await Process.run('git', ['show', 'HEAD:$path']);
    return r.exitCode == 0 ? (r.stdout as String).replaceAll('\r\n', '\n') : null;
  } catch (_) {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TripClock.resetClock();
    Get.reset();
  });

  test('supply_controller_has_no_taxi_members', () {
    final supply = _src('lib/features/trip/controllers/trip_supply_controller.dart');
    for (final gone in [
      'ensureTaxis',
      'loadTaxis',
      'loadMoreTaxis',
      'taxiLeg',
      'filteredTaxis',
      'taxiFitOf',
      'taxiCityKey',
      'taxisOutOfDate',
      'minSeats',
      'onlySuv',
      '/taxis/browse',
      'TripTaxiFit',
      'TaxiBrowseItem',
    ]) {
      expect(supply.contains(gone), isFalse, reason: gone);
    }
    expect(supply.contains('loadStays'), isTrue);
    expect(supply.contains('asksLeft'), isTrue);

    final plan = _src('lib/features/trip/controllers/trip_plan_controller.dart');
    for (final gone in [
      'taxiSupply',
      'cityHasTaxis',
      'canFindTaxi',
      'hidesLocalTaxi',
      'hasLocalTaxiOn',
      'cancelLocalTaxiTravelDay',
      'checkSupply',
      'ensureSupply',
      '_browseLeg',
      '_recheckLegs',
      'taxiAskedDays',
      'browseLocal',
    ]) {
      expect(plan.contains(gone), isFalse, reason: gone);
    }
    expect(_src('lib/features/trip/controllers/trip_enquiry_controller.dart').contains('sendLead'), isFalse);
    expect(_src('lib/features/trip/data/trip_enquiry_repository.dart').contains('createLead'), isFalse);
    expect(_src('lib/features/trip/controllers/trip_shortlist_controller.dart').contains('sendTaxis'), isFalse);
    expect(File('lib/features/trip/controllers/trip_plan_guide.dart').existsSync(), isFalse);
    expect(_src('lib/features/trip/widgets/trip_update_ask_sheet.dart').contains('sendLead'), isFalse);
  });

  group('stay_loading_resets_after_a_failed_load', () {
    final plan = TripPlan.singleCity(cityKey: 7, cityName: 'Nainital', centreLatitude: 29.39, centreLongitude: 79.45);

    test('a failed load clears the spinner and shows the retry state', () async {
      ApiService.init();
      final api = _StaysAdapter(() async => _json(500, {'status': '500', 'code': 500, 'error': {'message': 'boom', 'type': 'Boom'}}));
      ApiService.dio.httpClientAdapter = api;
      _plan(plan);
      final s = TripSupplyController.to;
      await s.ensureStays(1);
      expect(api.calls, 1);
      expect(s.stayLoading.value, isFalse);
      expect(s.stayFailed.value, isTrue);
    });

    test('a reload for a leg without a point does not leave the spinner of the dropped load on', () async {
      ApiService.init();
      final hang = Completer<ResponseBody>();
      final api = _StaysAdapter(() => hang.future);
      ApiService.dio.httpClientAdapter = api;
      final c = _plan(plan);
      final s = TripSupplyController.to;
      unawaited(s.loadStays());
      await Future<void>.delayed(Duration.zero);
      expect(s.stayLoading.value, isTrue);
      c.plan.value = TripPlan.singleCity(cityKey: 7, cityName: 'Nainital');
      await s.loadStays();
      expect(s.stayLoading.value, isFalse);
      hang.complete(_json(200, {'status': '200', 'code': 200, 'data': {'items': []}}));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(s.stayLoading.value, isFalse);
      expect(s.stays, isEmpty);
    });
  });

  test('enquiry_controller_keeps_withdraw_cancel_and_book_taxi', () async {
    const path = 'lib/features/trip/controllers/trip_enquiry_controller.dart';
    final now = _src(path);
    final head = await _headSource(path);
    for (final sig in [
      'Future<T?> _guard<T>(',
      'Future<bool> withdraw(',
      'Future<bool> cancel(',
      'Future<TripEnquiryModel?> bookTaxi(',
      'Future<TripEnquiryModel?> syncTaxiBooking(',
      'Map<String, dynamic> _taxiBody(',
    ]) {
      expect(_member(now, sig), isNotEmpty, reason: sig);
      if (head != null && sig != 'Future<bool> withdraw(') expect(_member(now, sig), _member(head, sig), reason: '$sig changed');
    }
    for (final field in ['lastConflict', 'lastErrorType', 'lastErrorMessage', 'lastRetryAfterMinutes']) {
      expect(now.contains(field), isTrue, reason: field);
    }

    final start = TripClock.today().add(const Duration(days: 10));
    Map<String, Object?> row(String id, String status) =>
        enquiryJson(id: id, kind: TripEnquiryKinds.taxi, status: status, start: start, days: [1]);
    final api = installFakeApi([
      FakeRoute.value('POST', '/trips/enquiries/{id}/withdraw', row('w1', TripEnquiryStatuses.closed)),
      FakeRoute.value('POST', '/trips/enquiries/{id}/cancel', row('c1', TripEnquiryStatuses.cancelledByTraveller)),
      FakeRoute.value('POST', '/trips/{id}/taxi-bookings', row('b1', TripEnquiryStatuses.bookedByTraveller)),
    ]);
    _plan(journeyPlan([2], start: start));
    final en = Get.put(TripEnquiryController());
    expect(await en.withdraw('w1'), isTrue);
    expect(await en.cancel('c1', reason: '  changed plans '), isTrue);
    final booked = await en.bookTaxi(
      taxiId: 'x1',
      days: [1],
      agreedFare: 2500,
      tollExtra: false,
      pickupTime: '08:30',
      pickupPlace: 'Mall Road',
      closeOthers: false,
    );
    expect(booked?.id, 'b1');
    expect(api.calls('POST', '/trips/enquiries/w1/withdraw'), hasLength(1));
    final cancel = api.calls('POST', '/trips/enquiries/c1/cancel').single;
    expect(cancel.data, {'reason': 'changed plans'});
    final book = api.calls('POST', '/trips/t1/taxi-bookings').single.data as Map;
    expect(book['taxiId'], 'x1');
    expect(book['days'], [1]);
    expect(book['agreedFare'], 2500);
    expect(book['closeOthers'], isFalse);
  });

  group('today_card_shows_the_booked_driver_from_the_request', () {
    final request = sampleRequest('taxi_request_booked.json');
    final start = DateTime(2026, 12, 18);
    final plan = TripPlan.singleCity(cityKey: 7, cityName: 'Nainital', centreLatitude: 29.39, centreLongitude: 79.45).copyWith(
      days: [for (var d = 1; d <= 4; d++) TripDay(day: d, leg: 1, spots: [journeySpot('s$d')])],
      settings: TripSettings(startDate: start, adults: 2),
    );
    final ref = TripTaxiRequestRef(requestId: request.id, state: 'Booked', view: 'Booked', version: request.version);

    void rig({bool withRequest = true, TripTaxiRequestRef? taxiRef, FakeTaxiRepo? repo}) {
      Get.reset();
      TripClock.clockUtc = () => DateTime.utc(2026, 12, 19, 6);
      installFakeApi(const []);
      final req = Get.put(TripTaxiRequestController(repo: repo ?? (FakeTaxiRepo()..getAnswer = (_) => TaxiOk(request)), realtime: null));
      if (withRequest) req.request.value = request;
      _plan(plan, trip: _trip(plan, id: request.tripId, taxiRequest: taxiRef ?? ref));
    }

    testWidgets('driver name, car and Call come from the confirmed driver of the booking', (t) async {
      await pumpAtFiveSizes(t, () {
        rig();
        return const Scaffold(body: SingleChildScrollView(child: TripTodayCard()));
      }, check: (t, size) async {
        expect(find.text('Ramesh Kumar'), findsOneWidget, reason: sizeLabel(size));
        expect(find.textContaining('Swift Dzire'), findsOneWidget, reason: sizeLabel(size));
        expect(find.text('Call'), findsOneWidget, reason: sizeLabel(size));
      });
    });

    testWidgets('no booked view on the trip shows no request driver', (t) async {
      rig(taxiRef: TripTaxiRequestRef(requestId: request.id, state: 'Collecting', view: 'Collecting', version: request.version));
      await pumpAtSize(t, const Scaffold(body: SingleChildScrollView(child: TripTodayCard())), const Size(360, 800));
      expect(find.text('Ramesh Kumar'), findsNothing);
      expect(TripPlanController.to.requestDriverOn(2), isNull);
    });

    test('a day outside the booking dates has no request driver', () {
      rig();
      final c = TripPlanController.to;
      expect(c.requestDriverOn(2)?.name, 'Ramesh Kumar');
      c.plan.value = plan.copyWith(settings: TripSettings(startDate: DateTime(2026, 12, 10), adults: 2));
      expect(c.requestDriverOn(2), isNull);
    });

    test('a booked trip loads the request once when it is not loaded yet', () async {
      rig(withRequest: false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final req = Get.find<TripTaxiRequestController>();
      expect(req.request.value?.id, request.id);
      expect(TripPlanController.to.requestDriverOn(2)?.phone, '+919876500001');
    });

    test('a failed request load is tried again on the next trip update', () async {
      final repo = FakeTaxiRepo()..getAnswer = (_) => TaxiOk(request);
      rig(withRequest: false, repo: repo);
      final req = Get.find<TripTaxiRequestController>();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(req.request.value?.id, request.id);
      req.request.value = null;
      repo.getIds.clear();
      repo.getAnswer = (_) => const TaxiOffline<TaxiRequest>();
      final c = TripPlanController.to;
      c.trip.value = _trip(plan, id: request.tripId, taxiRequest: TripTaxiRequestRef(
          requestId: request.id, state: 'Booked', view: 'Booked', version: request.version + 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.getIds, [request.id]);
      expect(c.requestDriverOn(2), isNull);
      repo.getAnswer = (_) => TaxiOk(request);
      c.trip.value = _trip(plan, id: request.tripId, taxiRequest: TripTaxiRequestRef(
          requestId: request.id, state: 'Booked', view: 'Booked', version: request.version + 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.getIds, [request.id, request.id]);
      expect(c.requestDriverOn(2)?.name, 'Ramesh Kumar');
    });

    testWidgets('map day card shows the driver, Confirmed and Call driver from the request', (t) async {
      await pumpAtFiveSizes(t, () {
        rig();
        return Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TripMapDayCard(dayCount: 4, selected: 2, onDaySelected: (_) {}),
          ),
        );
      }, check: (t, size) async {
        await t.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Ramesh Kumar · Confirmed'), findsWidgets, reason: sizeLabel(size));
        expect(find.text('Call driver'), findsWidgets, reason: sizeLabel(size));
      });
    });
  });

  test('cities_unavailable_resets_after_a_good_stay_check', () async {
    ApiService.init();
    var fail = true;
    final api = _StaysAdapter(() async => fail
        ? _json(503, {'status': '503', 'code': 503, 'error': {'message': 'later', 'type': 'TripCitiesUnavailable'}})
        : _json(200, {'status': '200', 'code': 200, 'data': {'items': []}}));
    ApiService.dio.httpClientAdapter = api;
    final c = _plan(TripPlan.singleCity(cityKey: 7, cityName: 'Nainital', centreLatitude: 29.39, centreLongitude: 79.45));
    await c.ensureStaySupply(1);
    expect(c.citiesUnavailable.value, isTrue);
    expect(c.supplyCheckFailedFor(1), isTrue);
    fail = false;
    c.retrySupply(1);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.citiesUnavailable.value, isFalse);
    expect(c.supplyCheckFailedFor(1), isFalse);
  });
}
