import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
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
