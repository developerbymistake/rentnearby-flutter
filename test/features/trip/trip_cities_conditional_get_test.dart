import 'dart:typed_data';

import 'package:bakhli/features/trip/data/trip_repository.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
