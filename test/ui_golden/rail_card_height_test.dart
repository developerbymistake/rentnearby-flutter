import 'package:bakhli/design/extra/card_kit.dart';
import 'package:bakhli/design/extra/kit_tone.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_support.dart';

Widget _card(double w, double h) => SizedBox(
      width: w,
      height: h,
      child: RailCard(
        title: 'Riverside Heritage Homestay Near Naini Lake Mall Road',
        tagLabel: 'HOMESTAY',
        locationLabel: 'Bhimtal, Nainital',
        facts: const [CardFact('4 rooms'), CardFact('Meals', tone: FactTone.cyan)],
        priceCaption: 'From',
        priceValue: '₹12,500',
        priceUnit: '/night',
        isFeatured: true,
        tone: KitTone.stay,
        onTap: () {},
      ),
    );

void main() {
  setUpAll(loadGoldenFonts);

  Future<double> minHeight(WidgetTester t, double w, double scale) async {
    setGoldenView(t);
    for (var h = 200.0; h <= 340; h += 2) {
      await t.pumpWidget(goldenHost(Align(alignment: Alignment.topLeft, child: KeyedSubtree(key: ValueKey(h), child: _card(w, h))), scale: scale, scroll: false));
      await t.pump();
      final ex = t.takeException();
      if (ex == null) return h;
    }
    return -1;
  }

  testWidgets('RailCard height fits worst case at scale 1.0 and 1.3', (t) async {
    final results = <String>[];
    var worst = 0.0;
    for (final w in [RailCard.width, RailCard.gridMaxExtent]) {
      for (final s in [1.0, 1.3]) {
        final h = await minHeight(t, w, s);
        results.add('w=$w scale=$s minHeight=$h');
        if (h > worst) worst = h;
      }
    }
    // ignore: avoid_print
    print(results.join('\n'));
    expect(worst, isPositive);
    expect(RailCard.height, greaterThanOrEqualTo(worst));
  });

  testWidgets('RailCard worst case golden at 1.3', (t) async {
    setGoldenView(t);
    await t.pumpWidget(goldenHost(
        Column(mainAxisSize: MainAxisSize.min, children: [
          _card(RailCard.width, RailCard.height),
          const SizedBox(height: 12),
          RailCard.skeleton(),
        ]),
        scale: 1.3,
        scroll: false));
    await settleGolden(t);
    expect(t.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('golden_root')),
        matchesGoldenFile('goldens/rail_card_1.3.png'));
  });
}
