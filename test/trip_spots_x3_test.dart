import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:bakhli/features/trip/utils/trip_spots_map_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripSpotModel _s(String id, {int rank = 0, String? img}) => TripSpotModel(
      id: id,
      source: 'x',
      name: 'Spot $id',
      latitude: 30,
      longitude: 78,
      category: 'lake',
      visitMinutes: 60,
      rank: rank,
      imageUrl: img,
      images: img == null ? const [] : [img],
    );

void main() {
  group('pickPins', () {
    test('selected first in pick order, then list order', () {
      final all = [for (var i = 0; i < 6; i++) _s('$i')];
      final out = TripSpotsMapRules.pickPins(all: all, visible: all, selectedOrder: ['4', '1']);
      expect(out.map((e) => e.id).toList(), ['4', '1', '0', '2', '3', '5']);
    });

    test('caps at 40 and keeps selected', () {
      final all = [for (var i = 0; i < 100; i++) _s('$i')];
      final out = TripSpotsMapRules.pickPins(all: all, visible: all, selectedOrder: ['99']);
      expect(out.length, 40);
      expect(out.first.id, '99');
      expect(out.map((e) => e.id).toSet().length, 40);
    });

    test('selected outside the filter still shown', () {
      final all = [_s('a'), _s('b'), _s('c')];
      final out = TripSpotsMapRules.pickPins(all: all, visible: [all[0]], selectedOrder: ['c']);
      expect(out.map((e) => e.id).toList(), ['c', 'a']);
    });

    test('numberOf is 1-based and 0 when absent', () {
      expect(TripSpotsMapRules.numberOf(['x', 'y'], 'y'), 2);
      expect(TripSpotsMapRules.numberOf(['x', 'y'], 'z'), 0);
    });
  });

  group('TripSpotsCache', () {
    final now = DateTime(2026, 11, 7, 12);

    test('round trip keeps fields', () {
      final raw = TripSpotsCache.encode([_s('1', rank: 3, img: 'http://i/1.jpg')], now);
      final back = TripSpotsCache.decode(raw, now.add(const Duration(hours: 1)))!;
      expect(back.single.id, '1');
      expect(back.single.rank, 3);
      expect(back.single.gallery, ['http://i/1.jpg']);
      expect(back.single.visitMinutes, 60);
    });

    test('expires after 24 h', () {
      final raw = TripSpotsCache.encode([_s('1')], now);
      expect(TripSpotsCache.decode(raw, now.add(const Duration(hours: 23))), isNotNull);
      expect(TripSpotsCache.decode(raw, now.add(const Duration(hours: 25))), isNull);
    });

    test('bad or empty input returns null', () {
      expect(TripSpotsCache.decode(null, now), isNull);
      expect(TripSpotsCache.decode('not json', now), isNull);
      expect(TripSpotsCache.decode(TripSpotsCache.encode([], now), now), isNull);
    });
  });
}
