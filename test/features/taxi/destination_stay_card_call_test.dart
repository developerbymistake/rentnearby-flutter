import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/taxi/ways/widgets/destination_stay_card.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/real_phone.dart';

StayNearbyModel _stay() => StayNearbyModel(
      id: 's1',
      name: 'Pine View Homestay',
      stayTypeName: 'Homestay',
      latitude: 29.6,
      longitude: 79.6,
      minPricePerNight: 1800,
      distanceKm: 1.2,
      isActive: true,
    );

void main() {
  final dialed = <String>[];
  final routes = <String>[];
  final whatsApped = <String>[];
  String? phone;

  setUp(() {
    dialed.clear();
    routes.clear();
    whatsApped.clear();
    phone = '9876543210';
    ListingContactActions.busy.clear();
    ListingContactActions.debugDeps = ListingContactDeps(
      fetchContact: (kind, id) async => ListingContact(ownerId: 'host', phone: phone),
      currentUserId: () => 'me',
      dial: (p) async => dialed.add(p),
      openWhatsApp: (p, {message}) async => whatsApped.add(p),
      openRoute: (r, a) => routes.add(r),
      info: (_) {},
    );
  });
  tearDown(() => ListingContactActions.debugDeps = null);

  Future<void> pumpCard(WidgetTester t) async {
    await pumpPhone(
      t,
      Scaffold(
        backgroundColor: DesignColors.scaffold,
        body: SafeArea(child: Align(alignment: Alignment.topLeft, child: DestinationStayCard(stay: _stay(), cityName: 'Almora'))),
      ),
      pages: [GetPage(name: AppRoutes.stayDetail, page: () => const Scaffold(body: Text('stay page')))],
    );
    await settlePhone(t);
  }

  testWidgets('the stay card shows Call, never Ask for a room', (t) async {
    await pumpCard(t);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Ask for a room'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Call dials the stay owner and sends no WhatsApp', (t) async {
    await pumpCard(t);
    await t.tap(find.text('Call'));
    await settlePhone(t);
    expect(dialed, ['9876543210']);
    expect(whatsApped, isEmpty);
    expect(find.text('stay page'), findsNothing);
  });

  testWidgets('Call with a hidden phone opens the stay page', (t) async {
    phone = null;
    await pumpCard(t);
    await t.tap(find.text('Call'));
    await settlePhone(t);
    expect(dialed, isEmpty);
    expect(routes, [AppRoutes.stayDetail]);
  });

  testWidgets('tapping the card opens the stay page and does not dial', (t) async {
    await pumpCard(t);
    await t.tap(find.text('Pine View Homestay'));
    await settlePhone(t);
    await t.pump(const Duration(seconds: 1));
    expect(Get.currentRoute, AppRoutes.stayDetail);
    expect(dialed, isEmpty);
    expect(find.text('stay page'), findsOneWidget);
  });
}
