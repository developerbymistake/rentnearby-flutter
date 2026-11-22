import 'package:bakhli/features/map_discovery/data/map_pack_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_map_pack_api.dart';

const base = 'https://api.example.test/api/v1';

void main() {
  late List<({String path, Map<String, String>? headers})> sent;
  late Response<dynamic> Function(String path) answer;

  MapPackApi make() => MapPackApi(
        baseUrl: base,
        get: (path, headers) async {
          sent.add((path: path, headers: headers));
          return answer(path);
        },
      );

  Response<dynamic> res(int code, [Object? data]) =>
      Response<dynamic>(requestOptions: RequestOptions(path: '/'), statusCode: code, data: data);

  setUp(() {
    sent = [];
    answer = (_) => res(200, '{"fields":[],"s":[]}');
  });

  test('200 returns the body; no etag means no If-None-Match header', () async {
    final r = await make().fetch(ref('s1'));
    expect(r.notModified, false);
    expect(r.body, '{"fields":[],"s":[]}');
    expect(sent.single.path, '/trips/map-packs/s1/v1');
    expect(sent.single.headers, isNull);
  });

  test('etag is sent quoted; 304 is notModified', () async {
    answer = (_) => res(304);
    final r = await make().fetch(ref('s1', version: 'v2'), etag: 'v1');
    expect(r.notModified, true);
    expect(r.body, isNull);
    expect(sent.single.headers, {'If-None-Match': '"v1"'});
  });

  test('200 with an empty body is a failure', () async {
    answer = (_) => res(200, '   ');
    final r = await make().fetch(ref('s1'));
    expect(r, MapPackApi.failed);
    answer = (_) => res(200);
    expect(await make().fetch(ref('s1')), MapPackApi.failed);
  });

  test('a decoded map body is re-encoded as text', () async {
    answer = (_) => res(200, {'fields': ['id'], 's': []});
    final r = await make().fetch(ref('s1'));
    expect(r.body, '{"fields":["id"],"s":[]}');
  });

  test('T12: a path on another host makes no request', () async {
    for (final p in [
      'https://evil.example.com/trips/map-packs/s1/v1',
      'http://api.example.test/trips/map-packs/s1/v1',
      '//evil.example.com/x',
      'ftp://api.example.test/x',
      'https://user@api.example.test/x',
      r'\\evil\x',
      '',
    ]) {
      final r = await make().fetch(ref('s1', path: p));
      expect(r, MapPackApi.failed, reason: p);
    }
    expect(sent, isEmpty);
  });

  test('requestPath: relative and same-origin absolute pass', () {
    expect(MapPackApi.requestPath('/trips/map-packs/a/1', base), '/trips/map-packs/a/1');
    expect(MapPackApi.requestPath('trips/map-packs/a/1', base), '/trips/map-packs/a/1');
    expect(MapPackApi.requestPath('https://API.example.test/api/v1/trips/x', base), 'https://API.example.test/api/v1/trips/x');
    expect(MapPackApi.requestPath('https://api.example.test:8443/x', base), isNull);
  });

  test('errors from the transport propagate to the caller (service counts them as failed)', () async {
    answer = (_) => throw DioException(requestOptions: RequestOptions(path: '/'), type: DioExceptionType.connectionError);
    expect(() => make().fetch(ref('s1')), throwsA(isA<DioException>()));
  });
}
