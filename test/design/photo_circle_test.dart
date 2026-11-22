import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bakhli/design/design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget child, {double scale = 1.0, double width = 360}) async {
  t.view.devicePixelRatio = 3;
  t.view.physicalSize = Size(width * 3, 800 * 3);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery.withClampedTextScaling(
      minScaleFactor: scale,
      maxScaleFactor: scale,
      child: Scaffold(body: Padding(padding: const EdgeInsets.only(top: 80, left: 20), child: Align(alignment: Alignment.topLeft, child: child))),
    ),
  ));
}

Finder _art(String asset) => find.byWidgetPredicate((w) => w is Art3D && w.asset == asset);

void main() {
  for (final approved in [false, true]) {
    group(approved ? 'approved scale' : 'identity scale', () {
      setUp(() => approved ? DS.applyApproved() : DS.debugReset());
      tearDown(DS.debugReset);

      testWidgets('no usable url shows the 3D art, never a photo or ring', (t) async {
        for (final url in <String?>[null, '', 'abc', 'ftp://x/y.jpg', '   ']) {
          await _pump(t, PhotoCircle(url: url, art: ListingArt.taxi));
          expect(_art(ListingArt.taxi), findsOneWidget, reason: '$url');
          expect(find.byType(CachedNetworkImage), findsNothing, reason: '$url');
          expect(find.byKey(PhotoCircle.photoKey), findsNothing);
          expect(t.takeException(), isNull);
        }
        expect(PhotoCircle.hasPhoto(null), isFalse);
        expect(PhotoCircle.hasPhoto('abc'), isFalse);
        expect(PhotoCircle.hasPhoto('https://x/a.jpg'), isTrue);
        expect(PhotoCircle.hasPhoto('/uploads/a.jpg'), isTrue);
      });

      testWidgets('a /path url and an https url build the network photo with a sized decode', (t) async {
        for (final url in ['/uploads/a.jpg', 'https://res.cloudinary.com/a.jpg']) {
          await _pump(t, PhotoCircle(url: url, art: ListingArt.stay, size: 112, photoSize: 100, artSize: 110));
          final img = t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
          expect(img.imageUrl, endsWith('a.jpg'));
          expect(img.imageUrl, startsWith('https://'));
          expect(img.memCacheWidth, math.min(480, (DS.s(100) * 3).round()));
          expect(img.fadeInDuration, const Duration(milliseconds: 120));
          expect(t.takeException(), isNull);
        }
      });

      testWidgets('placeholder and error builder both build the art, the photo builder draws the white ring', (t) async {
        await _pump(t, const PhotoCircle(url: 'https://x.test/a.jpg', art: ListingArt.bus));
        final img = t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        final ctx = t.element(find.byType(CachedNetworkImage));
        for (final w in [img.placeholder!(ctx, 'u'), img.errorWidget!(ctx, 'u', Exception('x'))]) {
          await _pump(t, w);
          expect(_art(ListingArt.bus), findsOneWidget);
          expect(find.byType(ClipOval), findsNothing);
        }
        final ringed = img.imageBuilder!(ctx, MemoryImage(_png));
        await _pump(t, ringed);
        expect(find.byType(ClipOval), findsOneWidget);
        final ring = t.widget<Container>(find.ancestor(of: find.byType(ClipOval), matching: find.byType(Container)).first);
        expect((ring.decoration! as BoxDecoration).color, DesignColors.surface);
        expect(ring.padding, EdgeInsets.all(DS.s(3)));
        expect(_art(ListingArt.bus), findsNothing);
        expect(t.takeException(), isNull);
      });

      testWidgets('star key only with star: true; halo follows tone or white', (t) async {
        await _pump(t, PhotoCircle(url: null, art: ListingArt.taxi, star: true, tone: ListingTone.coral));
        expect(find.byKey(PhotoCircle.starKey), findsOneWidget);
        expect(find.byKey(const ValueKey('photo-circle-star')), findsOneWidget);
        final halo = t.widget<DecoratedBox>(find.descendant(of: find.byType(PhotoCircle), matching: find.byType(DecoratedBox)).first);
        expect((halo.decoration as BoxDecoration).color, ListingTone.coral.halo);
        await _pump(t, const PhotoCircle(url: null, art: ListingArt.taxi));
        expect(find.byKey(PhotoCircle.starKey), findsNothing);
        final white = t.widget<DecoratedBox>(find.descendant(of: find.byType(PhotoCircle), matching: find.byType(DecoratedBox)).first);
        expect((white.decoration as BoxDecoration).color, DesignColors.onPrimary.withValues(alpha: Alpha.v22));
        await _pump(t, const PhotoCircle(url: null, art: ListingArt.taxi, haloColor: DesignColors.surfaceTint));
        final own = t.widget<DecoratedBox>(find.descendant(of: find.byType(PhotoCircle), matching: find.byType(DecoratedBox)).first);
        expect((own.decoration as BoxDecoration).color, DesignColors.surfaceTint);
      });

      testWidgets('box size, default art size and placement follow the contract', (t) async {
        await _pump(t, const PhotoCircle(url: null, art: ListingArt.taxi));
        expect(t.getSize(find.byType(PhotoCircle)), Size.square(DS.s(136)));
        final box = t.getTopLeft(find.byType(PhotoCircle));
        final art = t.getTopLeft(_art(ListingArt.taxi));
        expect(t.getSize(_art(ListingArt.taxi)).width, closeTo(DS.s(136 * 0.88), 0.01));
        expect(art.dx - box.dx, closeTo(DS.s((136 - 136 * 0.88) / 2), 0.01));
        expect(art.dy - box.dy, closeTo(DS.s((136 - 136 * 0.88) / 2 + 136 * 0.03), 0.01));
      });

      testWidgets('taps pass through and semantics are excluded unless a label is given', (t) async {
        var taps = 0;
        await _pump(t, GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const PhotoCircle(url: null, art: ListingArt.taxi)));
        await t.tap(find.byType(PhotoCircle));
        expect(taps, 1);
        expect(find.descendant(of: find.byType(PhotoCircle), matching: find.byType(IgnorePointer)), findsWidgets);
        final h = t.ensureSemantics();
        await _pump(t, const PhotoCircle(url: null, art: ListingArt.taxi, semanticsLabel: 'Driver photo'));
        expect(find.bySemanticsLabel('Driver photo'), findsOneWidget);
        h.dispose();
      });

      for (final width in [320.0, 360.0, 411.0]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('every call-site renders without overflow at $width x $scale', (t) async {
            final rows = <Widget>[
              const PhotoCircle(url: null, art: ListingArt.taxi),
              PhotoCircle(url: 'https://x.test/a.jpg', art: ListingArt.taxi, size: 136, tone: ListingTone.coral, star: true),
              PhotoCircle(url: null, art: ListingArt.bus, size: 104, tone: ListingTone.coral, star: true, starSize: 104 * 0.32, starOffset: const Offset(104 * 0.71, -104 * 0.15)),
              const PhotoCircle(url: null, art: ListingArt.stay, size: 112, photoSize: 100, artSize: 110),
              const PhotoCircle(url: 'https://x.test/b.jpg', art: ListingArt.taxi, size: 172, photoSize: 148, artSize: 168),
              const PhotoCircle(url: null, art: ListingArt.taxi, size: 72, photoSize: 56, artSize: 56),
              const PhotoCircle(url: null, art: ListingArt.taxi, size: 60, artSize: 56, haloColor: DesignColors.surfaceTint),
            ];
            await _pump(t, SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [for (final r in rows) Padding(padding: const EdgeInsets.only(top: 24), child: r)])), scale: scale, width: width);
            expect(find.byType(PhotoCircle), findsNWidgets(rows.length));
            expect(t.takeException(), isNull);
          });
        }
      }
    });
  }
}

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00, 0xC9, 0xFE, 0x92, 0xEF, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
]);
