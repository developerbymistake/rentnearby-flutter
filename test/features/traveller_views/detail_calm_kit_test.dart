import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Size size = const Size(360, 1400), double scale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SingleChildScrollView(child: SizedBox(width: size.width, child: Column(children: [child])))),
      ),
    );

DetailTitleCard _title({String? place = 'Nainital', String? was = '₹1,800', String? chip = '15% off'}) => DetailTitleCard(
      tone: ListingTone.forest,
      eyebrow: 'FOR STAY',
      title: 'Deodar Cottage Homestay',
      caption: 'From',
      value: '₹1,530',
      unit: '/night',
      was: was,
      chip: chip,
      place: place,
    );

BoxDecoration _decoOf(WidgetTester t, Finder inside) {
  final box = t.widgetList<Container>(find.ancestor(of: inside, matching: find.byType(Container))).firstWhere((c) {
    final d = c.decoration;
    return d is BoxDecoration && d.gradient != null;
  });
  return box.decoration! as BoxDecoration;
}

void _noWhiteText(WidgetTester t) {
  for (final text in t.widgetList<Text>(find.byType(Text))) {
    final c = text.style?.color;
    if (c == null || text.data == '15% off') continue;
    expect(c == Colors.white || c == DesignColors.onPrimary, isFalse, reason: 'white text: ${text.data}');
  }
}

const _facilities = [
  DetailChipItem(art: ListingArt.hotSprings, label: 'Hot water'),
  DetailChipItem(art: DetailArt.droplet, label: 'Heater'),
  DetailChipItem(art: ListingArt.antenna, label: 'Wi-Fi'),
  DetailChipItem(art: DetailArt.automobile, label: 'Parking'),
  DetailChipItem(art: ListingArt.potOfFood, label: 'Home food'),
  DetailChipItem(art: ListingArt.mountain, label: 'Mountain view'),
];

const _rules = [
  DetailChipItem(art: ListingArt.key, label: 'Check-in', value: '12:00 PM'),
  DetailChipItem(art: ListingArt.luggage, label: 'Check-out', value: '11:00 AM'),
  DetailChipItem(art: ListingArt.paw, label: 'Pets', value: 'No'),
  DetailChipItem(art: ListingArt.clipboard, label: 'Cancellation', value: ''),
];

Widget _all() => Column(children: [
      _title(),
      DetailSlimCard(tone: ListingTone.forest, art: ListingArt.bed, title: 'Deluxe', subtitle: '2 guests · Breakfast', price: '₹1,530', unit: '/night', was: '₹1,800'),
      DetailSlimCard(tone: ListingTone.coral, art: ListingArt.roundPushpin, title: 'Haldwani to Nainital', tag: 'Round trip', price: '₹2,400', highlight: true),
      DetailInfoCard(tone: ListingTone.forest, rows: const [DetailInfo(ListingArt.stay, 'Stay type', 'Homestay'), DetailInfo(ListingArt.pushpin, 'Location', '')]),
      DetailChipGrid(tone: ListingTone.forest, items: _facilities),
      DetailChipGrid(tone: ListingTone.forest, rules: true, items: _rules),
      const DetailAboutCard(text: 'A quiet wooden cottage above the lake.'),
    ]);

void main() {
  group('title card', () {
    testWidgets('calm gradient white to tint, hero notch, From caption, struck was, chip under the price, no white text', (t) async {
      await t.pumpWidget(_host(_title()));
      final d = _decoOf(t, find.text('Deodar Cottage Homestay'));
      expect((d.gradient! as LinearGradient).colors, [DesignColors.surface, ListingPalette.forest.tint]);
      expect(d.borderRadius, DS.br(CardRadius.hero));
      expect(find.text('From'), findsOneWidget);
      expect(find.text('Nainital'), findsOneWidget);
      expect(t.widget<Text>(find.text('₹1,800')).style?.decoration, TextDecoration.lineThrough);
      expect(t.getTopLeft(find.text('15% off')).dy, greaterThan(t.getBottomLeft(find.text('₹1,530')).dy));
      expect(find.byType(CalmChip), findsNWidgets(2));
      _noWhiteText(t);
    });

    testWidgets('place row hidden for empty and null', (t) async {
      for (final place in ['', null]) {
        await t.pumpWidget(_host(_title(place: place)));
        expect(find.text('Nainital'), findsNothing);
        expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.roundPushpin), findsNothing);
      }
    });

    testWidgets('no offer: no struck price, no chip', (t) async {
      await t.pumpWidget(_host(_title(was: null, chip: null)));
      expect(find.text('₹1,800'), findsNothing);
      expect(find.text('15% off'), findsNothing);
    });
  });

  group('slim card', () {
    testWidgets('room form shows subtitle; route form shows the trip tag; highlight border on and off', (t) async {
      await t.pumpWidget(_host(Column(children: [
        DetailSlimCard(tone: ListingTone.forest, art: ListingArt.bed, title: 'Deluxe', subtitle: '2 guests · Breakfast', price: '₹1,530', unit: '/night'),
        DetailSlimCard(tone: ListingTone.coral, art: ListingArt.roundPushpin, title: 'Haldwani to Nainital', tag: 'Round trip', price: '₹2,400', highlight: true),
        DetailSlimCard(tone: ListingTone.coral, art: ListingArt.roundPushpin, title: 'Haldwani to Almora', tag: 'One way', price: '₹3,100'),
      ])));
      expect(find.text('2 guests · Breakfast'), findsOneWidget);
      expect(find.text('Round trip'), findsOneWidget);
      expect(find.text('One way'), findsOneWidget);
      final on = _decoOf(t, find.text('Haldwani to Nainital'));
      final off = _decoOf(t, find.text('Haldwani to Almora'));
      expect((on.border! as Border).top.color, ListingPalette.coral.g2);
      expect(off.border, isNull);
      expect((_decoOf(t, find.text('Deluxe')).gradient! as LinearGradient).colors.last, ListingPalette.forest.tint);
      expect((on.gradient! as LinearGradient).colors.last, ListingPalette.coral.tint);
      _noWhiteText(t);
    });
  });

  group('info, tiles, about', () {
    testWidgets('calm decoration, values and dash for empty values', (t) async {
      await t.pumpWidget(_host(_all()));
      expect(find.text('Homestay'), findsOneWidget);
      expect(find.text('-'), findsNWidgets(2));
      for (final label in ['Hot water', 'Heater', 'Wi-Fi', 'Parking', 'Home food', 'Mountain view', 'Check-in', 'Pets', 'A quiet wooden cottage above the lake.']) {
        final d = _decoOf(t, find.text(label));
        expect((d.gradient! as LinearGradient).colors, [DesignColors.surface, ListingPalette.forest.tint], reason: label);
      }
      expect(_decoOf(t, find.text('Hot water')).borderRadius, DS.circular(14));
      expect(_decoOf(t, find.text('Pets')).borderRadius, DS.circular(16));
      final hot = t.getTopLeft(find.text('Hot water'));
      final heater = t.getTopLeft(find.text('Heater'));
      expect(hot.dy, closeTo(heater.dy, 4));
      _noWhiteText(t);
    });
  });

  for (final w in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('kit fits at $w @$scale, prices stay on one line', (t) async {
        final size = Size(w, 2000);
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(_all(), size: size, scale: scale));
        expect(t.takeException(), isNull);
        for (final price in ['₹2,400']) {
          final text = t.widget<Text>(find.text(price));
          final style = text.style!;
          final line = TextScaler.linear(scale).scale(style.fontSize!) * (style.height ?? 1.2);
          expect(t.getSize(find.text(price)).height, lessThan(line * 1.6), reason: price);
        }
        expect(t.getSize(find.text('₹1,530').first).height, lessThan(DS.s(30) * scale * 1.6));
      });
    }
  }
}
