import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_tiers.dart';
import 'package:bakhli/features/trip/map/map_marker_art.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(Uint8List png) async => (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MapMarkerArt.debugReset);
  tearDown(MapMarkerArt.debugReset);

  test('pin for null, empty, blank and the generic attraction type', () {
    expect(MapMarkerArt.assetFor(null), ListingArt.roundPushpin);
    expect(MapMarkerArt.assetFor(''), ListingArt.roundPushpin);
    expect(MapMarkerArt.assetFor('  '), ListingArt.roundPushpin);
    expect(MapMarkerArt.assetFor('attraction'), ListingArt.roundPushpin);
    expect(MapMarkerArt.assetFor('place'), ListingArt.roundPushpin);
    expect(MapMarkerArt.assetFor('no-such-type'), ListingArt.roundPushpin);
  });

  test('known categories use the app 3D type icon, case does not matter', () {
    for (final c in DiscIds.badgeCategories) {
      if (c == DiscIds.badgeDefault) continue;
      expect(MapMarkerArt.assetFor(c), TripSpotLook.assetOf(c), reason: c);
    }
    expect(MapMarkerArt.assetFor('Temple'), ListingArt.hinduTemple);
    expect(MapMarkerArt.assetFor('temple'), isNot(ListingArt.roundPushpin));
  });

  test('badge art and stop art always come from the same asset', () {
    for (final c in [...DiscIds.badgeCategories, 'market', 'Market', 'Temple', 'attraction', '', 'unknown-type']) {
      expect(MapMarkerArt.assetFor(DiscIds.badgeKey(c)), MapMarkerArt.assetFor(c), reason: c);
    }
  });

  test('every Atlas category (BackendV2 SpotCategories.All) has its own badge and a 3D icon; attraction is the pin', () {
    const atlas = [
      'temple', 'fort', 'palace', 'museum', 'lake', 'waterfall', 'viewpoint', 'park', 'garden',
      'zoo', 'wildlife', 'bridge', 'ghat', 'cave', 'historic', 'beach', 'attraction',
    ];
    expect(atlas.length, 17);
    for (final c in atlas) {
      if (c == 'attraction') {
        expect(DiscIds.badgeKey(c), DiscIds.badgeDefault);
        expect(MapMarkerArt.assetFor(c), ListingArt.roundPushpin);
        continue;
      }
      expect(DiscIds.badgeCategories, contains(c), reason: c);
      expect(DiscIds.badgeKey(c.toUpperCase()), c, reason: c);
      expect(MapMarkerArt.assetFor(c), isNot(ListingArt.roundPushpin), reason: c);
    }
    for (final c in DiscIds.badgeCategories) {
      if (c == DiscIds.badgeDefault) continue;
      expect(TripSpotLook.assetOf(c), isNot(ListingArt.roundPushpin), reason: '$c is a badge type without its own icon');
    }
  });

  test('colour and dot group ignore the category case', () {
    for (final c in DiscIds.badgeCategories) {
      expect(DiscTiers.groupOf(c.toUpperCase()), DiscTiers.groupOf(c), reason: c);
    }
    expect(DiscTiers.groupOf(' Temple '), DiscTiers.grpHeritage);
    expect(DiscTiers.groupOf('LAKE'), DiscTiers.grpWater);
  });

  testWidgets('an icon is decoded once per asset and size, then reused', (tester) async {
    await tester.runAsync(() async {
      final a = await MapMarkerArt.image('temple', 64);
      final b = await MapMarkerArt.image('temple', 64);
      expect(a, isNotNull);
      expect(identical(a, b), isTrue);
      expect(MapMarkerArt.decodeCount, 1);
      await Future.wait([MapMarkerArt.image('fort', 64), MapMarkerArt.image('fort', 64), MapMarkerArt.image('fort', 64)]);
      expect(MapMarkerArt.decodeCount, 2);
      await MapMarkerArt.image('temple', 96);
      expect(MapMarkerArt.decodeCount, 3, reason: 'size is part of the key');
      await MapMarkerArt.image(null, 64);
      await MapMarkerArt.image('attraction', 64);
      expect(MapMarkerArt.decodeCount, 4, reason: 'null and attraction share the pin');
    });
  });

  testWidgets('badges of one category share one decode and keep the badge canvas size', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      final t = DiscTuning.trip;
      final one = await _decode(await painter.badge('temple', t));
      await painter.badge('temple', t);
      await painter.badge('temple', t);
      expect(MapMarkerArt.decodeCount, 1);
      expect(one.width, t.px(CanvasMarkerPainter.canvasDp(t.badgeDp)));
      final bytes = (await one.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final c = one.width ~/ 2;
      final ring = (c * one.width + (c + (t.badgeDp / 2).floor() - 2)) * 4;
      expect(bytes.getUint8(ring + 3), greaterThan(200), reason: 'badge circle and white ring are still drawn');
    });
  });

  testWidgets('a stop without a photo draws the 3D icon, the pin for an untyped spot', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      final t = DiscTuning.tripStops;
      const ring = ui.Color(0xFFFF8A3D);
      final typed = await painter.stop(category: 'temple', ring: ring, number: 1, t: t);
      final plain = await painter.stop(category: 'attraction', ring: ring, number: 1, t: t);
      final empty = await painter.stop(category: '', ring: ring, number: 1, t: t);
      expect(await painter.valid(typed), isTrue);
      expect(plain, empty, reason: 'attraction and empty both show the pin');
      expect(typed, isNot(plain));
      expect((await _decode(typed)).width, t.px(CanvasMarkerPainter.stopCanvasDp(t)));
    });
  });

  test('image cache key keeps the size in it', () {
    final small = DiscTuning(photoMax: 40, photoDp: 54);
    final big = DiscTuning(photoMax: 40, photoDp: 90);
    expect(TripMarkerImages.cacheKey('s1', 'https://a/x.jpg', small), isNot(TripMarkerImages.cacheKey('s1', 'https://a/x.jpg', big)));
  });
}
