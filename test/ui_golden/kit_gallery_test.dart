import 'package:bakhli/design/design.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_support.dart';

Widget _gallery() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroBanner(title: 'List your stay', subtitle: 'Reach travellers near you', iconAsset: TravelIcon.stay, tone: KitTone.stay, cta: 'Start', onTap: () {}),
        const SizedBox(height: 12),
        HeroBanner(title: 'Seeker', subtitle: 'Plan trips and find stays', iconAsset: TravelIcon.route, tone: KitTone.jobs, selected: true, badge: 'CURRENT', onTap: () {}),
        ListRow(
          margin: const EdgeInsets.symmetric(vertical: 6),
          title: 'Hillview Homestay near Mall Road',
          subtitle: 'Nainital',
          tag: 'HOMESTAY',
          facts: const [CardFact('3 rooms'), CardFact('Meals', tone: FactTone.cyan)],
          priceValue: '₹1,800',
          priceUnit: '/night',
          onTap: () {},
        ),
        ListRow.skeleton(margin: const EdgeInsets.symmetric(vertical: 6)),
        DriverOptionCard(
          margin: const EdgeInsets.symmetric(vertical: 6),
          name: 'Ramesh Kumar Negi',
          vehicle: 'Innova Crysta, 7 seats',
          facts: const [CardFact('AC'), CardFact('Luggage', tone: FactTone.slate)],
          fareValue: '₹1,800',
          fareUnit: 'min fare',
          actions: [PillAction(label: 'Call', tone: KitTone.taxi, filled: true, onTap: () {}), PillAction(label: 'Ask', tone: KitTone.taxi, onTap: () {})],
          onTap: () {},
        ),
        SlimBar(margin: const EdgeInsets.symmetric(vertical: 6), title: 'Follow us on Instagram', subtitle: 'Travel stories', leadingAsset: TravelIcon.photo, tone: KitTone.jobs, filled: true, onTap: () {}),
        PrimaryButton(label: 'Continue', onPressed: () {}, tone: KitTone.stay, trailingArrow: true),
        const SizedBox(height: 8),
        SecondaryButton(label: 'Skip', onPressed: () {}, neutral: true),
        const SizedBox(height: 8),
        const SizedBox(height: 300, child: StateCard(title: 'No trips yet', message: 'Plan your first trip.', actionLabel: 'Plan a trip', onAction: _noop)),
      ],
    );

void _noop() {}

void main() {
  setUpAll(loadGoldenFonts);
  for (final s in [1.0, 1.3]) {
    testWidgets('kit gallery $s', (t) async {
      setGoldenView(t, const Size(360, 1400));
      await t.pumpWidget(goldenHost(_gallery(), scale: s));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/kit_gallery_$s.png'));
    });
  }
}
