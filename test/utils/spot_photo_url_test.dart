import 'package:bakhli/utils/spot_photo_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _raw = 'https://res.cloudinary.com/demo/image/upload/v3/atlas/spots/a.jpg';

void main() {
  test('each size inserts its exact segment after /image/upload/', () {
    const expected = {
      SpotPhotoSize.marker: 'c_fill,w_288,h_288,q_auto,f_auto',
      SpotPhotoSize.square: 'c_fill,g_auto,w_320,h_320,q_auto,f_auto',
      SpotPhotoSize.card: 'c_fill,g_auto,w_720,h_400,q_auto,f_auto',
      SpotPhotoSize.hero: 'c_fill,g_auto,w_1080,h_640,q_auto,f_auto',
      SpotPhotoSize.full: 'c_limit,w_1280,q_auto,f_auto',
    };
    expect(SpotPhotoSize.values.length, 5);
    for (final e in expected.entries) {
      expect(SpotPhotoUrl.of(_raw, e.key), 'https://res.cloudinary.com/demo/image/upload/${e.value}/v3/atlas/spots/a.jpg');
      expect(SpotPhotoUrl.transforms[e.key], e.value);
    }
  });

  test('foreign host that only ends with cloudinary.com is returned unchanged', () {
    const u = 'https://evilcloudinary.com/image/upload/a.jpg';
    expect(SpotPhotoUrl.of(u, SpotPhotoSize.card), u);
  });

  test('pixel widths are fixed', () {
    expect(SpotPhotoSize.values.map(SpotPhotoUrl.pixelWidth).toList(), [288, 320, 720, 1080, 1280]);
  });

  test('non-Cloudinary, no upload marker, already transformed, null and empty stay unchanged', () {
    for (final size in SpotPhotoSize.values) {
      expect(SpotPhotoUrl.of(null, size), isNull);
      expect(SpotPhotoUrl.of('', size), '');
      expect(SpotPhotoUrl.of('https://upload.wikimedia.org/a.jpg', size), 'https://upload.wikimedia.org/a.jpg');
      expect(SpotPhotoUrl.of('https://res.cloudinary.com/demo/video/upload/v1/a.mp4', size), 'https://res.cloudinary.com/demo/video/upload/v1/a.mp4');
      expect(SpotPhotoUrl.of('not a url', size), 'not a url');
      for (final p in ['c_fill,w_10', 'w_10', 'f_auto', 'q_auto', 'g_auto']) {
        final u = 'https://res.cloudinary.com/demo/image/upload/$p/v1/a.jpg';
        expect(SpotPhotoUrl.of(u, size), u);
      }
      final once = SpotPhotoUrl.of(_raw, size);
      expect(SpotPhotoUrl.of(once, size), once);
    }
  });

  testWidgets('cacheWidth uses the device pixel ratio and clamps', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 3),
      child: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    expect(SpotPhotoUrl.cacheWidth(ctx, 100, SpotPhotoSize.card), 300);
    expect(SpotPhotoUrl.cacheWidth(ctx, 100.2, SpotPhotoSize.card), 301);
    expect(SpotPhotoUrl.cacheWidth(ctx, 400, SpotPhotoSize.card), 720);
    expect(SpotPhotoUrl.cacheWidth(ctx, 40, SpotPhotoSize.marker), 120);
    expect(SpotPhotoUrl.cacheWidth(ctx, 200, SpotPhotoSize.marker), 288);
    expect(SpotPhotoUrl.cacheWidth(ctx, 0, SpotPhotoSize.square), 1);
    expect(SpotPhotoUrl.cacheWidth(ctx, double.infinity, SpotPhotoSize.hero), 1080);
    expect(SpotPhotoUrl.cacheWidth(ctx, double.nan, SpotPhotoSize.full), 1280);
  });
}
