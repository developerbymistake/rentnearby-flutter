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

Map<String, dynamic> _row(String id, {Object? lat = 1, Object? lon = 2, Object? images, Object? imageUrl, Object? galleryCount}) => {
      'id': id,
      'latitude': lat,
      'longitude': lon,
      'images': ?images,
      'imageUrl': ?imageUrl,
      'galleryCount': ?galleryCount,
    };

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

  test('fromJson reads images into photos', () {
    final m = TripSpotModel.fromJson(_row('1', imageUrl: 'https://i/u', images: ['https://i/u', 'https://i/v']));
    expect(m.photos, ['https://i/u', 'https://i/v']);
    expect(m.hasPhoto, true);
  });

  test('images: cap 3, duplicates removed in order, bad urls dropped, relative made absolute', () {
    final m = TripSpotModel.fromJson(_row('1', images: ['https://a/1', 'https://a/1', 7, '', 'ftp://x', 'https://a/2', '/media/3.jpg', 'https://a/4']));
    expect(m.images.length, 3);
    expect(m.images[0], 'https://a/1');
    expect(m.images[1], 'https://a/2');
    expect(m.images[2], endsWith('/media/3.jpg'));
    expect(m.images[2], startsWith('http'));
  });

  test('photos falls back to imageUrl and caps a long constructor list', () {
    expect(TripSpotModel.fromJson(_row('1', imageUrl: 'https://a/c')).photos, ['https://a/c']);
    expect(TripSpotModel.fromJson(_row('1', imageUrl: 'nope')).photos, isEmpty);
    expect(_s('x', 0, images: ['1', '2', '3', '4', '5']).photos, ['1', '2', '3']);
  });

  test('galleryCount: missing 0, string 0, 99 clamps to 10, negative 0', () {
    expect(TripSpotModel.fromJson(_row('1')).galleryCount, 0);
    expect(TripSpotModel.fromJson(_row('1', galleryCount: '4')).galleryCount, 0);
    expect(TripSpotModel.fromJson(_row('1', galleryCount: 99)).galleryCount, 10);
    expect(TripSpotModel.fromJson(_row('1', galleryCount: -2)).galleryCount, 0);
    expect(TripSpotModel.fromJson(_row('1', galleryCount: 4)).galleryCount, 4);
  });

  test('tryFromJson skips empty id, missing or bad coordinates, non maps', () {
    expect(TripSpotModel.tryFromJson(_row('')), isNull);
    expect(TripSpotModel.tryFromJson({'latitude': 1, 'longitude': 2}), isNull);
    expect(TripSpotModel.tryFromJson(_row('1', lat: null)), isNull);
    expect(TripSpotModel.tryFromJson(_row('1', lon: 'x')), isNull);
    expect(TripSpotModel.tryFromJson(_row('1', lat: double.nan)), isNull);
    expect(TripSpotModel.tryFromJson('x'), isNull);
    expect(TripSpotModel.tryFromJson(_row('1'))!.id, '1');
  });

  test('fromJson is null safe on id', () {
    expect(TripSpotModel.fromJson({'latitude': 1, 'longitude': 2}).id, '');
  });

  test('page skips a bad item and keeps the others', () {
    final page = TripSpotsPage.fromJson({
      'items': [_row('a'), _row(''), 'junk', _row('b', lat: null), _row('c', galleryCount: 3)],
      'status': 'Ready',
      'generatedAt': '2026-11-22T10:00:00Z',
    });
    expect(page.items.map((e) => e.id), ['a', 'c']);
    expect(page.items.last.galleryCount, 3);
    expect(page.version, '2026-11-22T10:00:00.000Z');
  });

  test('page with no generatedAt has an empty version', () {
    expect(TripSpotsPage.fromJson({'items': 'x'}).version, '');
  });

  test('toJson round trip keeps galleryCount', () {
    final m = TripSpotModel.fromJson(_row('1', galleryCount: 6, images: ['https://a/1']));
    final back = TripSpotModel.fromJson(m.toJson());
    expect(back.galleryCount, 6);
    expect(back.photos, ['https://a/1']);
  });
}
