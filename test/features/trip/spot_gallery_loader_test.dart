import 'dart:async';
import 'dart:io';

import 'package:bakhli/features/trip/data/spot_gallery_loader.dart';
import 'package:bakhli/features/trip/data/trip_repository.dart';
import 'package:bakhli/features/trip/utils/spot_gallery_cache.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

class _Repo extends TripRepository {
  int calls = 0;
  Completer<SpotDetail>? gate;
  Object? error;
  String version = '';

  @override
  Future<SpotDetail> spotDetail(int cityKey, String spotId) async {
    calls++;
    if (gate != null) return gate!.future;
    if (error != null) throw error!;
    return SpotDetail(gallery: ['https://a/$spotId'], version: version);
  }
}

void main() {
  late _Repo repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('spot_gallery_loader').path,
    );
    await GetStorage.init();
    await TripSpotsCache.init();
  });

  setUp(() {
    SpotGalleryLoader.debugReset();
    SpotGalleryCache.clear();
    repo = _Repo();
    SpotGalleryLoader.repository = repo;
  });

  group('revalidate (map Details, D12)', () {
    test('skips a cached entry, asks once and stores the answer under the answer version', () async {
      await SpotGalleryLoader.load(1, 's', 'v1');
      repo.version = '2026-11-23T10:00:00.000Z';
      final d = await SpotGalleryLoader.load(1, 's', 'v1', revalidate: true);
      expect(repo.calls, 2);
      expect(d.version, '2026-11-23T10:00:00.000Z');
      expect(SpotGalleryCache.get(1, 's', '2026-11-23T10:00:00.000Z'), isNotNull);
      await SpotGalleryLoader.load(1, 's', '2026-11-23T10:00:00.000Z');
      expect(repo.calls, 2);
    });

    test('two parallel revalidate calls = one request, whatever version they carry', () async {
      repo.gate = Completer<SpotDetail>();
      final a = SpotGalleryLoader.load(1, 's', 'v1', revalidate: true);
      final b = SpotGalleryLoader.load(1, 's', '', revalidate: true);
      repo.gate!.complete(const SpotDetail(gallery: ['https://a/x'], version: 'v9'));
      expect((await a).gallery, ['https://a/x']);
      expect((await b).gallery, ['https://a/x']);
      expect(repo.calls, 1);
    });

    test('an answer without a version is not stored', () async {
      await SpotGalleryLoader.load(1, 's', '', revalidate: true);
      expect(SpotGalleryCache.memoryLength, 0);
    });

    test('SpotDetail.version uses the TripSpotsPage normalisation of generatedAt', () {
      expect(SpotDetail.fromJson({'generatedAt': '2026-11-23T10:00:00Z'}).version, DateTime.parse('2026-11-23T10:00:00Z').toIso8601String());
      expect(SpotDetail.fromJson({}).version, '');
      expect(SpotDetail.fromJson({'generatedAt': 'x'}).version, '');
    });
  });

  test('second load of the same version is a cache hit', () async {
    expect((await SpotGalleryLoader.load(1, 's', 'v1')).gallery, ['https://a/s']);
    expect((await SpotGalleryLoader.load(1, 's', 'v1')).gallery, ['https://a/s']);
    expect(repo.calls, 1);
  });

  test('a new version refetches', () async {
    await SpotGalleryLoader.load(1, 's', 'v1');
    await SpotGalleryLoader.load(1, 's', 'v2');
    expect(repo.calls, 2);
  });

  test('single flight: two callers, one request', () async {
    repo.gate = Completer<SpotDetail>();
    final a = SpotGalleryLoader.load(1, 's', 'v1');
    final b = SpotGalleryLoader.load(1, 's', 'v1');
    repo.gate!.complete(const SpotDetail(gallery: ['https://a/x']));
    expect((await a).gallery, ['https://a/x']);
    expect((await b).gallery, ['https://a/x']);
    expect(repo.calls, 1);
  });

  test('failure is not cached and the next call retries', () async {
    repo.error = Exception('down');
    await expectLater(SpotGalleryLoader.load(1, 's', 'v1'), throwsException);
    repo.error = null;
    expect((await SpotGalleryLoader.load(1, 's', 'v1')).gallery, ['https://a/s']);
    expect(repo.calls, 2);
  });

  test('repository passed by parameter wins', () async {
    final other = _Repo();
    await SpotGalleryLoader.load(1, 'p', 'v1', repo: other);
    expect(other.calls, 1);
    expect(repo.calls, 0);
  });

  test('SpotDetail parses the gallery defensively and the full spot', () {
    final d = SpotDetail.fromJson({
      'id': 'a',
      'latitude': 1,
      'longitude': 2,
      'name': 'Lake',
      'gallery': ['https://g/1', 'https://g/1', 3, '', for (var i = 2; i < 15; i++) 'https://g/$i'],
    });
    expect(d.gallery.length, 10);
    expect(d.gallery.first, 'https://g/1');
    expect(d.spot!.name, 'Lake');
    expect(SpotDetail.fromJson({'gallery': 'x'}).gallery, isEmpty);
    expect(SpotDetail.fromJson({}).spot, isNull);
  });
}
