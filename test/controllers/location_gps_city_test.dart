import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class _Loc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final pending = <Completer<ResponseBody>>[];
  bool hold = false;
  int status = 200;
  Map<String, dynamic> body = const {};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    if (hold) {
      final c = Completer<ResponseBody>();
      pending.add(c);
      return c.future;
    }
    return Future.value(reply(status, body));
  }

  static ResponseBody reply(int status, Map<String, dynamic> body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _context(String cityId, String cityName,
        {String? address = 'Haldwani, Nainital, Uttarakhand', bool cityResolved = true}) =>
    {
      'data': {
        'district': {'id': 'd1', 'name': 'Nainital', 'stateName': 'Uttarakhand'},
        'nearestCityId': cityId,
        'cities': [
          {'id': 'area', 'districtId': 'd1', 'name': 'Kamalwaganja', 'latitude': 29.24, 'longitude': 79.52},
          {'id': cityId, 'districtId': 'd1', 'name': cityName, 'latitude': 29.22, 'longitude': 79.51},
        ],
        'address': address,
        'cityResolved': cityResolved,
      },
    };

void main() {
  late _Loc loc;
  late _Adapter adapter;
  final area = CityModel(id: 'area', districtId: 'd1', name: 'Kamalwaganja', latitude: 29.24, longitude: 79.52);

  setUp(() {
    Get.testMode = true;
    Get.reset();
    ApiService.init();
    adapter = _Adapter();
    ApiService.dio.httpClientAdapter = adapter;
    loc = Get.put<LocationController>(_Loc()) as _Loc;
    loc.userLocation.value = const LatLng(29.24, 79.52);
    loc.autoCity.value = area;
  });

  tearDown(Get.reset);

  test('sets gpsCity and gpsCityDistrict from the includeAddress answer', () async {
    adapter.body = _context('hld', 'Haldwani');
    final city = await loc.ensureGpsCity();
    expect(city?.name, 'Haldwani');
    expect(loc.gpsCity.value?.name, 'Haldwani');
    expect(loc.gpsCityDistrict.value?.stateName, 'Uttarakhand');
    expect(loc.gpsCityOrNearest?.name, 'Haldwani');
    expect(adapter.requests.single.path, '/locations/context');
    expect(adapter.requests.single.queryParameters['includeAddress'], true);
    expect(loc.autoCity.value, same(area));
  });

  test('a resolved city is reused for the same autoCity, no second request', () async {
    adapter.body = _context('hld', 'Haldwani');
    await loc.ensureGpsCity();
    await loc.ensureGpsCity();
    expect(adapter.requests, hasLength(1));
  });

  test('a failure leaves gpsCity null and gpsCityOrNearest falls back to autoCity', () async {
    adapter.status = 404;
    adapter.body = const {'error': 'No district'};
    expect(await loc.ensureGpsCity(), isNull);
    expect(loc.gpsCity.value, isNull);
    expect(loc.gpsCityOrNearest, same(area));
  });

  test('a failed reverse lookup (no address, cityResolved false) is not a resolved city', () async {
    adapter.body = _context('area2', 'Kamalwaganja', address: null, cityResolved: false);
    expect(await loc.ensureGpsCity(), isNull);
    expect(loc.gpsCity.value, isNull);
    expect(loc.gpsCityOrNearest, same(area));
  });

  test('an address with the nearest row but cityResolved false is not a resolved city', () async {
    adapter.body = _context('area2', 'Kamalwaganja', address: 'Kamalwaganja, Haldwani, Nainital, Uttarakhand', cityResolved: false);
    expect(await loc.ensureGpsCity(), isNull);
    expect(loc.gpsCity.value, isNull);
    expect(loc.gpsCityOrNearest, same(area));
  });

  test('an answer without the cityResolved flag is not a resolved city', () async {
    final body = _context('hld', 'Haldwani');
    (body['data'] as Map<String, dynamic>).remove('cityResolved');
    adapter.body = body;
    expect(await loc.ensureGpsCity(), isNull);
    expect(loc.gpsCity.value, isNull);
  });

  test('single flight: two calls make one request', () async {
    adapter.hold = true;
    final a = loc.ensureGpsCity();
    final b = loc.ensureGpsCity();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, hasLength(1));
    adapter.pending.single.complete(_Adapter.reply(200, _context('hld', 'Haldwani')));
    expect((await a)?.name, 'Haldwani');
    expect((await b)?.name, 'Haldwani');
  });

  test('a stale answer is dropped when autoCity moved meanwhile', () async {
    adapter.hold = true;
    final first = loc.ensureGpsCity();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    loc.autoCity.value = CityModel(id: 'b', districtId: 'd1', name: 'Kathgodam', latitude: 29.26, longitude: 79.54);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, hasLength(2));
    adapter.pending[1].complete(_Adapter.reply(200, _context('ktg', 'Kathgodam Town')));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    adapter.pending[0].complete(_Adapter.reply(200, _context('hld', 'Haldwani')));
    await first;
    expect(loc.gpsCity.value?.name, 'Kathgodam Town');
  });

  test('no userLocation returns null without a request', () async {
    loc.userLocation.value = null;
    expect(await loc.ensureGpsCity(), isNull);
    expect(adapter.requests, isEmpty);
    expect(loc.gpsCityOrNearest, same(area));
  });

  test('a GPS fix that lands after the first call resolves the city once', () async {
    adapter.body = _context('hld', 'Haldwani');
    loc.userLocation.value = null;
    expect(await loc.ensureGpsCity(), isNull);
    expect(adapter.requests, isEmpty);
    loc.userLocation.value = const LatLng(29.24, 79.52);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, hasLength(1));
    expect(loc.gpsCity.value?.name, 'Haldwani');
    loc.userLocation.value = const LatLng(29.25, 79.53);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, hasLength(1));
  });

  test('an unresolved answer is not asked again on every GPS update', () async {
    adapter.body = _context('area2', 'Kamalwaganja', cityResolved: false);
    expect(await loc.ensureGpsCity(), isNull);
    loc.userLocation.value = const LatLng(29.25, 79.53);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, hasLength(1));
  });
}
