import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/trip_strings_spots_x.dart';
import 'package:bakhli/features/trip/utils/trip_spot_picks.dart';
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

const _desc = 'A calm lake in the middle of the town, ringed by green hills. Boating starts in the morning and the mall road runs along the north shore.';

TripSpotModel _spot({String id = 'naini', int photos = 1, bool featured = false, String name = 'Naini Lake', String category = 'lake', String? description = _desc}) => TripSpotModel(
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

final _shown = <String>[];

Future<void> _host(WidgetTester t, Widget child, {Size size = const Size(360, 800), double scale = 1.0}) =>
    pumpPhone(t, Scaffold(body: SingleChildScrollView(child: child)), size: size, devicePixelRatio: 2, textScale: scale);

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('spot_card').path,
    );
    await GetStorage.init();
    await TripSpotsCache.init();
  });

  setUp(() {
    _shown.clear();
    TripSpotMedia.debugImageBuilder = (url, fit, fallback) {
      _shown.add(url);
      return const ColoredBox(color: Color(0xFF88AACC));
    };
  });
  tearDown(() => TripSpotMedia.debugImageBuilder = null);

  group('card states', () {
    testWidgets('S1 one photo, featured: tag reads exactly Featured, no +N, category badge on the photo beside Featured', (t) async {
      await _host(t, TripSpotRow(spot: _spot(featured: true), selected: false, onToggle: () {}));
      expect(find.text(TripStringsSpotsX.featured), findsOneWidget);
      expect(find.textContaining('Featured ·'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
      expect(find.text('Mall Road'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(t.getTopLeft(find.text('LAKE')).dy, lessThan(t.getTopLeft(find.text('Naini Lake')).dy));
      expect(t.getBottomLeft(find.text('LAKE')).dy, lessThan(t.getTopLeft(find.byType(TripSpotCard)).dy + DS.s(28) + TripSpotCard.mediaHeight));
      expect((t.getCenter(find.text('LAKE')).dy - t.getCenter(find.text(TripStringsSpotsX.featured)).dy).abs(), lessThan(1));
      expect(t.getTopRight(find.text('LAKE')).dx, lessThan(t.getTopLeft(find.text(TripStringsSpotsX.featured)).dx));
      expect(find.text(TripStringsSpotsX.addToTrip), findsOneWidget);
      expect(find.text(TripSpotRow.details), findsOneWidget);
      expect(find.byType(TripSpotCard), findsOneWidget);
      expect(find.byType(WideCard), findsNothing);
      expect(_shown.single, contains('w_720,h_400'));
    });

    testWidgets('not featured: no tag', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      expect(find.text(TripStringsSpotsX.featured), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('pill tap calls onToggle', (t) async {
      var n = 0;
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () => n++));
      await t.tap(find.text(TripStringsSpotsX.addToTrip));
      await t.pump(const Duration(milliseconds: 300));
      expect(n, 1);
      expect(find.byType(TripSpotDetailSheet), findsNothing);
    });

    testWidgets('S2 three photos, selected: +2, Added with check, ring, tap removes', (t) async {
      var n = 0;
      final h = t.ensureSemantics();
      await _host(t, TripSpotRow(spot: _spot(photos: 3), selected: true, onToggle: () => n++));
      expect(find.text('+2'), findsOneWidget);
      expect(find.text(TripStringsSpotsX.addedToTrip), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text(TripStringsSpotsX.addToTrip), findsNothing);
      final ring = t.widget<Container>(find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is Container && w.foregroundDecoration != null)));
      final border = (ring.foregroundDecoration! as BoxDecoration).border! as Border;
      expect(border.top.color, ListingPalette.coral.text);
      expect(border.top.color, isNot(ListingTone.cA.g1));
      expect(border.top.color, isNot(ListingTone.cA.g2));
      expect(border.top.width, DS.s(2.5));
      final inner = t
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(TripSpotCard), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border is Border && (d.border! as Border).top.color == DesignColors.surface && d.borderRadius == DS.br(kMealsRadius));
      expect(inner.length, 1);
      expect((inner.single.border! as Border).top.width, DS.s(2));
      await t.tap(find.text(TripStringsSpotsX.addedToTrip));
      await t.pump(const Duration(milliseconds: 300));
      expect(n, 1);
      expect(t.getSemantics(find.bySemanticsLabel(TripStringsSpotsX.addedToTrip)), isSemantics(isSelected: true, isButton: true));
      h.dispose();
    });

    testWidgets('S3 no photo: art header, no +N, no sticker, featured tag', (t) async {
      await _host(t, TripSpotRow(spot: _spot(photos: 0, featured: true, name: 'Naina Devi Temple'), selected: false, onToggle: () {}));
      expect(_shown, isEmpty);
      expect(find.text(TripStringsSpotsX.featured), findsOneWidget);
      expect(find.byType(TripPhotoCount), findsNothing);
      final arts = t.widgetList<Art3D>(find.descendant(of: find.byType(TripSpotCard), matching: find.byType(Art3D))).toList();
      expect(arts.map((a) => a.size), [104]);
      final card = t.getTopLeft(find.byType(TripSpotCard));
      expect(t.getTopLeft(find.text('LAKE')).dx - card.dx, closeTo(DS.s(14) + DS.s(14) + DS.s(12), 0.5));
      expect(t.getTopLeft(find.text('Naina Devi Temple')).dx - card.dx, closeTo(DS.s(14) + DS.s(18), 0.5));
    });

    testWidgets('photo card: sticker 72, title indented past it and level with the 36 band under the photo', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      final arts = t.widgetList<Art3D>(find.descendant(of: find.byType(TripSpotCard), matching: find.byType(Art3D))).toList();
      expect(arts.map((a) => a.size), [72]);
      final card = t.getTopLeft(find.byType(TripSpotCard));
      final title = t.getRect(find.text('Naini Lake'));
      expect(title.left - card.dx, closeTo(DS.s(14) + DS.s(100), 0.5));
      final band = card.dy + DS.s(28) + TripSpotCard.mediaHeight;
      expect(title.center.dy, closeTo(band + DS.s(18), 0.5));
      final sticker = t.getRect(find.descendant(of: find.byType(TripSpotCard), matching: find.byType(Art3D)));
      expect(sticker.bottom, closeTo(band + DS.s(36), 0.5));
    });

    testWidgets('card colors cycle cA, cB, cC, cE by index like the city tiles, text white', (t) async {
      final tones = [ListingTone.cA, ListingTone.cB, ListingTone.cC, ListingTone.cE, ListingTone.cA];
      await _host(
        t,
        Column(children: [for (var i = 0; i < tones.length; i++) TripSpotRow(spot: _spot(id: 's$i', name: 'Spot $i'), selected: false, index: i, onToggle: () {})]),
        size: const Size(360, 2600),
      );
      final boxes = t
          .widgetList<Container>(find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).gradient != null)))
          .toList();
      expect(boxes.length, tones.length);
      for (var i = 0; i < tones.length; i++) {
        final deco = boxes[i].decoration! as BoxDecoration;
        expect((deco.gradient! as LinearGradient).colors, [tones[i].g1, tones[i].g2]);
        expect(TripSpotCard.toneOf(i).g1, tones[i].g1);
      }
      expect(t.widget<Text>(find.text('Spot 0')).style!.color, DesignColors.surface);
      final pill = t.widgetList<WhitePillButton>(find.byType(WhitePillButton)).toList();
      expect(pill[1].tone.g1, ListingTone.cB.g1);
      expect(pill[1].onGradient, isTrue);
      final inks = [ListingPalette.coral.text, ListingPalette.indigo.text, DesignColors.roseDeepStart, ListingTone.cE.text, ListingPalette.coral.text];
      final details = t.widgetList<Text>(find.text(TripSpotRow.details)).toList();
      for (var i = 0; i < tones.length; i++) {
        expect(TripSpotCard.inkOf(i), inks[i]);
        expect(pill[i].tone.button, inks[i]);
        expect(details[i].style!.color, inks[i]);
      }
    });

    testWidgets('no photo: art sits on the card gradient, no second gradient box under it', (t) async {
      await _host(t, TripSpotRow(spot: _spot(photos: 0), selected: false, index: 0, onToggle: () {}));
      final grads = t
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(TripSpotCard), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null)
          .toList();
      expect(grads.length, 1);
      expect((grads.single.gradient! as LinearGradient).colors, [ListingTone.cA.g1, ListingTone.cA.g2]);
    });

    testWidgets('bold text setting: description still ends in a whole more on line two', (t) async {
      await _host(
        t,
        Builder(builder: (c) => MediaQuery(data: MediaQuery.of(c).copyWith(boldText: true), child: TripSpotRow(spot: _spot(), selected: false, onToggle: () {}))),
      );
      final rich = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().endsWith('… ${TripStringsSpotsX.more}'));
      expect(rich, findsOneWidget);
      final para = t.renderObject<RenderParagraph>(rich);
      expect(para.didExceedMaxLines, isFalse);
      final plain = para.text.toPlainText();
      final n = TripStringsSpotsX.more.length;
      final boxes = para.getBoxesForSelection(TextSelection(baseOffset: plain.length - n, extentOffset: plain.length));
      final line = para.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first.toRect();
      expect(boxes.length, 1);
      expect(boxes.single.toRect().top, greaterThan(line.bottom - 1));
    });

    testWidgets('long description: two lines ending in a bold more that opens the place page', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      final rich = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().endsWith('… ${TripStringsSpotsX.more}'));
      expect(rich, findsOneWidget);
      final para = t.renderObject<RenderParagraph>(rich);
      expect(para.didExceedMaxLines, isFalse);
      final plain = para.text.toPlainText();
      expect(_desc.startsWith(plain.substring(0, plain.length - '… ${TripStringsSpotsX.more}'.length)), isTrue);
      final n = TripStringsSpotsX.more.length;
      final box = para.getBoxesForSelection(TextSelection(baseOffset: plain.length - n, extentOffset: plain.length)).first.toRect();
      final line = para.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first.toRect();
      expect(box.top, greaterThan(line.bottom - 1));
      await t.tapAt(para.localToGlobal(box.center));
      await _settle(t);
      expect(find.byType(TripSpotDetailSheet), findsOneWidget);
    });

    testWidgets('short description: plain text, no more', (t) async {
      await _host(t, TripSpotRow(spot: _spot(description: 'A calm lake.'), selected: false, onToggle: () {}));
      expect(find.text('A calm lake.'), findsOneWidget);
      expect(find.textContaining(TripStringsSpotsX.more, findRichText: true), findsNothing);
    });

    testWidgets('S4 locked: faded 0.6, pill still calls onToggle, Details still opens', (t) async {
      var n = 0;
      await _host(t, TripSpotRow(spot: _spot(), selected: false, locked: true, onToggle: () => n++));
      final o = t.widget<Opacity>(find.descendant(of: find.byType(TripSpotCard), matching: find.byType(Opacity)).first);
      expect(o.opacity, Alpha.v60);
      await t.tap(find.text(TripStringsSpotsX.addToTrip));
      await t.pump(const Duration(milliseconds: 300));
      expect(n, 1);
      await t.tap(find.text(TripSpotRow.details));
      await _settle(t);
      expect(find.byType(TripSpotDetailSheet), findsOneWidget);
    });

    testWidgets('selected and locked: not faded', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: true, locked: true, onToggle: () {}));
      expect(find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == Alpha.v60)), findsNothing);
    });

    testWidgets('existing id without toggle: soft Added, not tappable, no fade', (t) async {
      final h = t.ensureSemantics();
      await _host(t, TripSpotRow(spot: _spot(), selected: true));
      expect(find.text(TripStringsSpotsX.addedToTrip), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel(TripStringsSpotsX.addedToTrip)), isSemantics(isEnabled: false));
      h.dispose();
      await t.tap(find.text(TripStringsSpotsX.addedToTrip));
      await _settle(t);
      expect(find.byType(TripSpotDetailSheet), findsNothing);
    });

    testWidgets('empty description: no subtitle block', (t) async {
      await _host(t, TripSpotRow(spot: _spot(description: null), selected: false, onToggle: () {}));
      expect(find.text(_desc), findsNothing);
      final texts = t.widgetList<Text>(find.descendant(of: find.byType(TripSpotCard), matching: find.byType(Text))).map((e) => e.data).toList();
      expect(texts.contains(''), isFalse);
    });

    testWidgets('Details and card tap open the place page', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      await t.tap(find.text(TripSpotRow.details));
      await _settle(t);
      expect(find.byType(TripSpotDetailSheet), findsOneWidget);
      Navigator.of(t.element(find.byType(TripSpotDetailSheet))).pop();
      await _settle(t);
      expect(find.byType(TripSpotDetailSheet), findsNothing);
      await t.tap(find.text('Naini Lake'));
      await _settle(t);
      expect(find.byType(TripSpotDetailSheet), findsOneWidget);
    });

    testWidgets('Details and pill tap areas are at least 44 high', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      final details = find.ancestor(of: find.text(TripSpotRow.details), matching: find.byType(ConstrainedBox)).first;
      expect(t.getSize(details).height, greaterThanOrEqualTo(DS.s(KitMetrics.touch)));
      final pill = find.ancestor(of: find.byType(WhitePillButton), matching: find.byType(ConstrainedBox)).first;
      expect(t.getSize(pill).height, greaterThanOrEqualTo(DS.s(KitMetrics.touch)));
      expect(t.getSize(find.byType(WhitePillButton)).height, DS.s(KitMetrics.touch));
    });

    testWidgets('Proposal B: photo 180, Details outline pill 44, 16 below the pill, 16 gap after the card', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      final media = find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == TripSpotCard.mediaHeight));
      expect(media, findsOneWidget);
      expect(TripSpotCard.mediaHeight, DS.s(180));
      final details = find.ancestor(of: find.text(TripSpotRow.details), matching: find.byType(Container)).first;
      expect(t.getSize(details).height, DS.s(KitMetrics.touch));
      final deco = t.widget<Container>(details).decoration! as BoxDecoration;
      expect(deco.border, isNotNull);
      final pill = t.getRect(find.byType(WhitePillButton));
      final box = t.getRect(find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).boxShadow != null)).first);
      expect(box.bottom - pill.bottom, closeTo(DS.s(16), 0.5));
      final card = t.getRect(find.byType(TripSpotCard));
      expect(card.bottom - box.bottom, closeTo(DS.gv(16), 0.5));
    });

    testWidgets('Added soft pill is 44 high', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: true, onToggle: () {}));
      final soft = find.ancestor(of: find.text(TripStringsSpotsX.addedToTrip), matching: find.byType(SizedBox)).first;
      expect(t.getSize(soft).height, DS.s(KitMetrics.touch));
    });

    testWidgets('semantics: Details button and Add to trip button', (t) async {
      final h = t.ensureSemantics();
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      expect(find.bySemanticsLabel(TripSpotRow.details), findsOneWidget);
      expect(find.bySemanticsLabel(TripStringsSpotsX.addToTrip), findsOneWidget);
      h.dispose();
    });
  });

  group('draft', () {
    testWidgets('unselected: circle toggle, no add to trip label, tap calls onToggle', (t) async {
      var n = 0;
      await _host(t, TripSpotRow(spot: _spot(), selected: false, draft: true, subtitle: 'Lake · 1 h 30 min', onToggle: () => n++));
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(t.widget<Icon>(find.byIcon(Icons.circle_outlined)).color, TripSpotCard.inkOf(0));
      final dot = t.widget<DecoratedBox>(find.ancestor(of: find.byIcon(Icons.circle_outlined), matching: find.byType(DecoratedBox)).first);
      expect((dot.decoration as BoxDecoration).color, DesignColors.surface);
      expect(find.text(TripStringsSpotsX.addToTrip), findsNothing);
      expect(find.text('Lake · 1 h 30 min'), findsOneWidget);
      await t.tap(find.byIcon(Icons.circle_outlined));
      await t.pump(const Duration(milliseconds: 300));
      expect(n, 1);
      expect(find.byType(TripSpotDetailSheet), findsNothing);
    });

    testWidgets('selected: check circle and ring', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: true, draft: true, onToggle: () {}));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(t.widget<Icon>(find.byIcon(Icons.check_rounded)).color, DesignColors.surface);
      final dot = t.widget<DecoratedBox>(find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(DecoratedBox)).first);
      expect((dot.decoration as BoxDecoration).color, TripSpotCard.inkOf(0));
      expect(((dot.decoration as BoxDecoration).border! as Border).top.color, DesignColors.surface);
      expect(find.text(TripStringsSpotsX.addedToTrip), findsNothing);
      expect(find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is Container && w.foregroundDecoration != null)), findsOneWidget);
    });

    testWidgets('dimmed existing: Added, faded, tap does nothing', (t) async {
      var n = 0;
      await _host(t, TripSpotRow(spot: _spot(), selected: true, draft: true, dimmed: true, onToggle: () => n++));
      expect(find.text(TripStringsSpotsX.addedToTrip), findsOneWidget);
      expect(find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == Alpha.v60)), findsOneWidget);
      await t.tap(find.text(TripStringsSpotsX.addedToTrip));
      await _settle(t);
      expect(n, 0);
      expect(find.byType(TripSpotDetailSheet), findsNothing);
    });
  });

  group('sizes', () {
    for (final w in [320.0, 360.0, 411.0]) {
      for (final s in [1.0, 1.3]) {
        testWidgets('no exception at $w x $s with a 2-line title', (t) async {
          await _host(
            t,
            Column(children: [
              TripSpotRow(spot: _spot(featured: true, photos: 3, name: 'Naina Devi Temple and the old mall road jetty'), selected: false, onToggle: () {}),
              TripSpotRow(spot: _spot(id: 'b', photos: 0, name: 'Snow View Point and Cable Car'), selected: true, onToggle: () {}),
              TripSpotRow(spot: _spot(id: 'c'), selected: false, draft: true, onToggle: () {}),
            ]),
            size: Size(w, 1600),
            scale: s,
          );
          expect(t.takeException(), isNull);
          expect(find.text(TripStringsSpotsX.addToTrip), findsOneWidget);
          expect(t.getSize(find.byType(WhitePillButton)).height, DS.s(KitMetrics.touch));
          final pill = t.getRect(find.byType(WhitePillButton));
          final card = t.getRect(find.byType(TripSpotCard).first);
          expect(pill.right, lessThanOrEqualTo(card.right - DS.s(14) - DS.s(18) + 0.5));
        });
      }
    }

    testWidgets('1.3 at 320: pill wraps under Details on the right, never shrinks', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}), size: const Size(320, 900), scale: 1.3);
      final details = t.getRect(find.text(TripSpotRow.details));
      final pill = t.getRect(find.byType(WhitePillButton));
      if (DS.size == 1.0) expect(pill.top, greaterThan(details.bottom));
      final card = t.getRect(find.byType(TripSpotCard));
      expect(pill.right, closeTo(card.right - DS.s(14) - DS.s(18), 0.5));
      final fitted = t.widget<FittedBox>(find.descendant(of: find.byType(WhitePillButton), matching: find.byType(FittedBox)));
      expect(fitted.fit, BoxFit.scaleDown);
      final row = find.descendant(of: find.byType(FittedBox), matching: find.byType(Row)).first;
      expect(t.getSize(row).width, lessThanOrEqualTo(t.getSize(find.byType(FittedBox)).width + 0.5));
    });

    testWidgets('1.0 at 360: Details and pill share one line', (t) async {
      await _host(t, TripSpotRow(spot: _spot(), selected: false, onToggle: () {}));
      final details = t.getRect(find.text(TripSpotRow.details));
      final pill = t.getRect(find.byType(WhitePillButton));
      expect((details.center.dy - pill.center.dy).abs(), lessThan(1));
    });
  });

  group('skeleton', () {
    testWidgets('media 180 placeholder and 44 pill placeholder', (t) async {
      await _host(t, const TripSpotCardSkeleton());
      final ph = t.widgetList<TemplatePlaceholder>(find.byType(TemplatePlaceholder)).toList();
      expect(ph.first.height, DS.s(180));
      expect(ph.last.height, DS.s(KitMetrics.touch));
      expect(t.takeException(), isNull);
    });
  });

  group('suggestion', () {
    TripSuggestionCard sug({TripSpotModel? spot, String away = '20 min away', String? label, VoidCallback? onAdd, VoidCallback? onDismiss}) => TripSuggestionCard(
          spot: spot ?? _spot(id: 'mall', name: 'Mall Road Ridge'),
          away: away,
          semanticsLabel: label,
          onAdd: onAdd ?? () {},
          onDismiss: onDismiss ?? () {},
        );

    testWidgets('photo thumbnail, name and minutes, Add and dismiss callbacks', (t) async {
      var add = 0, dismiss = 0;
      await _host(t, sug(onAdd: () => add++, onDismiss: () => dismiss++));
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('Mall Road Ridge'), findsOneWidget);
      expect(find.text('20 min away'), findsOneWidget);
      expect(_shown.single, contains('w_320,h_320'));
      expect(find.byType(Art3D), findsNothing);
      await t.tap(find.text(TripStringsSpotsX.add));
      await t.tap(find.byTooltip(TripStringsSpotsX.dismiss));
      await t.pump(const Duration(milliseconds: 300));
      expect(add, 1);
      expect(dismiss, 1);
    });

    testWidgets('no photo: category art tile and km text', (t) async {
      await _host(t, sug(spot: _spot(id: 'temple', name: 'Naina Devi Temple', photos: 0, category: 'temple'), away: 'about 1 km away'));
      await t.pump(const Duration(milliseconds: 800));
      expect(_shown, isEmpty);
      final art = t.widget<Art3D>(find.byType(Art3D));
      expect(art.size, 44);
      expect(art.asset, TripSpotLook.assetOf('temple'));
      expect(find.text('about 1 km away'), findsOneWidget);
    });

    testWidgets('mock S5: thumb 54 r14, name and distance roles, Add tap area 44, card radius 20', (t) async {
      await _host(t, sug());
      await t.pump(const Duration(milliseconds: 800));
      final thumb = find.descendant(of: find.byType(TripSuggestionCard), matching: find.byType(ClipRRect)).first;
      expect(t.getSize(thumb), Size(DS.s(54), DS.s(54)));
      expect(t.widget<ClipRRect>(thumb).borderRadius, DS.circular(14));
      final name = t.widget<Text>(find.text('Mall Road Ridge'));
      expect(name.style!.fontSize, DS.f(13));
      expect(name.style!.fontWeight, FontWeight.w600);
      final away = t.widget<Text>(find.text('20 min away'));
      expect(away.style!.fontSize, DS.f(12.5));
      expect(t.getSize(find.byType(GradientPillButton)).height, DS.s(34));
      final hit = find.ancestor(of: find.byType(GradientPillButton), matching: find.byType(ConstrainedBox)).first;
      expect(t.getSize(hit).height, greaterThanOrEqualTo(DS.s(KitMetrics.touch)));
      final box = t.widget<DecoratedBox>(find.descendant(of: find.byType(TripSuggestionCard), matching: find.byType(DecoratedBox)).first);
      expect((box.decoration as BoxDecoration).borderRadius, DS.circular(20));
    });

    testWidgets('sits right under the added card: gap 20 like the mock', (t) async {
      await _host(t, Column(children: [TripSpotRow(spot: _spot(photos: 3), selected: true, onToggle: () {}), sug()]));
      await t.pump(const Duration(milliseconds: 800));
      final card = t.getRect(find.descendant(of: find.byType(TripSpotCard), matching: find.byWidgetPredicate((w) => w is Container && w.foregroundDecoration != null)).first);
      final box = t.getRect(find.descendant(of: find.byType(TripSuggestionCard), matching: find.byType(DecoratedBox)).first);
      expect(box.top - card.bottom, closeTo(DS.gv(16) + DS.gv(4), 0.5));
    });

    testWidgets('dismiss target is at least 44 dp', (t) async {
      await _host(t, sug());
      await t.pump(const Duration(milliseconds: 800));
      final size = t.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(DS.s(44)));
      expect(size.height, greaterThanOrEqualTo(DS.s(44)));
    });

    testWidgets('semantics label is the nearbyText sentence', (t) async {
      final h = t.ensureSemantics();
      final added = _spot(id: 'snow', name: 'Snow View Point');
      final near = _spot(id: 'mall', name: 'Mall Road Ridge');
      final n = TripNearby(near, 20, 3);
      await _host(t, sug(spot: near, away: TripSpotPicks.awayText(n), label: TripSpotPicks.nearbyText(added, n)));
      await t.pump(const Duration(milliseconds: 800));
      expect(find.bySemanticsLabel('Mall Road Ridge is 20 min from Snow View Point. Add it?'), findsOneWidget);
      h.dispose();
    });

    for (final w in [320.0, 360.0, 411.0]) {
      for (final s in [1.0, 1.3]) {
        testWidgets('no exception at $w x $s, sides match the card', (t) async {
          await _host(
            t,
            Column(children: [
              TripSpotRow(spot: _spot(photos: 3), selected: true, onToggle: () {}),
              sug(spot: _spot(id: 'mall', name: 'Mall Road Ridge and the old cable car station')),
            ]),
            size: Size(w, 1000),
            scale: s,
          );
          await t.pump(const Duration(milliseconds: 800));
          expect(t.takeException(), isNull);
          expect(t.getSize(find.byType(IconButton)).height, greaterThanOrEqualTo(DS.s(44)));
          final box = t.getRect(find.descendant(of: find.byType(TripSuggestionCard), matching: find.byType(DecoratedBox)).first);
          expect(box.left, closeTo(DS.s(14), 0.5));
          expect(box.right, closeTo(w - DS.s(14), 0.5));
        });
      }
    }
  });
}
