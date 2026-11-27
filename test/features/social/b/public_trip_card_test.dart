import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/public_trip_card.dart';
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
    putSeeker();
    installServer();
  });
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('feed card: owner row, cover, who and seats, text, footer ($size, $scale)', (t) async {
        final trip = PublicTrip.fromJson(publicTripJson());
        await pumpSocial(t, _host(PublicTripCard(trip: trip, footer: const Text('footer'), onMenu: () {})), size: size, textScale: scale);
        expect(find.text('Kavya S.'), findsOneWidget);
        expect(find.text('Dehradun'), findsOneWidget);
        expect(find.text('Dehradun · Mountains, Treks'), findsNothing);
        expect(find.text('Rishikesh'), findsOneWidget);
        expect(find.text('December · 5 days'), findsOneWidget);
        expect(find.text('Anyone'), findsOneWidget);
        expect(find.text('2 seats left'), findsOneWidget);
        expect(find.text(SocialStrings.follow), findsOneWidget);
        expect(find.text('footer'), findsOneWidget);
        expect(find.byKey(PublicTripCard.menuKey), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('my own post shows Your post and seats as N of M, no Follow', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(isMine: true, seats: 3, seatsLeft: 3, when: {'kind': 'within', 'months': 2}));
    await pumpSocial(t, _host(PublicTripCard(trip: trip)));
    expect(find.text(SocialStringsB.yourPost), findsOneWidget);
    expect(find.text('3 of 3 seats left'), findsOneWidget);
    expect(find.text('Within 2 months · 5 days'), findsOneWidget);
    expect(find.text(SocialStrings.follow), findsNothing);
  });

  testWidgets('rail mode: compact card with the owner short name and a women-only pill, tap fires', (t) async {
    var taps = 0;
    final trip = PublicTrip.fromJson(publicTripJson(joinGender: 'F', seats: 11, seatsLeft: 6));
    await pumpSocial(t, _host(SizedBox(width: 290, child: PublicTripCard(trip: trip, mode: PublicTripCardMode.rail, onTap: () => taps++))));
    expect(find.text('Kavya S.'), findsOneWidget);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('4+ seats left'), findsOneWidget);
    expect(find.text(SocialStrings.follow), findsNothing);
    await t.tap(find.text('Rishikesh'));
    expect(taps, 1);
  });

  testWidgets('a full trip reads Full', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(seatsLeft: 0));
    await pumpSocial(t, _host(PublicTripCard(trip: trip, mode: PublicTripCardMode.profile)));
    expect(find.text('Full'), findsOneWidget);
  });

  testWidgets('rail and profile cards read plain seats left even on my own trip', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(isMine: true, seats: 3, seatsLeft: 3));
    await pumpSocial(t, _host(SizedBox(width: 290, child: PublicTripCard(trip: trip, mode: PublicTripCardMode.rail))));
    expect(find.text('3 seats left'), findsOneWidget);
    expect(find.text('3 of 3 seats left'), findsNothing);
  });

  testWidgets('owner level: round trophy + N trips beside the name on the feed and rail cards; none on a sample', (t) async {
    final trip = PublicTrip.fromJson(publicTripJson(ownerTrips: 124, ownerLevel: 4));
    await pumpSocial(t, _host(Column(children: [
      PublicTripCard(trip: trip),
      SizedBox(width: 290, child: PublicTripCard(trip: trip, mode: PublicTripCardMode.rail)),
      PublicTripCard(trip: PublicTrip.fromJson(publicTripJson(id: 's', sample: true, ownerTrips: 3, ownerLevel: 1)), mode: PublicTripCardMode.profile),
    ])), size: const Size(392, 1800));
    expect(find.byKey(PublicTripCard.levelKey), findsNWidgets(2));
    expect(find.text('124 trips'), findsNWidgets(2));
    expect(find.text('3 trips'), findsNothing);
    final names = find.text('Kavya S.');
    final badges = find.byKey(PublicTripCard.levelKey);
    for (var i = 0; i < 2; i++) {
      expect(t.getRect(badges.at(i)).left, greaterThan(t.getRect(names.at(i)).right));
    }
    expect(t.takeException(), isNull);
  });
}
