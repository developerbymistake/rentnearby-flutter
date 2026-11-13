import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:bakhli/design/template/hotel_app_theme.dart';
import 'package:bakhli/design/template/models/meals_list_data.dart';
import 'package:bakhli/design/template/my_diary/meals_list_view.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/models/browse_item.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/models/home_feed_model.dart';
import 'package:bakhli/widgets/home_stay_rail_card.dart';
import 'package:bakhli/widgets/home_taxi_rail_card.dart';
import 'package:bakhli/widgets/nearby_item_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_phone.dart';

const _out = r'F:\Dhasu\UI_Template_resume\Slice2\shots';

TaxiBrowseItem _taxi({bool match = true}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Negi',
      vehicleTypeName: 'Sedan',
      seats: 4,
      plateDisplay: 'UK 04 AB 1234',
      cityName: 'Nainital',
      routeCount: 3,
      matchedFare: match ? 5200 : null,
      matchedFromName: 'Delhi',
      matchedToName: 'Nainital',
      matchedTripType: 'OneWay',
      minFare: 1800,
      matchReversed: false,
      createdAt: DateTime(2030, 1, 1),
    );

HomeStayModel _stayModel() => HomeStayModel(
      districtName: 'Nainital',
      item: BrowseItem(
        id: 's1',
        userId: 'u',
        thumbnailUrl: null,
        tagLabel: 'FOR STAY',
        title: 'Hotel Himalayan View',
        locationLabel: 'Nainital, Nainital',
        facts: const [CardFact('Hotel'), CardFact('Breakfast')],
        priceCaption: 'FROM',
        priceValue: 'Rs 2,400',
        priceUnit: '/night',
      ),
    );

Widget _gridCards(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < 2; i++) ...[
        if (i == 1) const SizedBox(width: RailCard.gridSpacing),
        Expanded(
          child: SizedBox(
            height: StayGridCard.heightOf(context),
            child: StayGridCard(
              key: ValueKey('sgc$i'),
              thumbnailUrl: null,
              tagLabel: 'FOR STAY',
              title: 'Hotel Himalayan View',
              locationLabel: 'Nainital, Nainital',
              facts: const [CardFact('Hotel'), CardFact('Breakfast')],
              priceCaption: 'FROM',
              priceValue: 'Rs 2,400',
              priceUnit: '/night',
              onViewDetails: () {},
            ),
          ),
        ),
      ],
    ]);

Widget _hotel(ThemeData theme) {
  final grey = Colors.grey.withValues(alpha: 0.8);
  return Padding(
    padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 16),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(16.0)),
        boxShadow: <BoxShadow>[BoxShadow(color: Colors.grey.withValues(alpha: 0.6), offset: const Offset(4, 4), blurRadius: 16)],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16.0)),
        child: Column(children: [
          AspectRatio(aspectRatio: 2, child: Image.asset('assets/images/design/hotel/hotel_1.png', fit: BoxFit.cover)),
          Container(
            color: theme.colorScheme.surface,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Grand Royal Hotel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
                    Text('Wembley, London', style: TextStyle(fontSize: 14, color: grey)),
                    Text('80 Reviews', style: TextStyle(fontSize: 14, color: grey)),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('\$180', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
                  Text('/per night', style: TextStyle(fontSize: 14, color: grey)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

void _tw(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    shotsDir = _out;
    Directory(_out).createSync(recursive: true);
  });

  _tw('stay card beside the template hotel card', (t) async {
    final theme = HotelAppTheme.buildLightTheme();
    await pumpPhone(
      t,
      Theme(
        data: theme,
        child: Scaffold(
          body: SafeArea(
            child: Column(children: [
              _hotel(theme),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
                child: Builder(builder: (c) => _gridCards(c)),
              ),
            ]),
          ),
        ),
      ),
    );
    await settlePhone(t);
    expect(t.takeException(), isNull);
    await shot(t, 'K_stay_vs_template');
    final r = t.getRect(find.byKey(const ValueKey('sgc0')));
    expect(r.height, lessThanOrEqualTo(StayGridCard.height));
    expect(find.text('Hotel Himalayan View'), findsWidgets);
    expect(find.textContaining('2,400'), findsWidgets);
  });

  _tw('home rails beside the template meals card', (t) async {
    final a = AnimationController(vsync: t, duration: const Duration(milliseconds: 1))..value = 1;
    final anim = CurvedAnimation(parent: a, curve: Curves.linear);
    await pumpPhone(
      t,
      Scaffold(
        backgroundColor: FitnessAppTheme.background,
        body: SafeArea(
          child: ListView(children: [
            SizedBox(
              height: 216,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16, left: 16),
                children: [
                  for (final m in MealsListData.tabIconsList) MealsView(mealsListData: m, animation: anim, animationController: a),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MealsRail(
              children: [
                HomeStayRailCard(key: const ValueKey('hsr'), stay: _stayModel(), onOpen: () {}),
                HomeTaxiRailCard(key: const ValueKey('htr'), taxi: _taxi(), onOpen: () {}),
                HomeTaxiRailCard(taxi: _taxi(match: false), onOpen: () {}),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
              child: NearbyItemRow(
                key: const ValueKey('nir'),
                thumbnailUrl: null,
                tag: 'FOR STAY',
                title: 'Hotel Himalayan View',
                subtitle: 'Nainital',
                caption: 'FROM',
                value: 'Rs 2,400',
                unit: '/night',
                placeholderIcon: Icons.home_rounded,
                elevated: true,
                onTap: () {},
              ),
            ),
          ]),
        ),
      ),
    );
    await settlePhone(t);
    expect(t.takeException(), isNull);
    await shot(t, 'K_rails_vs_template');
    expect(find.byType(MealsView), findsWidgets);
    final ours = t.getRect(find.descendant(of: find.byKey(const ValueKey('hsr')), matching: find.byType(MealsCardV)));
    final oursTaxi = t.getRect(find.descendant(of: find.byKey(const ValueKey('htr')), matching: find.byType(MealsCardV)));
    expect(oursTaxi.height, ours.height);
    expect(ours.width, HomeStayRailCard.cellWidth);
  });

  _tw('taxi card is compact and keeps every action', (t) async {
    await pumpPhone(
      t,
      Scaffold(
        backgroundColor: DesignColors.scaffold,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(children: [
              TaxiCard(key: const ValueKey('tc'), item: _taxi(), onOpen: () {}, onSelect: () {}, onEnquire: () {}),
              TaxiCard(key: const ValueKey('tc2'), item: _taxi(match: false), onOpen: () {}),
            ]),
          ),
        ),
      ),
    );
    await settlePhone(t);
    expect(t.takeException(), isNull);
    await shot(t, 'K_taxi_cards');
    expect(find.text('Call'), findsNWidgets(2));
    expect(find.text('Enquiry'), findsNWidgets(2));
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Ramesh Negi'), findsNWidgets(2));
    expect(find.textContaining('to Nainital'), findsOneWidget);
    expect(find.textContaining('Nainital'), findsWidgets);
  });

  for (final scale in [1.3, 2.0]) {
    _tw('cards survive text scale $scale', (t) async {
      await pumpPhone(
        t,
        Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(children: [
                TaxiCard(item: _taxi(), onOpen: () {}, onSelect: () {}, onEnquire: () {}),
                MealsRail(children: [
                  HomeStayRailCard(stay: _stayModel(), onOpen: () {}),
                  HomeTaxiRailCard(taxi: _taxi(), onOpen: () {}),
                ]),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(builder: (c) => _gridCards(c)),
                ),
              ]),
            ),
          ),
        ),
        textScale: scale,
      );
      await settlePhone(t);
      expect(t.takeException(), isNull);
    });
  }
}
