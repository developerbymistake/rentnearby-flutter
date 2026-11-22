import 'dart:io';

import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/data/trip_repository.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

const _version = '{"data": {"version": "c1", "count": 3, "stale": false, "mapDiscovery": true, "packsKnown": true, "packs": []}}';
const _page = '{"data": {"items": [], "hasMore": false, "version": "c1", "count": 0, "stale": false}}';

class _Api implements HttpClientAdapter {
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final tag = options.path.endsWith('/version') ? 'W/"v.1"' : 'W/"p.1"';
    if (options.headers['If-None-Match'] == tag) return ResponseBody.fromString('', 304, headers: {'etag': [tag]});
    return ResponseBody.fromString(options.path.endsWith('/version') ? _version : _page, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      'etag': [tag],
    });
  }

  @override
  void close({bool force = false}) {}
}

String _cityPage(int key, {required bool more}) =>
    '{"data": {"items": [{"cityKey": $key, "name": "City $key", "latitude": 30.0, "longitude": 78.0}], "hasMore": $more, "version": "c1", "count": 2, "stale": false}}';

// Two pages of one city each; the first page answers 304 for the current tag.
class _Pages implements HttpClientAdapter {
  final List<RequestOptions> seen = [];
  String tag = 'W/"c1"';

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final page = options.queryParameters['page'];
    if (page == 1 && options.headers['If-None-Match'] == tag) return ResponseBody.fromString('', 304, headers: {'etag': [tag]});
    return ResponseBody.fromString(_cityPage(page == 1 ? 1 : 2, more: page == 1), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      'etag': [tag],
    });
  }

  @override
  void close({bool force = false}) {}
}

// MAP_MASTER S-03: the cities version and the first cities page send If-None-Match.
void main() {
  test('version: second call sends the etag and a 304 reuses the last answer', () async {
    ApiService.init();
    final api = _Api();
    ApiService.dio.httpClientAdapter = api;
    const repo = TripRepository();

    final a = await repo.citiesVersion(once: true);
    final b = await repo.citiesVersion(once: true);

    expect(api.seen.first.headers['If-None-Match'], isNull);
    expect(api.seen.last.headers['If-None-Match'], 'W/"v.1"');
    expect(a.version, 'c1');
    expect(b.version, 'c1');
    expect(b.mapDiscovery, isTrue);
  });

  test('first page: 304 with the stored etag returns no page', () async {
    ApiService.init();
    final api = _Api();
    ApiService.dio.httpClientAdapter = api;
    const repo = TripRepository();

    final first = await repo.citiesFirstPage(etag: null);
    expect(first.page?.version, 'c1');
    final again = await repo.citiesFirstPage(etag: first.etag);

    expect(api.seen.last.headers['If-None-Match'], 'W/"p.1"');
    expect(again.page, isNull);
  });

  test('catalog: a reload asks only the first page; 304 keeps the list, a new tag reuses that answer as page 1', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (_) async => Directory.systemTemp.createTempSync('s03_gs').path);
    await GetStorage.init();
    ApiService.init();
    final api = _Pages();
    ApiService.dio.httpClientAdapter = api;
    final catalog = TripCityCatalog();

    final first = await catalog.load();
    expect(first.map((c) => c.cityKey), [1, 2]);
    expect(api.seen.length, 2);
    expect(api.seen.first.headers['If-None-Match'], isNull);

    final same = await catalog.load(force: true);
    expect(identical(same, first), isTrue);
    expect(api.seen.length, 3);
    expect(api.seen.last.headers['If-None-Match'], 'W/"c1"');
    expect(api.seen.last.queryParameters['page'], 1);

    api.tag = 'W/"c2"';
    final changed = await catalog.load(force: true);
    expect(changed.map((c) => c.cityKey), [1, 2]);
    expect(api.seen.length, 5);
    expect(api.seen[3].headers['If-None-Match'], 'W/"c1"');
    expect(api.seen[4].queryParameters['page'], 2);

    await catalog.load(force: true);
    expect(api.seen.length, 6);
    expect(api.seen.last.headers['If-None-Match'], 'W/"c2"');
  });
}
