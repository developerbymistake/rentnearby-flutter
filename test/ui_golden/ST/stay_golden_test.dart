import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiry_button.dart';
import 'package:bakhli/features/stay/guest/stay_bottom_sheet.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

StayNearbyModel _stay() => StayNearbyModel(
      id: 's1',
      name: 'Riverside Heritage Homestay Near Naini Lake',
      stayTypeName: 'Homestay',
      latitude: 29.4,
      longitude: 79.4,
      minPricePerNight: 2400,
      distanceKm: 3.4,
      isActive: true,
      isFeatured: true,
    );

Widget _gridPair() => const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(width: 150, height: StayGridCard.height, child: _Card(featured: true)),
        SizedBox(width: 150, height: StayGridCard.height, child: _Card(featured: false)),
      ],
    );

class _Card extends StatelessWidget {
  const _Card({required this.featured});
  final bool featured;

  @override
  Widget build(BuildContext context) => StayGridCard(
        thumbnailUrl: null,
        tagLabel: 'FOR STAY',
        title: 'Riverside Heritage Homestay Near Naini Lake',
        locationLabel: 'Bhimtal, Nainital',
        facts: const [CardFact('Homestay'), CardFact('Meals', tone: FactTone.cyan)],
        priceCaption: 'FROM',
        priceValue: 'Rs 2,400',
        priceUnit: '/night',
        isFeatured: featured,
        onViewDetails: () {},
      );
}

Widget _mapRow(bool elevated) => ListRow(
      tag: 'FOR STAY',
      title: 'Riverside Heritage Homestay Near Naini Lake',
      subtitle: 'Homestay · 3.4 km',
      priceCaption: 'FROM',
      priceValue: 'Rs 2,400',
      priceUnit: '/night',
      isFeatured: true,
      margin: elevated ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 6),
      onTap: () {},
    );

Widget _buttons() => Wrap(spacing: 8, runSpacing: 8, children: [
      StayEnquiryButton(label: 'Send offer', kind: StayEnquiryButtonKind.primary, onTap: () {}),
      StayEnquiryButton(label: 'Accept price', kind: StayEnquiryButtonKind.positive, onTap: () {}),
      StayEnquiryButton(label: 'Not available', kind: StayEnquiryButtonKind.negative, onTap: () {}),
      StayEnquiryButton(label: 'Chat', kind: StayEnquiryButtonKind.plain, iconAsset: TravelIcon.chat, onTap: () {}),
      const StayEnquiryButton(label: 'Disabled', kind: StayEnquiryButtonKind.primary, onTap: null),
    ]);

void main() {
  setUpAll(loadGoldenFonts);

  for (final scale in [1.0, 1.3]) {
    final tag = scale == 1.0 ? '1_0' : '1_3';

    testWidgets('stay cards scale $scale', (t) async {
      setGoldenView(t);
      await t.pumpWidget(goldenHost(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _gridPair(),
          const SizedBox(height: 16),
          _mapRow(false),
          _mapRow(true),
          const SizedBox(height: 16),
          _buttons(),
        ]),
        scale: scale,
      ));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/stay_cards_$tag.png'));
    });

    testWidgets('stay bottom sheet scale $scale', (t) async {
      setGoldenView(t);
      await t.pumpWidget(goldenHost(StayBottomSheet(stay: _stay()), scale: scale, scroll: false));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/stay_sheet_$tag.png'));
    });
  }

  testWidgets('calendar popup works when first equals last date', (t) async {
    setGoldenView(t);
    final d = DateTime(2030, 5, 10);
    DateTime? picked;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => picked = await TemplateCalendarPopup.pickDate(ctx, initial: d, first: d, last: d, tone: KitTone.stay),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pump(const Duration(milliseconds: 800));
    expect(t.takeException(), isNull);
    await t.tap(find.text('Apply'));
    await t.pump(const Duration(milliseconds: 800));
    expect(t.takeException(), isNull);
    expect(picked, d);
  });
}
