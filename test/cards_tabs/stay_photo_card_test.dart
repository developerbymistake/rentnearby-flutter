import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_photo_card.dart';
import 'package:bakhli/features/nearby/card_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

const _sizes = [320.0, 360.0, 411.0];
const _scales = [1.0, 1.3];

StayPhotoCard _card({
  int index = 0,
  String? url,
  bool featured = false,
  String price = '₹1,500',
  String? caption = CardStrings.from,
  String unit = CardStrings.perNight,
  String? was,
  String? offTag,
  String place = 'Kausani, Nainital',
  String? address = 'In Kausani',
  List<String> chips = const ['Homestay', 'Breakfast', 'Deluxe room', 'Parking'],
  String? leadChip,
  List<CalmAction> actions = const [],
  VoidCallback? onTap,
}) =>
    StayPhotoCard(
      palette: CalmCard.stayAt(index),
      title: 'Deodar Cottage',
      place: place,
      photoUrl: url,
      featured: featured,
      chips: chips,
      leadChip: leadChip,
      price: price,
      caption: caption,
      unit: unit,
      was: was,
      offTag: offTag,
      address: address,
      actions: actions,
      onTap: onTap,
    );

Future<void> _pump(WidgetTester t, Widget card, {double width = 360, double scale = 1.0}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(
    t,
    Scaffold(body: SingleChildScrollView(child: card)),
    size: Size(width, 900),
    textScale: scale,
  );
}

void _sized(String name, Future<void> Function(WidgetTester t, double width, double scale) body) {
  for (final w in _sizes) {
    for (final s in _scales) {
      testWidgets('$name at ${w.toInt()} @$s', (t) async {
        await body(t, w, s);
        expect(t.takeException(), isNull);
      });
    }
  }
}

void main() {
  _sized('photo url shows the photo, no tent art', (t, w, s) async {
    await _pump(t, _card(url: 'https://example.com/a.jpg'), width: w, scale: s);
    expect(find.byType(KitPhoto), findsOneWidget);
    expect(find.byKey(StayPhotoCard.bannerArtKey), findsNothing);
  });

  _sized('null, empty or bad url shows the tent art', (t, w, s) async {
    for (final url in [null, '', 'abc']) {
      await _pump(t, _card(url: url), width: w, scale: s);
      expect(find.byType(KitPhoto), findsNothing, reason: '$url');
      expect(find.byKey(StayPhotoCard.bannerArtKey), findsOneWidget, reason: '$url');
      expect(t.widgetList<Art3D>(find.byType(Art3D)).where((a) => a.asset == ListingArt.stay), isNotEmpty, reason: '$url');
      expect(t.takeException(), isNull);
    }
  });

  _sized('featured pill only when featured', (t, w, s) async {
    await _pump(t, _card(featured: true), width: w, scale: s);
    expect(find.byKey(StayPhotoCard.featuredKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(StayPhotoCard.featuredKey), matching: find.text('Featured')), findsOneWidget);
    expect(t.widget<Container>(find.byKey(StayPhotoCard.featuredKey)).decoration, isA<BoxDecoration>().having((d) => d.color, 'color', ListingPalette.forest.g2));
    await _pump(t, _card(), width: w, scale: s);
    expect(find.byKey(StayPhotoCard.featuredKey), findsNothing);
  });

  _sized('offer: bold new price, struck old price, tag under the price block', (t, w, s) async {
    await _pump(t, _card(price: '₹1,275', was: '₹1,500', offTag: '15% off'), width: w, scale: s);
    final value = t.widget<Text>(find.text('₹1,275'));
    expect(value.style?.fontWeight, FontWeight.w800);
    expect(t.widget<Text>(find.text('₹1,500')).style?.decoration, TextDecoration.lineThrough);
    expect(find.text('15% off'), findsOneWidget);
    expect(find.descendant(of: find.byType(CalmPriceBlock), matching: find.text('15% off')), findsOneWidget);
    expect(find.descendant(of: find.byType(Wrap), matching: find.text('15% off')), findsNothing);
  });

  testWidgets('chip only: base price not struck, tag still under the block', (t) async {
    await _pump(t, _card(offTag: '15% off'));
    expect(t.widget<Text>(find.text('₹1,500')).style?.decoration, isNot(TextDecoration.lineThrough));
    expect(find.descendant(of: find.byType(CalmPriceBlock), matching: find.text('15% off')), findsOneWidget);
  });

  testWidgets('On request: no From, no /night', (t) async {
    await _pump(t, _card(price: CardStrings.onRequest, caption: null, unit: ''));
    expect(find.text('On request'), findsOneWidget);
    expect(find.text('From'), findsNothing);
    expect(find.text('/night'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('address stays one line at 320 x 1.3 with a 40 character place', (t) async {
    const long = 'Mukteshwar Dhari Ramgarh Road Kumaon Hill';
    final address = CardStrings.placeAbout(long, 64);
    await _pump(
      t,
      _card(address: address, actions: [CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () {}), CalmAction(kind: CalmActionKind.whatsApp, label: 'WhatsApp', onTap: () {})]),
      width: 320,
      scale: 1.3,
    );
    final text = t.widget<Text>(find.text(address));
    expect(text.maxLines, 1);
    final lineHeight = t.getSize(find.text('Call')).height;
    expect(t.getSize(find.text(address)).height, lessThanOrEqualTo(lineHeight + 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('chips: at most 3, no image inside a chip, lead chip first', (t) async {
    await _pump(t, _card(leadChip: 'Full on your dates'));
    expect(find.byType(CalmChip).evaluate().where((e) => (e.widget as CalmChip).kind != CalmChipKind.tag).length, 4);
    expect(find.text('Parking'), findsNothing);
    expect(find.descendant(of: find.byType(CalmChip), matching: find.byType(Image)), findsNothing);
    expect(find.descendant(of: find.byType(CalmChip), matching: find.byType(Art3D)), findsNothing);
    final lead = t.getTopLeft(find.text('Full on your dates'));
    final first = t.getTopLeft(find.text('Homestay'));
    expect(lead.dx, lessThan(first.dx));
    expect(t.widget<CalmChip>(find.ancestor(of: find.text('Full on your dates'), matching: find.byType(CalmChip))).kind, CalmChipKind.muted);
  });

  testWidgets('even index forest, odd index indigo', (t) async {
    await _pump(t, _card(index: 0));
    expect(t.widget<Text>(find.text('₹1,500')).style?.color, ListingPalette.forest.g2);
    await _pump(t, _card(index: 1));
    expect(t.widget<Text>(find.text('₹1,500')).style?.color, ListingPalette.indigo.g2);
    await _pump(t, _card(index: 2));
    expect(t.widget<Text>(find.text('₹1,500')).style?.color, ListingPalette.forest.g2);
  });

  testWidgets('card tap, Call tap and busy Call', (t) async {
    var cardTaps = 0;
    var calls = 0;
    await _pump(t, _card(onTap: () => cardTaps++, actions: [CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () => calls++)]));
    await t.tap(find.text('Deodar Cottage'));
    await t.pump(const Duration(milliseconds: 300));
    expect((cardTaps, calls), (1, 0));
    await t.tap(find.text('Call'));
    await t.pump(const Duration(milliseconds: 300));
    expect((cardTaps, calls), (1, 1));
    await _pump(t, _card(onTap: () => cardTaps++, actions: [CalmAction(kind: CalmActionKind.call, label: 'Call', busy: true, onTap: () => calls++)]));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.tap(find.text('Call'));
    await t.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
  });

  _sized('full card with every slot fits', (t, w, s) async {
    await _pump(
      t,
      Column(children: [
        _card(featured: true, price: '₹12,75,000', was: '₹15,00,000', offTag: '15% off', leadChip: 'Full on your dates', actions: [
          CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () {}),
          CalmAction(kind: CalmActionKind.whatsApp, label: 'WhatsApp', onTap: () {}),
        ]),
        _card(index: 1, place: '', address: null),
      ]),
      width: w,
      scale: s,
    );
  });
}
