import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/trip_strings_spots_x.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_card.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_detail_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:bakhli/features/trip/widgets/trip_spots_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/real_phone.dart';

TripSpotModel _spot({String id = 'naini', int photos = 1, bool featured = false, String name = 'Naini Lake', String category = 'lake', String? description = 'A calm lake in the middle of the town, ringed by green hills.'}) => TripSpotModel(
      id: id,
      source: 'osm',
      name: name,
      description: description,
      latitude: 29.38,
      longitude: 79.45,
      category: category,
      area: 'Mall Road',
      visitMinutes: 90,
      isFeatured: featured,
      images: [for (var i = 0; i < photos; i++) 'https://res.cloudinary.com/demo/image/upload/v1/$id$i.jpg'],
    );

Future<void> _host(WidgetTester t, Widget child, {Size size = const Size(360, 800), double scale = 1.0}) =>
    pumpPhone(t, Scaffold(body: SingleChildScrollView(child: child)), size: size, devicePixelRatio: 2, textScale: scale);

bool _cut(WidgetTester t, Finder f) => t.renderObject<RenderParagraph>(f).didExceedMaxLines;

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('spot_card_review').path,
    );
    await GetStorage.init();
    await TripSpotsCache.init();
  });

  setUp(() => TripSpotMedia.debugImageBuilder = (url, fit, fallback) => const ColoredBox(color: Color(0xFF88AACC)));
  tearDown(() => TripSpotMedia.debugImageBuilder = null);

  group('suggestion distance is never cut', () {
    for (final w in [320.0, 360.0]) {
      for (final away in ['20 min away', '1 h 10 min away', 'about 12 km away']) {
        testWidgets('$away at $w x 1.3', (t) async {
          await _host(
            t,
            TripSuggestionCard(spot: _spot(id: 'mall', name: 'Mall Road Ridge'), away: away, onAdd: () {}, onDismiss: () {}),
            size: Size(w, 800),
            scale: 1.3,
          );
          await t.pump(const Duration(milliseconds: 800));
          expect(t.takeException(), isNull);
          expect(_cut(t, find.text(away)), isFalse);
          final fitted = find.descendant(of: find.byType(GradientPillButton), matching: find.byType(FittedBox));
          final row = find.descendant(of: fitted, matching: find.byType(Row)).first;
          expect(t.getSize(row).width, lessThanOrEqualTo(t.getSize(fitted).width + 0.5));
        });
      }
    }
  });

  group('action row sweep', () {
    for (final w in [320.0, 330.0, 340.0, 350.0, 360.0, 375.0, 393.0, 411.0]) {
      for (final s in [1.0, 1.1, 1.15, 1.2, 1.25, 1.3]) {
        testWidgets('$w x $s: no overflow, pill label at full size, Details clear of the pill', (t) async {
          await _host(
            t,
            Column(children: [
              TripSpotRow(spot: _spot(), selected: false, onToggle: () {}),
              TripSpotRow(spot: _spot(id: 'b'), selected: true, onToggle: () {}),
              TripSpotRow(spot: _spot(id: 'c'), selected: false, draft: true, onToggle: () {}),
            ]),
            size: Size(w, 1800),
            scale: s,
          );
          expect(t.takeException(), isNull);
          final fitted = find.descendant(of: find.byType(GradientPillButton), matching: find.byType(FittedBox));
          final row = find.descendant(of: fitted, matching: find.byType(Row)).first;
          expect(t.getSize(row).width, lessThanOrEqualTo(t.getSize(fitted).width + 0.5));
          final details = t.getRect(find.text(TripSpotRow.details).first);
          final pill = t.getRect(find.byType(GradientPillButton));
          if (pill.top < details.bottom) expect(details.right, lessThan(pill.left));
          final added = t.getRect(find.text(TripStringsSpotsX.addedToTrip));
          final cardB = t.getRect(find.byType(TripSpotCard).at(1));
          expect(added.right, lessThanOrEqualTo(cardB.right - DS.s(14) - DS.s(16)));
          for (final e in find.text(TripSpotRow.details).evaluate()) {
            expect((e.renderObject! as RenderParagraph).didExceedMaxLines, isFalse);
          }
        });
      }
    }
  });

  group('media overlays', () {
    for (final w in [320.0, 360.0]) {
      testWidgets('Featured tag and +N do not touch at $w x 1.3', (t) async {
        await _host(t, TripSpotRow(spot: _spot(featured: true, photos: 3), selected: false, onToggle: () {}), size: Size(w, 900), scale: 1.3);
        expect(t.takeException(), isNull);
        final tag = find.text(TripStringsSpotsX.featured);
        expect(_cut(t, tag), isFalse);
        final count = t.getRect(find.byType(TripPhotoCount));
        expect(t.getRect(tag).right, lessThan(count.left));
        final card = t.getRect(find.byType(TripSpotCard));
        expect(count.top - card.top, closeTo(DS.s(28) + DS.s(12), 0.5));
        expect(t.getRect(tag).left, greaterThan(card.left + DS.s(14)));
      });
    }

    testWidgets('no photo and not featured: nothing on the header, no +N', (t) async {
      await _host(t, TripSpotRow(spot: _spot(photos: 0), selected: false, onToggle: () {}));
      expect(find.text(TripStringsSpotsX.featured), findsNothing);
      expect(find.byType(TripPhotoCount), findsNothing);
    });
  });

  group('odd data', () {
    testWidgets('one long word title and unknown category at 320 x 1.3', (t) async {
      await _host(
        t,
        Column(children: [
          TripSpotRow(spot: _spot(name: 'Kanchenjunga-Sunrise-Viewpoint', category: 'something_new'), selected: false, onToggle: () {}),
          TripSpotRow(spot: _spot(id: 'b', photos: 0, name: 'Kanchenjunga-Sunrise-Viewpoint', category: '', description: null), selected: true, onToggle: () {}),
        ]),
        size: const Size(320, 1400),
        scale: 1.3,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('draft toggle and add to trip pill never open the place page', (t) async {
      var n = 0;
      await _host(
        t,
        Column(children: [
          TripSpotRow(spot: _spot(), selected: false, draft: true, onToggle: () => n++),
          TripSpotRow(spot: _spot(id: 'b'), selected: false, locked: true, onToggle: () => n++),
        ]),
        size: const Size(360, 1200),
      );
      await t.tap(find.byIcon(Icons.circle_outlined));
      await t.tap(find.text(TripStringsSpotsX.addToTrip));
      await t.pump(const Duration(milliseconds: 400));
      expect(n, 2);
      expect(find.byType(TripSpotDetailSheet), findsNothing);
    });
  });
}
