import 'dart:convert';
import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_spots_controller.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

// Serves two pages per version; the server moves from v1 to v2 after the first page was read.
class _Pages implements HttpClientAdapter {
  String live = '2026-11-22T10:00:00.000Z';
  final calls = <String>[];

  Map<String, dynamic> _spot(String id) => {'id': id, 'name': id, 'latitude': 30.0, 'longitude': 78.0, 'category': 'lake'};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final cursor = options.queryParameters['cursor'] as String?;
    calls.add('${cursor ?? 'first'}@$live');
    final tag = live.startsWith('2026-11-22') ? 'a' : 'b';
    final second = cursor != null;
    final body = {
      'data': {
        'items': [for (var i = 0; i < 2; i++) _spot('$tag${second ? i + 2 : i}')],
        'hasMore': !second,
        'nextCursor': second ? null : 'c1',
        'status': 'Ready',
        'cityName': 'Hill Town',
        'cityKey': 1,
        'total': 4,
        'generatedAt': live,
      },
    };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Pages server;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('spots_version').path,
    );
    await GetStorage.init();
    await TripSpotsCache.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.put<TabConfigController>(_Tabs());
    await GetStorage(TripSpotsCache.container).erase();
    ApiService.init();
    server = _Pages();
    ApiService.dio.httpClientAdapter = server;
  });

  tearDown(Get.reset);

  test('APP-20: the version changes between page 1 and 2: exactly one restart, screen and disk hold the full list of the new version', () async {
    final c = TripSpotsController(1);
    await c.load();
    expect(c.items.map((s) => s.id), ['a0', 'a1']);
    server.live = '2026-11-23T10:00:00.000Z';
    await c.loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(server.calls, [
      'first@2026-11-22T10:00:00.000Z',
      'c1@2026-11-23T10:00:00.000Z',
      'first@2026-11-23T10:00:00.000Z',
      'c1@2026-11-23T10:00:00.000Z',
    ]);
    expect(c.items.map((s) => s.id), ['b0', 'b1', 'b2', 'b3']);
    expect(c.version, DateTime.parse('2026-11-23T10:00:00.000Z').toIso8601String());
    expect(TripSpotsCache.load(1)!.map((s) => s.id), ['b0', 'b1', 'b2', 'b3']);
    expect(TripSpotsCache.versionOf(1), c.version);
    expect(c.hasMore.value, isFalse);
  });

  test('same version on every page: no restart, the merged list is stored', () async {
    final c = TripSpotsController(1);
    await c.load();
    await c.loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(server.calls, hasLength(2));
    expect(TripSpotsCache.load(1)!.map((s) => s.id), ['a0', 'a1', 'a2', 'a3']);
  });
}
