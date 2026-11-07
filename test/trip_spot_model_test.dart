import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';

TripSpotModel _s(String id, int rank, {List<String> images = const []}) => TripSpotModel(
      id: id,
      source: 's',
      name: id,
      latitude: 0,
      longitude: 0,
      category: 'attraction',
      visitMinutes: 60,
      rank: rank,
      images: images,
    );

void main() {
  test('photoFirst keeps rank order and is stable inside a rank', () {
    final out = TripSpotModel.photoFirst([
      _s('a', 1),
      _s('b', 1, images: ['x']),
      _s('c', 1, images: ['y']),
      _s('d', 2, images: ['z']),
      _s('e', 2),
    ]);
    expect(out.map((e) => e.id).toList(), ['b', 'c', 'a', 'd', 'e']);
  });

  test('fromJson reads images', () {
    final m = TripSpotModel.fromJson({
      'id': '1',
      'latitude': 1,
      'longitude': 2,
      'imageUrl': 'u',
      'images': ['u', 'v'],
    });
    expect(m.gallery, ['u', 'v']);
    expect(m.hasPhoto, true);
  });
}
