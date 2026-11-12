import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/utils/cloudinary_thumb.dart';
import 'package:flutter_test/flutter_test.dart';

TripCityModel _c({String? image, String? cover}) =>
    TripCityModel(cityKey: 1, name: 'A', latitude: 1, longitude: 1, imageUrl: image, coverUrl: cover);

void main() {
  const raw = 'https://res.cloudinary.com/x/image/upload/v1/a.jpg';
  const done = 'https://res.cloudinary.com/x/image/upload/c_fill,w_480/a.jpg';

  test('coverUrl wins over imageUrl', () {
    expect(_c(image: raw, cover: done).cover, done);
  });

  test('imageUrl is thumbnailed when there is no coverUrl', () {
    expect(_c(image: raw).cover, 'https://res.cloudinary.com/x/image/upload/c_fill,w_480,h_360,q_auto,f_auto/v1/a.jpg');
  });

  test('empty coverUrl falls back to imageUrl', () {
    expect(_c(image: raw, cover: '').cover, contains('w_480'));
  });

  test('no image at all gives null so the placeholder shows', () {
    expect(_c().cover, isNull);
    expect(_c(image: '', cover: '').cover, isNull);
  });

  test('coverUrl round trips through json', () {
    final back = TripCityModel.fromJson(_c(image: raw, cover: 'u').toJson());
    expect(back.coverUrl, 'u');
    expect(back.imageUrl, raw);
  });

  group('CloudinaryThumb', () {
    test('non cloudinary and already transformed urls are unchanged', () {
      expect(CloudinaryThumb.of('https://example.com/a.jpg'), 'https://example.com/a.jpg');
      const transformed = 'https://res.cloudinary.com/x/image/upload/w_100/a.jpg';
      expect(CloudinaryThumb.of(transformed), transformed);
      expect(CloudinaryThumb.of(null), isNull);
      expect(CloudinaryThumb.of(''), '');
    });
  });
}
