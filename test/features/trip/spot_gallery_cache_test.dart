import 'dart:io';

import 'package:bakhli/features/trip/data/spot_gallery_loader.dart';
import 'package:bakhli/features/trip/utils/spot_gallery_cache.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

SpotDetail _d(List<String> urls) => SpotDetail(gallery: urls);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('spot_gallery_cache').path,
    );
    await GetStorage.init();
    await TripSpotsCache.init();
  });

  setUp(() async {
    SpotGalleryCache.clear();
    await GetStorage(TripSpotsCache.container).erase();
  });

  test('hit by version, miss on a new version', () {
    SpotGalleryCache.put(1, 's', 'v1', _d(['https://a/1']));
    expect(SpotGalleryCache.get(1, 's', 'v1')!.gallery, ['https://a/1']);
    expect(SpotGalleryCache.get(1, 's', 'v2'), isNull);
    expect(SpotGalleryCache.get(2, 's', 'v1'), isNull);
  });

  test('disk copy survives a memory wipe and checks version and age', () async {
    final now = DateTime.now();
    SpotGalleryCache.put(1, 's', 'v1', _d(['https://a/1', 'https://a/2']), now: now);
    await _settle();
    expect(GetStorage(TripSpotsCache.container).hasData('g:1:s'), isTrue);
    SpotGalleryCache.debugForgetMemory();
    expect(SpotGalleryCache.get(1, 's', 'v1', now: now)!.gallery, ['https://a/1', 'https://a/2']);
    SpotGalleryCache.debugForgetMemory();
    expect(SpotGalleryCache.get(1, 's', 'v2', now: now), isNull);
    expect(SpotGalleryCache.get(1, 's', 'v1', now: now.add(const Duration(hours: 25))), isNull);
  });

  test('empty version is a memory copy only', () async {
    SpotGalleryCache.put(1, 's', '', _d(['https://a/1']));
    await _settle();
    expect(SpotGalleryCache.get(1, 's', '')!.gallery, ['https://a/1']);
    expect(GetStorage(TripSpotsCache.container).hasData('g:1:s'), isFalse);
  });

  test('memory LRU keeps the 50 most recent spots', () {
    for (var i = 0; i < 55; i++) {
      SpotGalleryCache.put(1, 's$i', '', _d(['https://a/$i']));
    }
    expect(SpotGalleryCache.memoryLength, SpotGalleryCache.maxMemory);
    expect(SpotGalleryCache.get(1, 's0', ''), isNull);
    expect(SpotGalleryCache.get(1, 's54', ''), isNotNull);
  });

  test('clear wipes memory and disk', () async {
    SpotGalleryCache.put(1, 's', 'v1', _d(['https://a/1']));
    await _settle();
    SpotGalleryCache.clear();
    expect(SpotGalleryCache.get(1, 's', 'v1'), isNull);
    expect(GetStorage(TripSpotsCache.container).hasData('g:1:s'), isFalse);
  });
}
