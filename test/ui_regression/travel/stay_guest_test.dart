import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/widgets/nearby_item_row.dart';
import 'package:bakhli/widgets/plan_badge_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stay grid card shows featured chip, price, facts and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 190,
            height: StayGridCard.height,
            child: StayGridCard(
              thumbnailUrl: null,
              tagLabel: 'FOR STAY',
              title: 'A long homestay title that wraps around',
              locationLabel: 'Mall Road, Manali',
              facts: const [
                CardFact('Breakfast included'),
                CardFact('Check-in 12 PM', tone: FactTone.cyan),
                CardFact('Free parking here', tone: FactTone.slate),
              ],
              priceCaption: 'FROM',
              priceValue: 'Rs 1,500',
              priceUnit: '/night',
              isFeatured: true,
              onViewDetails: () => taps++,
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(PlanBadgeChip), findsOneWidget);
    expect(find.textContaining('Rs 1,500', findRichText: true), findsOneWidget);
    expect(find.text('Free parking here'), findsOneWidget);
    await tester.tap(find.byType(StayGridCard));
    expect(taps, 1);
  });

  testWidgets('nearby row renders tag, featured and arrow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NearbyItemRow(
          thumbnailUrl: null,
          tag: 'FOR STAY',
          title: 'Hill View',
          subtitle: 'Homestay · 2 km',
          caption: 'FROM',
          value: 'Rs 900',
          placeholderIcon: Icons.hotel,
          isFeatured: true,
          onTap: () {},
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(PlanBadgeChip), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
