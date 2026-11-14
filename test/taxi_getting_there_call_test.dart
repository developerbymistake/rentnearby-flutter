import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_phone.dart';

TaxiBrowseItem _taxi(String id, String name) => TaxiBrowseItem(
      id: id,
      driverName: name,
      vehicleTypeName: 'Innova',
      seats: 7,
      plateDisplay: 'UK 04 TA 1234',
      routeCount: 1,
      matchReversed: false,
      createdAt: DateTime(2030, 1, 1),
    );

void main() {
  final dialed = <String>[];
  final fetched = <String>[];
  final routes = <String>[];

  setUp(() {
    dialed.clear();
    fetched.clear();
    routes.clear();
    ListingContactActions.busy.clear();
    ListingContactActions.debugDeps = ListingContactDeps(
      fetchContact: (kind, id) async {
        fetched.add(id);
        return ListingContact(ownerId: 'driver', phone: '98765$id');
      },
      currentUserId: () => 'me',
      dial: (p) async => dialed.add(p),
      openWhatsApp: (p) async {},
      createConversation: (type, id) async => null,
      openRoute: (r, a) => routes.add(r),
      info: (_) {},
    );
  });
  tearDown(() => ListingContactActions.debugDeps = null);

  Future<void> pumpRows(WidgetTester t, List<TaxiBrowseItem> items, List<String> opened) async {
    await pumpPhone(
      t,
      Scaffold(
        backgroundColor: DesignColors.scaffold,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(children: [
              for (final i in items) TaxiCard(item: i, inLabel: 'Getting there', onOpen: () => opened.add(i.id)),
            ]),
          ),
        ),
      ),
    );
    await settlePhone(t);
  }

  Finder callButtons() => find.byIcon(Icons.call_rounded);

  testWidgets('every taxi row has a Call button on its right, no arrow', (t) async {
    final opened = <String>[];
    await pumpRows(t, [_taxi('1', 'Rakesh Singh'), _taxi('2', 'Sunil Negi')], opened);
    expect(callButtons(), findsNWidgets(2));
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(find.text('Enquiry'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
    for (var i = 0; i < 2; i++) {
      final name = find.text(i == 0 ? 'Rakesh Singh' : 'Sunil Negi');
      expect(t.getCenter(callButtons().at(i)).dx, greaterThan(t.getCenter(name).dx));
      expect(t.getCenter(callButtons().at(i)).dx, greaterThan(250));
    }
  });

  testWidgets('tapping Call dials that driver and does not open the detail', (t) async {
    final opened = <String>[];
    await pumpRows(t, [_taxi('1', 'Rakesh Singh'), _taxi('2', 'Sunil Negi')], opened);
    await t.tap(callButtons().at(1));
    await t.pump();
    await t.pump();
    expect(fetched, ['2']);
    expect(dialed, ['987652']);
    expect(opened, isEmpty);
    expect(routes, isEmpty);
  });

  testWidgets('tapping the rest of the row opens the detail and does not call', (t) async {
    final opened = <String>[];
    await pumpRows(t, [_taxi('1', 'Rakesh Singh')], opened);
    await t.tap(find.text('Rakesh Singh'));
    await t.pump();
    expect(opened, ['1']);
    expect(dialed, isEmpty);
    expect(fetched, isEmpty);
  });
}
