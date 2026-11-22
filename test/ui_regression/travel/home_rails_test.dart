import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/features/seeker_home/seeker_rail_art.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/models/browse_item.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/models/home_feed_model.dart';
import 'package:bakhli/widgets/home_stay_rail_card.dart';
import 'package:bakhli/widgets/home_taxi_rail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaxiBrowseItem _taxi({bool featured = true, int? fare = 1800}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07',
      cityName: 'Dehradun',
      minFare: fare,
      routeCount: 2,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
      isFeatured: featured,
    );

Widget _host(Widget child, {double scale = 1, double? height}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: height == null
                ? MealsRail(children: [child])
                : SizedBox(height: height, child: ListView(scrollDirection: Axis.horizontal, children: [child])),
          ),
        ),
      ),
    );

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('taxi rail card shows all details at scale $scale', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(HomeTaxiRailCard(taxi: _taxi(), onOpen: () => taps++), scale: scale));
      expect(find.text('INNOVA CRYSTA'), findsOneWidget);
      expect(find.textContaining('FEATURED', findRichText: true), findsNothing);
      expect(find.byKey(const ValueKey('meals-star-badge')), findsOneWidget);
      expect(find.text('Dehradun'), findsOneWidget);
      expect(find.text('Innova Crysta'), findsNothing);
      expect(find.text('7 seats'), findsNothing);
      expect(find.textContaining('1,800'), findsOneWidget);
      expect(find.text('FARE FROM'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(HomeTaxiRailCard));
      expect(taps, 1);
    });
  }

  testWidgets('taxi rail card without fare shows local taxi', (tester) async {
    await tester.pumpWidget(_host(HomeTaxiRailCard(taxi: _taxi(featured: false, fare: null))));
    expect(find.text('Dehradun'), findsOneWidget);
    expect(find.text('Local taxi'), findsOneWidget);
    expect(find.byKey(const ValueKey('meals-star-badge')), findsNothing);
    expect(find.text('INNOVA CRYSTA'), findsOneWidget);
    expect(find.textContaining('FEATURED'), findsNothing);
    expect(find.text('FARE FROM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taxi rail card with no fare and no base city shows Local taxi once', (tester) async {
    final t = TaxiBrowseItem(
      id: 't2',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      plateDisplay: 'UK07',
      routeCount: 0,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(_host(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      HomeTaxiRailCard(taxi: t),
      HomeTaxiRailCard(taxi: _taxi(featured: false, fare: null)),
    ])));
    expect(find.text('Local taxi'), findsNWidgets(2));
    final cards = find.byType(MealsCardV);
    expect(tester.getSize(cards.at(0)).height, tester.getSize(cards.at(1)).height);
    expect(tester.takeException(), isNull);
  });

  test('taxi base city is read from cityName of the browse and feed JSON', () {
    final t = TaxiBrowseItem.fromJson({
      'id': 't',
      'driverName': 'Ravi',
      'vehicleTypeName': 'Sedan',
      'plateDisplay': 'UK04',
      'routeCount': 1,
      'createdAt': '2026-01-01T00:00:00Z',
      'cityName': 'Haldwani',
      'districtName': 'Nainital',
    });
    expect(t.cityName, 'Haldwani');
    expect(t.baseCityName, isNull);
    expect(t.locality, 'Haldwani');
  });

  testWidgets('stay and taxi rail cards have the same height and one location line', (tester) async {
    BrowseItem item(String title, String place, String? km) => BrowseItem(
          id: 's',
          userId: 'u',
          thumbnailUrl: null,
          tagLabel: 'FOR STAY',
          title: title,
          locationLabel: place,
          facts: const [],
          priceCaption: 'FROM',
          priceValue: 'Rs 1,100',
          priceUnit: '/night',
          placeName: place,
          distanceLabel: km,
        );
    Widget stay(String title, String place, String? km) =>
        HomeStayRailCard(stay: HomeStayModel(item: item(title, place, km), districtName: ''), onOpen: () {});
    await tester.pumpWidget(_host(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      stay('Inn', 'Kathgodam', '8.7 km away'),
      stay('Naukuchiatal Lake Stay', 'A very long place name that must never wrap', null),
      HomeTaxiRailCard(taxi: _taxi(featured: false), onOpen: () {}),
    ])));
    expect(find.text('Kathgodam · 8.7 km'), findsOneWidget);
    final cards = find.byType(MealsCardV);
    final h = tester.getSize(cards.at(0)).height;
    expect(tester.getSize(cards.at(1)).height, h);
    expect(tester.getSize(cards.at(2)).height, h);
    final long = tester.getSize(find.text('A very long place name that must never wrap'));
    expect(long.height, lessThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stay grid card in the rail cell shows facts and price', (tester) async {
    await tester.pumpWidget(_host(Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: SizedBox(
        width: HomeStayRailCard.cellWidth,
        child: StayGridCard(
          thumbnailUrl: null,
          tagLabel: 'HOMESTAY',
          title: 'Himalayan View',
          locationLabel: 'Mussoorie',
          facts: const [
            CardFact('Breakfast', tone: FactTone.accent),
            CardFact('Wifi', tone: FactTone.cyan),
            CardFact('Parking', tone: FactTone.slate),
          ],
          priceCaption: 'FROM',
          priceValue: 'Rs 1,200',
          priceUnit: '/night',
          isFeatured: true,
          onViewDetails: () {},
        ),
      ),
    ), height: StayGridCard.height + 24));
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('A3 rail look', () {
    const photo = 'https://res.cloudinary.com/demo/image/upload/a.jpg';
    BrowseItem item({String title = 'Deodar Cottage', String? thumb, String? km = '1.4 km away'}) => BrowseItem(
          id: 's',
          userId: 'u',
          thumbnailUrl: thumb,
          tagLabel: 'FOR STAY',
          title: title,
          locationLabel: 'Kausani',
          facts: const [],
          priceCaption: 'FROM',
          priceValue: '₹1,500',
          priceUnit: '/night',
          placeName: 'Kausani',
          distanceLabel: km,
        );
    Widget stay({String title = 'Deodar Cottage', String? thumb, String? type}) =>
        HomeStayRailCard(stay: HomeStayModel(item: item(title: title, thumb: thumb), districtName: '', stayTypeName: type), onOpen: () {});
    TaxiBrowseItem taxi({String? photo, double? km, bool featured = false}) => TaxiBrowseItem(
          id: 't',
          driverName: 'Pradeep',
          vehicleTypeName: 'Sedan',
          plateDisplay: 'UK04',
          cityName: 'Nainital',
          minFare: 1200,
          routeCount: 1,
          matchReversed: false,
          createdAt: DateTime(2026, 1, 1),
          isFeatured: featured,
          displayPhotoUrl: photo,
          distanceKm: km,
        );
    PhotoCircle circle(WidgetTester t) => t.widget<PhotoCircle>(find.byType(PhotoCircle));

    testWidgets('stay card: FROM above the price, place without away, photo in the circle', (t) async {
      await t.pumpWidget(_host(stay(thumb: photo)));
      expect(find.text('FROM'), findsOneWidget);
      expect(t.getTopLeft(find.text('FROM')).dy, lessThan(t.getTopLeft(find.textContaining('1,500')).dy));
      expect(find.text('Kausani · 1.4 km'), findsOneWidget);
      expect(circle(t).url, photo);
      expect(t.takeException(), isNull);
    });

    testWidgets('stay card without photo: the stay type art', (t) async {
      await t.pumpWidget(_host(stay(type: 'Camp')));
      expect(circle(t).url, isNull);
      expect(circle(t).art, SeekerRailArt.forStay('Camp'));
    });

    testWidgets('taxi card: display photo or vehicle art, place line with km', (t) async {
      await t.pumpWidget(_host(HomeTaxiRailCard(taxi: taxi(photo: photo, km: 5), onOpen: () {})));
      expect(circle(t).url, photo);
      expect(find.text('Nainital · 5 km'), findsOneWidget);
      await t.pumpWidget(_host(HomeTaxiRailCard(taxi: taxi(), onOpen: () {})));
      expect(circle(t).url, isNull);
      expect(circle(t).art, SeekerRailArt.forVehicle('Sedan'));
      expect(find.text('Nainital'), findsOneWidget);
    });

    testWidgets('featured taxi shows the star with and without a photo', (t) async {
      for (final p in [photo, null]) {
        await t.pumpWidget(_host(HomeTaxiRailCard(taxi: taxi(photo: p, featured: true), onOpen: () {})));
        expect(find.byKey(const ValueKey('meals-star-badge')), findsOneWidget);
      }
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('one-line and two-line titles keep equal card heights at $scale', (t) async {
        await t.pumpWidget(_host(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stay(title: 'Inn'),
          stay(title: 'Pine Ridge Cottage and Garden Rooms'),
          HomeTaxiRailCard(taxi: taxi(km: 5), onOpen: () {}),
        ]), scale: scale));
        final cards = find.byType(MealsCardV);
        final h = t.getSize(cards.at(0)).height;
        expect(t.getSize(cards.at(1)).height, h);
        expect(t.getSize(cards.at(2)).height, h);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('null and unknown photo values never throw', (t) async {
      for (final v in ['', 'ftp://x', 'not a url', 'http://']) {
        await t.pumpWidget(_host(Row(children: [stay(thumb: v), HomeTaxiRailCard(taxi: taxi(photo: v), onOpen: () {})])));
        expect(t.takeException(), isNull);
      }
      final parsed = TaxiBrowseItem.fromJson({
        'id': 't', 'driverName': 'R', 'vehicleTypeName': 'Sedan', 'plateDisplay': 'U', 'routeCount': 0,
        'createdAt': '2026-01-01T00:00:00Z', 'displayPhotoUrl': 42, 'distanceKm': 'x',
      });
      expect(parsed.displayPhotoUrl, isNull);
      expect(parsed.distanceKm, isNull);
    });
  });
}
