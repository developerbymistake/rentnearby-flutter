import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_phone.dart';

class _Fake {
  ListingContact? contact;
  Completer<void>? gate;
  final fetched = <(ListingKind, String)>[];
  final dialed = <String>[];
  final routes = <(String, Object?)>[];
  final created = <(String, String)>[];
  final infos = <String>[];

  ListingContactDeps get deps => ListingContactDeps(
        fetchContact: (kind, id) async {
          fetched.add((kind, id));
          if (gate != null) await gate!.future;
          return contact;
        },
        currentUserId: () => 'me',
        dial: (p) async => dialed.add(p),
        createConversation: (type, id) async {
          created.add((type, id));
          return null;
        },
        openRoute: (r, a) => routes.add((r, a)),
        info: infos.add,
      );
}

TaxiBrowseItem _taxi({bool match = true}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Negi',
      vehicleTypeName: 'Sedan',
      seats: 4,
      plateDisplay: 'UK 04 AB 1234',
      routeCount: 3,
      matchedFare: match ? 5200 : null,
      matchedToName: 'Nainital',
      matchedTripType: 'OneWay',
      matchReversed: false,
      createdAt: DateTime(2030, 1, 1),
    );

Future<void> _pump(WidgetTester t, TaxiCard card) async {
  await pumpPhone(
    t,
    Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: SafeArea(child: SingleChildScrollView(child: card)),
    ),
  );
  await settlePhone(t);
}

Future<void> _tap(WidgetTester t, Key key) async {
  await t.ensureVisible(find.byKey(key));
  await t.tap(find.byKey(key));
  await t.pump();
  await t.pump();
}

void main() {
  late _Fake fake;
  late int opened;

  setUp(() {
    fake = _Fake();
    opened = 0;
    ListingContactActions.debugDeps = fake.deps;
    ListingContactActions.busy.clear();
  });

  tearDown(() => ListingContactActions.debugDeps = null);

  testWidgets('browse Call with a visible phone dials the driver', (t) async {
    fake.contact = const ListingContact(ownerId: 'driver', phone: '9876543210');
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () => opened++));
    await _tap(t, TaxiCard.callKey);
    expect(fake.fetched, [(ListingKind.taxi, 't1')]);
    expect(fake.dialed, ['9876543210']);
    expect(fake.routes, isEmpty);
    expect(opened, 0);
  });

  testWidgets('browse Call with a hidden phone opens the detail with the fare', (t) async {
    fake.contact = const ListingContact(ownerId: 'driver');
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () => opened++));
    await _tap(t, TaxiCard.callKey);
    expect(fake.dialed, isEmpty);
    expect(fake.infos, [ListingContactActions.phoneHiddenMessage]);
    expect(fake.routes.single.$1, AppRoutes.taxiDetail);
    expect(fake.routes.single.$2, {'matchedFare': 5200, 'matchedToName': 'Nainital', 'id': 't1'});
  });

  testWidgets('browse Call shows busy while the detail loads', (t) async {
    fake.contact = const ListingContact(ownerId: 'driver', phone: '9876543210');
    fake.gate = Completer<void>();
    await _pump(t, TaxiCard(item: _taxi(match: false), onOpen: () => opened++));
    await _tap(t, TaxiCard.callKey);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.gate!.complete();
    await t.pump();
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(fake.dialed, ['9876543210']);
  });

  testWidgets('browse Enquiry goes through the chat helper, not onOpen', (t) async {
    await _pump(t, TaxiCard(item: _taxi(match: false), onOpen: () => opened++));
    await _tap(t, TaxiCard.enquiryKey);
    expect(opened, 0);
    expect(fake.created, isEmpty);
    expect(fake.routes.single.$1, AppRoutes.taxiDetail);
    expect(fake.routes.single.$2, {'id': 't1'});
  });

  testWidgets('card tap opens the detail', (t) async {
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () => opened++));
    await t.tap(find.text('Ramesh Negi'));
    await t.pump();
    expect(opened, 1);
    expect(fake.fetched, isEmpty);
  });

  testWidgets('trip mode Enquiry still uses onEnquire', (t) async {
    var enquired = 0;
    await _pump(
      t,
      TaxiCard(item: _taxi(), onOpen: () => opened++, onSelect: () {}, onEnquire: () => enquired++),
    );
    expect(find.byKey(TaxiCard.enquiryKey), findsNothing);
    await t.ensureVisible(find.text('Enquiry'));
    await t.tap(find.text('Enquiry'));
    await t.pump();
    expect(enquired, 1);
    expect(fake.created, isEmpty);
    expect(fake.routes, isEmpty);
  });
}
