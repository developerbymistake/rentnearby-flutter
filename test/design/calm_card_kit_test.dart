import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/nearby/card_strings.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
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
      child: Scaffold(body: Center(child: child)),
    ),
  ));
}

BoxDecoration _deco(WidgetTester t, Finder of) =>
    t.widget<Container>(find.descendant(of: of, matching: find.byType(Container)).first).decoration! as BoxDecoration;

Text _text(WidgetTester t, String s) => t.widget<Text>(find.text(s));

void main() {
  const forest = ListingPalette.forest;
  const coral = ListingPalette.coral;

  for (final approved in [false, true]) {
    group(approved ? 'approved scale' : 'identity scale', () {
      setUp(() => approved ? DS.applyApproved() : DS.debugReset());
      tearDown(DS.debugReset);

      testWidgets('chip kinds use the palette tokens', (t) async {
        final cases = <CalmChipKind, (Color, Color)>{
          CalmChipKind.tag: (forest.g2.withValues(alpha: Alpha.tint), forest.g2),
          CalmChipKind.fact: (forest.g2.withValues(alpha: Alpha.tint), forest.text),
          CalmChipKind.solid: (forest.g2, DesignColors.onPrimary),
          CalmChipKind.muted: (DesignColors.chipBackground, DesignColors.textSecondary),
        };
        for (final e in cases.entries) {
          await _pump(t, CalmChip('Label', palette: forest, kind: e.key));
          final d = _deco(t, find.byType(CalmChip));
          expect(d.color, e.value.$1, reason: '${e.key}');
          expect(d.borderRadius, DS.br(CardRadius.chip));
          final s = _text(t, 'Label').style!;
          expect(s.color, e.value.$2, reason: '${e.key}');
          expect(s.fontWeight, FontWeight.w700);
          final spaced = e.key == CalmChipKind.tag || e.key == CalmChipKind.solid;
          expect(s.letterSpacing, spaced ? 0.4 : null);
          expect(t.widget<Container>(find.descendant(of: find.byType(CalmChip), matching: find.byType(Container)).first).padding, DS.sym(h: spaced ? 8 : 6, v: 3));
        }
        await _pump(t, const CalmChip('TAXI', palette: coral, kind: CalmChipKind.tag, fg: Color(0xFFB83A40)));
        expect(_text(t, 'TAXI').style!.color, coral.text);
        await _pump(t, CalmChip('Featured', palette: forest, kind: CalmChipKind.solid, leading: TravelIcon(TravelIcon.star, size: 13)));
        expect(find.byType(TravelIcon), findsOneWidget);
      });

      testWidgets('price block without offer: caption, value, unit; no strike, no tag', (t) async {
        await _pump(t, const CalmPriceBlock(palette: forest, caption: 'From', value: '₹1,200', unit: '/night'));
        expect(find.text('From'), findsOneWidget);
        expect(_text(t, '₹1,200').style!.color, forest.g2);
        expect(_text(t, '₹1,200').style!.fontWeight, FontWeight.w800);
        expect(_text(t, '/night').textAlign, TextAlign.right);
        expect(find.byType(CalmChip), findsNothing);
        expect(find.byWidgetPredicate((w) => w is Text && w.style?.decoration == TextDecoration.lineThrough), findsNothing);
        expect(t.getSize(find.byType(CalmPriceBlock)).width, greaterThanOrEqualTo(DS.s(84) + DS.s(12)));
        expect(t.takeException(), isNull);
      });

      testWidgets('price block with offer: struck old price beside the unit and the solid tag under it', (t) async {
        await _pump(t, const CalmPriceBlock(palette: ListingPalette.indigo, caption: 'From', value: '₹1,275', unit: '/night', was: '₹1,500', offTag: '15% off'));
        expect(_text(t, '₹1,500').style!.decoration, TextDecoration.lineThrough);
        expect(_text(t, '₹1,275').style!.color, ListingPalette.indigo.g2);
        final tag = find.widgetWithText(CalmChip, '15% off');
        expect(tag, findsOneWidget);
        expect(t.widget<CalmChip>(tag).kind, CalmChipKind.solid);
        expect(t.getTopLeft(tag).dy, greaterThan(t.getBottomLeft(find.text('₹1,500')).dy - 0.5));
        expect(t.getTopLeft(find.text('/night')).dy, closeTo(t.getTopLeft(find.text('₹1,500')).dy, 2));
        expect(t.takeException(), isNull);
      });

      testWidgets('price block with a text value uses the small style and the value colour override', (t) async {
        await _pump(t, CalmPriceBlock(palette: coral, value: CardStrings.askForFare, valueColor: coral.text, minWidth: 92, unitAlign: TextAlign.left));
        final s = _text(t, 'Ask for fare').style!;
        expect(s.fontWeight, FontWeight.w700);
        expect(s.color, coral.text);
        expect(find.byType(FittedBox), findsNothing);
        await _pump(t, CalmPriceBlock(palette: coral, value: '₹2,400', unit: 'to Nainital', valueColor: coral.text, unitAlign: TextAlign.left));
        expect(_text(t, 'to Nainital').textAlign, TextAlign.left);
        expect(find.byType(FittedBox), findsOneWidget);
      });

      testWidgets('button kinds: colours, leading and taps', (t) async {
        final taps = <String>[];
        Future<void> one(CalmAction a) => _pump(t, CalmPillButton(action: a, palette: forest));
        await one(CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () => taps.add('call'), itemKey: const ValueKey('c')));
        var d = _deco(t, find.byType(CalmPillButton));
        expect(d.color, forest.button);
        expect(_text(t, 'Call').style!.color, forest.text);
        expect(find.byIcon(Icons.call_rounded), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('c')));
        expect(taps, ['call']);

        await one(CalmAction(kind: CalmActionKind.whatsApp, label: 'WhatsApp', onTap: () => taps.add('wa')));
        d = _deco(t, find.byType(CalmPillButton));
        expect(d.gradient, forest.gradient);
        expect(d.boxShadow, isNotEmpty);
        expect(find.byType(WhatsAppGlyph), findsOneWidget);
        expect(_text(t, 'WhatsApp').style!.color, DesignColors.onPrimary);

        await one(CalmAction(kind: CalmActionKind.primary, label: 'Shortlisted', selected: true, onTap: () {}));
        expect(_deco(t, find.byType(CalmPillButton)).gradient, forest.gradient);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        await one(CalmAction(kind: CalmActionKind.primary, label: 'Shortlist', onTap: () {}));
        expect(_deco(t, find.byType(CalmPillButton)).color, forest.button);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);

        await one(CalmAction(kind: CalmActionKind.plain, label: 'Ask', icon: Icons.send_rounded, onTap: () {}));
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);
        expect(_deco(t, find.byType(CalmPillButton)).color, forest.button);

        await one(CalmAction(kind: CalmActionKind.plain, label: 'Enquiry', icon: Icons.mail_rounded, onTap: () {}, child: const Text('Sent')));
        expect(find.text('Sent'), findsOneWidget);
        expect(t.getTopLeft(find.text('Sent')).dx, greaterThan(t.getTopLeft(find.text('Enquiry')).dx));

        expect(t.getSize(find.byType(CalmPillButton)).height, greaterThanOrEqualTo(44 - 0.01));
        expect(t.takeException(), isNull);
      });

      testWidgets('disabled ignores taps and is grey; busy shows a spinner and ignores taps', (t) async {
        var n = 0;
        await _pump(t, CalmPillButton(action: CalmAction(kind: CalmActionKind.disabled, label: 'Full', onTap: () => n++), palette: forest));
        final d = _deco(t, find.byType(CalmPillButton));
        expect(d.color, DesignColors.chipBackground);
        expect(d.boxShadow, isNull);
        expect(_text(t, 'Full').style!.color, DesignColors.textDisabled);
        await t.tap(find.text('Full'));
        expect(n, 0);

        for (final kind in [CalmActionKind.call, CalmActionKind.whatsApp, CalmActionKind.primary]) {
          await _pump(t, CalmPillButton(action: CalmAction(kind: kind, label: 'Go', busy: true, onTap: () => n++), palette: forest));
          expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: '$kind');
          await t.tap(find.text('Go'));
          expect(n, 0);
        }
        final h = t.ensureSemantics();
        await _pump(t, CalmPillButton(action: CalmAction(kind: CalmActionKind.primary, label: 'Shortlisted', selected: true, onTap: () {}), palette: forest));
        expect(t.getSemantics(find.byType(CalmPillButton)), matchesSemantics(label: 'Shortlisted', isButton: true, hasEnabledState: true, isEnabled: true, hasSelectedState: true, isSelected: true, hasTapAction: true, isFocusable: false));
        h.dispose();
      });

      for (final width in [320.0, 360.0, 411.0]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('bottom row keeps the address on one line at $width x $scale', (t) async {
            final long = 'Kausani Ridge Road, Upper Bageshwar District';
            await _pump(
              t,
              SizedBox(
                width: width - 28,
                child: CalmBottomRow(
                  palette: forest,
                  address: long,
                  actions: [
                    CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () {}),
                    CalmAction(kind: CalmActionKind.whatsApp, label: 'WhatsApp', onTap: () {}),
                  ],
                ),
              ),
              scale: scale,
              width: width,
            );
            final txt = _text(t, long);
            expect(txt.maxLines, 1);
            expect(txt.softWrap, isFalse);
            expect(txt.overflow, TextOverflow.ellipsis);
            final lineHeight = t.getSize(find.text(long)).height;
            expect(lineHeight, lessThan(txt.style!.fontSize! * scale * 2));
            expect(find.byType(Art3D), findsOneWidget);
            expect(t.takeException(), isNull);
          });
        }
      }

      testWidgets('bottom row: no address keeps buttons on the right; empty row not built; note second line', (t) async {
        await _pump(t, SizedBox(width: 300, child: CalmBottomRow(palette: forest, actions: [CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () {})])));
        expect(find.byType(Art3D), findsNothing);
        expect(find.byType(Spacer), findsOneWidget);
        await _pump(t, const SizedBox(width: 300, child: CalmBottomRow(palette: forest, actions: [])));
        expect(find.byType(Row), findsNothing);
        await _pump(t, const SizedBox(width: 300, child: CalmBottomRow(palette: forest, address: '0.4 km away', note: 'Asked 2 h ago', actions: [])));
        expect(t.getTopLeft(find.text('Asked 2 h ago')).dy, greaterThan(t.getTopLeft(find.text('0.4 km away')).dy));
        expect(t.takeException(), isNull);
      });

      testWidgets('CalmCard.box is a white to tint gradient with the tight palette shadow', (t) async {
        final b = CalmCard.box(forest);
        expect((b.gradient! as LinearGradient).colors, [DesignColors.surface, forest.tint]);
        expect(b.borderRadius, DS.circular(16));
        expect(b.boxShadow, DS.shadows(ShadowTokens.tight(forest.shadow)));
        expect(CalmCard.box(coral, radius: DS.br(CardRadius.hero)).borderRadius, DS.br(CardRadius.hero));
        expect(CalmCard.stayAt(0), same(ListingPalette.forest));
        expect(CalmCard.stayAt(1), same(ListingPalette.indigo));
        expect(CalmCard.stayAt(2), same(ListingPalette.forest));
      });
    });
  }

  group('CardStrings', () {
    test('address text: In city, Place. About N km, or About N km', () {
      expect(CardStrings.addressFor(const NearbyDistance(km: 0.3, label: NearbyLabel.inCity, city: 'Kausani')), 'In Kausani');
      expect(CardStrings.addressFor(const NearbyDistance(km: 9, label: NearbyLabel.near, city: 'Bhimtal')), 'Bhimtal. About 9 km');
      expect(CardStrings.addressFor(const NearbyDistance(km: 63.2, label: NearbyLabel.far, city: 'Mukteshwar', state: 'Uttarakhand')), 'Mukteshwar. About 64 km');
      expect(CardStrings.addressFor(const NearbyDistance(km: 64, label: NearbyLabel.far)), 'About 64 km');
      expect(CardStrings.addressFor(const NearbyDistance(km: 2, label: NearbyLabel.inCity, city: ' ')), 'About 2 km');
      expect(CardStrings.percentOff(15), '15% off');
      expect(CardStrings.placeAbout('  Haldwani ', 5), 'Haldwani. About 5 km');
      for (final s in [CardStrings.placeAbout('Haldwani', 5), CardStrings.addressFor(const NearbyDistance(km: 210, label: NearbyLabel.far, city: 'Haridwar'))]) {
        expect(s, isNot(contains('away')));
      }
    });
  });
}
