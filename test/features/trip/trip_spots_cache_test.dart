import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

TripSpotModel _s(String id, {int gallery = 0}) => TripSpotModel(
      id: id,
      source: 'x',
      name: 'Spot $id',
      latitude: 30,
      longitude: 78,
      category: 'lake',
      visitMinutes: 60,
      galleryCount: gallery,
    );

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('trip_spots_cache').path,
    );
    await GetStorage.init();
    GetStorage().write('trip_spots_list_cache_7', '{"t":1}');
    GetStorage().write('other_key', 'keep');
    await TripSpotsCache.init();
  });

  setUp(() async {
    await GetStorage(TripSpotsCache.container).erase();
  });

  test('own box name and old default-box keys removed once at init', () {
    expect(TripSpotsCache.container, 'trip_spots');
    expect(TripSpotsCache.box, isNotNull);
    expect(GetStorage().hasData('trip_spots_list_cache_7'), isFalse);
    expect(GetStorage().read<String>('other_key'), 'keep');
  });

  test('save stores the version and load returns the items', () async {
    TripSpotsCache.save(1, [_s('a'), _s('b')], 'v1');
    await _settle();
    expect(TripSpotsCache.load(1)!.map((e) => e.id), ['a', 'b']);
    expect(TripSpotsCache.versionOf(1), 'v1');
    final raw = jsonDecode(GetStorage(TripSpotsCache.container).read<String>('c:1')!) as Map;
    expect(raw['v'], 'v1');
    expect(GetStorage().getKeys<Iterable<dynamic>>().whereType<String>().any((k) => k.startsWith('c:')), isFalse);
  });

  test('versionOf is null when nothing is stored', () {
    expect(TripSpotsCache.versionOf(42), isNull);
    expect(TripSpotsCache.load(42), isNull);
  });

  test('a new version replaces the entry, never mixes', () async {
    TripSpotsCache.save(1, [_s('a'), _s('b')], 'v1');
    TripSpotsCache.save(1, [_s('c')], 'v2');
    await _settle();
    expect(TripSpotsCache.load(1)!.map((e) => e.id), ['c']);
    expect(TripSpotsCache.versionOf(1), 'v2');
  });

  test('merged list after loadMore is stored whole, capped at 300', () async {
    final many = [for (var i = 0; i < 320; i++) _s('$i')];
    TripSpotsCache.save(2, many, 'v1');
    await _settle();
    expect(TripSpotsCache.load(2)!.length, TripSpotsCache.maxItems);
  });

  test('expired entry, corrupt entry and a bad row', () {
    final now = DateTime(2026, 11, 22, 12);
    final raw = TripSpotsCache.encode([_s('a')], now, version: 'v');
    expect(TripSpotsCache.decodeEntry(raw, now.add(const Duration(hours: 25))), isNull);
    expect(TripSpotsCache.decodeEntry('{bad', now), isNull);
    expect(TripSpotsCache.decodeEntry('{"t":"x","items":[]}', now), isNull);
    final mixed = jsonEncode({
      't': now.millisecondsSinceEpoch,
      'v': 'v',
      'items': [
        _s('a').toJson(),
        {'id': '', 'latitude': 1, 'longitude': 1},
        {'id': 'z'},
        'junk',
      ],
    });
    expect(TripSpotsCache.decodeEntry(mixed, now)!.items.map((e) => e.id), ['a']);
  });

  test('galleryCount round trip', () {
    final now = DateTime(2026, 11, 22, 12);
    final back = TripSpotsCache.decode(TripSpotsCache.encode([_s('a', gallery: 7)], now), now)!;
    expect(back.single.galleryCount, 7);
  });

  test('clear empties the box', () async {
    TripSpotsCache.save(3, [_s('a')], 'v1');
    await _settle();
    TripSpotsCache.clear();
    await _settle();
    expect(TripSpotsCache.load(3), isNull);
  });
}
