import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_ids.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// APP-5 (D5): trip markers follow DS like the rest of the trip map; stay markers stay raw (mock at real sizes).
void main() {
  final restore = (size: DS.size, font: DS.font, gap: DS.gapRel, floor: DS.fontFloor);
  tearDown(() => DS.debugSet(size: restore.size, font: restore.font, gapRel: restore.gap, fontFloor: restore.floor));

  test('approved scale: trip 35.2 / 19.2 / 7.2 / 11.2 / halos 57.6 and 28.8, tap box 44; stay unchanged', () {
    DS.applyApproved();
    final t = DiscTuning.trip;
    expect(t.photoDp, closeTo(35.2, 1e-9));
    expect(t.badgeDp, closeTo(19.2, 1e-9));
    expect(t.dotDp, closeTo(7.2, 1e-9));
    expect(t.selDotDp, closeTo(11.2, 1e-9));
    expect(t.haloPhotoDp, closeTo(57.6, 1e-9));
    expect(t.haloDotDp, closeTo(28.8, 1e-9));
    expect(t.hitDp, 44);
    expect(t.photoMax, 40);
    final s = DiscTuning.stay;
    expect((s.photoDp, s.badgeDp, s.dotDp, s.hitDp), (32, 24, 9, 44));
  });

  test('identity scale: trip = the mock numbers (44 / 24 / 9)', () {
    DS.debugReset();
    final t = DiscTuning.trip;
    expect((t.photoDp, t.badgeDp, t.dotDp, t.selDotDp, t.haloPhotoDp, t.haloDotDp), (44, 24, 9, 14, 72, 36));
  });

  test('the photo marker disk cache key follows the marker size, so old PNGs of another size are not reused', () {
    DS.debugReset();
    final raw = TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.trip);
    DS.applyApproved();
    final scaled = TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.trip);
    expect(scaled, isNot(raw));
    expect(scaled, startsWith('w_12_35_'));
  });

  testWidgets('compose: the trip photo marker canvas follows px(photoDp) under the approved scale', (tester) async {
    DS.applyApproved();
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 96, 96), Paint()..color = const Color(0xFF3366CC));
      final img = await recorder.endRecording().toImage(96, 96);
      final thumb = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final t = DiscTuning.trip;
      final png = (await const CanvasMarkerPainter().photo(Uint8List.fromList(thumb), t))!;
      final codec = await ui.instantiateImageCodec(png);
      final out = (await codec.getNextFrame()).image;
      expect(out.width, t.px(CanvasMarkerPainter.canvasDp(t.photoDp)));
    });
  });
}
