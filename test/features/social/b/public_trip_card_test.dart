import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/social_widgets_b.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/public_trip_card.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

Widget _host(Widget child) => Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    CityCoverLookup.debugReset();
    putSeeker();
    installServer();
  });
  tearDown(Get.reset);

  Widget rail(PublicTrip trip, {VoidCallback? onTap}) => SizedBox(width: 290, child: PublicTripCard(trip: trip, onTap: onTap));

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('rail card: cover, who and seats pills, owner short name and level ($size, $scale)', (t) async {
        final trip = PublicTrip.fromJson(publicTripJson(ownerTrips: 12, ownerLevel: 2));
        await pumpSocial(t, _host(rail(trip)), size: size, textScale: scale);
        expect(find.text('Kavya S.'), findsOneWidget);
        expect(find.text('Rishikesh'), findsOneWidget);
        expect(find.text('December · 5 days'), findsOneWidget);
        expect(find.text('Anyone'), findsOneWidget);
        expect(find.text('2 seats left'), findsOneWidget);
        expect(find.text(SocialStrings.follow), findsNothing);
        expect(find.byKey(PublicTripCard.levelKey), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('rail card: women-only pill, 4+ seats, tap fires', (t) async {
    var taps = 0;
    final trip = PublicTrip.fromJson(publicTripJson(joinGender: 'F', seats: 11, seatsLeft: 6));
    await pumpSocial(t, _host(rail(trip, onTap: () => taps++)));
    expect(find.text('Kavya S.'), findsOneWidget);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('4+ seats left'), findsOneWidget);
    expect(find.text(SocialStrings.follow), findsNothing);
    await t.tap(find.text('Rishikesh'));
    expect(taps, 1);
  });

  testWidgets('a full trip reads Full', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(seatsLeft: 0));
    await pumpSocial(t, _host(rail(trip)));
    expect(find.text('Full'), findsOneWidget);
  });

  testWidgets('a post with the most requests shows Full with its key, not on my own post', (t) async {
    final full = PublicTrip.fromJson({...publicTripJson(), 'requestsFull': true});
    final mine = PublicTrip.fromJson({...publicTripJson(isMine: true), 'requestsFull': true});
    await pumpSocial(t, _host(Column(children: [rail(full), rail(mine)])));
    expect(find.byKey(PublicTripCard.fullKey), findsOneWidget);
  });

  testWidgets('the rail reads plain seats left even on my own trip', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(isMine: true, seats: 3, seatsLeft: 3));
    await pumpSocial(t, _host(rail(trip)));
    expect(find.text('3 seats left'), findsOneWidget);
    expect(find.text('3 of 3 seats left'), findsNothing);
  });

  testWidgets('T1: a post without a travel mode shows no travel chip', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson());
    expect(trip.travelMode, isNull);
    await pumpSocial(t, _host(rail(trip)));
    expect(find.byKey(PublicTripCard.travelKey), findsNothing);
    for (final label in SocialStringsB.travelLabels) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  for (final (code, label) in [('taxi', 'Taxi'), ('bike', 'Bike'), ('bus', 'Bus'), ('train', 'Train')]) {
    testWidgets('T2: travel mode $code shows the $label chip with its 3D art on the rail card', (t) async {
      final trip = PublicTrip.fromJson(publicTripJson(travelMode: code));
      await pumpSocial(t, _host(rail(trip)));
      expect(find.byKey(PublicTripCard.travelKey), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      expect(find.descendant(of: find.byKey(PublicTripCard.travelKey), matching: find.byType(Art3D)), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('T2: the chip fits the rail card at a large text size', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(travelMode: 'train', joinGender: 'F'));
    await pumpSocial(t, _host(rail(trip)), textScale: 1.3);
    expect(find.text('Train'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('an unknown travel mode from the server is dropped', () {
    expect(PublicTrip.fromJson(publicTripJson(travelMode: 'plane')).travelMode, isNull);
    expect(PublicTrip.fromJson(publicTripJson(travelMode: 'public')).travelMode, isNull, reason: 'I-1: old codes are gone');
    expect(PublicTrip.fromJson(publicTripJson(travelMode: 'car')).travelMode, isNull);
    expect(PublicTrip.fromJson({...publicTripJson()}..remove('travelMode')).travelMode, isNull);
    expect(PublicTrip.fromJson(publicTripJson(travelMode: 'bus')).copyWith(myJoin: 'requested').travelMode, 'bus');
  });

  testWidgets('owner level: round trophy + N trips beside the name; none on a sample', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(ownerTrips: 124, ownerLevel: 4));
    await pumpSocial(t, _host(Column(children: [
      rail(trip),
      rail(PublicTrip.fromJson(publicTripJson(id: 's', sample: true, ownerTrips: 3, ownerLevel: 1))),
    ])));
    expect(find.byKey(PublicTripCard.levelKey), findsOneWidget);
    expect(find.text('124 trips'), findsOneWidget);
    expect(find.text('3 trips'), findsNothing);
    expect(t.getRect(find.byKey(PublicTripCard.levelKey)).left, greaterThan(t.getRect(find.text('Kavya S.').first).right));
    expect(t.takeException(), isNull);
  });

  group('I-24 city photo on the card', () {
    const withPhoto = TripCityModel(cityKey: 201, name: 'Rishikesh', latitude: 30.1, longitude: 78.3, coverUrl: 'https://example.com/rishikesh.jpg');
    const noPhoto = TripCityModel(cityKey: 202, name: 'Chopta', latitude: 30.4, longitude: 79.2);

    Widget cards(PublicTrip trip) => _host(rail(trip));

    testWidgets('the first city photo fills the rail cover', (t) async {
      TripCityCatalog.to.seedForTest(const [withPhoto, noPhoto]);
      final trip = PublicTrip.fromJson(publicTripJson(cityKey: 201));
      await pumpSocial(t, cards(trip));
      expect(find.byKey(PublicTripCard.photoKey), findsOneWidget);
      expect(find.byType(TripCoverArt), findsNothing);
      expect(find.text('Rishikesh'), findsOneWidget);
      expect(find.text('December · 5 days'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(minutes: 1));
    });

    testWidgets('a city without a photo keeps the gradient cover and art', (t) async {
      TripCityCatalog.to.seedForTest(const [withPhoto, noPhoto]);
      final trip = PublicTrip.fromJson(publicTripJson(cityKey: 202, cities: const ['Chopta']));
      await pumpSocial(t, cards(trip));
      expect(find.byKey(PublicTripCard.photoKey), findsNothing);
      expect(find.byType(TripCoverArt), findsOneWidget);
    });

    testWidgets('the photo shows once the city list arrives after the card was built', (t) async {
      final trip = PublicTrip.fromJson(publicTripJson(cityKey: 201));
      await pumpSocial(t, _host(rail(trip)));
      expect(find.byKey(PublicTripCard.photoKey), findsNothing);
      TripCityCatalog.to.seedForTest(const [withPhoto]);
      CityCoverLookup.loaded.value++;
      await t.pump();
      expect(find.byKey(PublicTripCard.photoKey), findsOneWidget);
      await drain(t);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(minutes: 1));
    });
  });
}
