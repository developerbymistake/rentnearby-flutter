import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/guest/v2/stay_card_actions.dart';
import 'package:bakhli/utils/contact_message.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const ContactCustomer asha = (name: 'Asha', phone: '9876543210');

class _Fake {
  ListingContact? contact;
  Completer<void>? gate;
  final dialed = <String>[];
  final routes = <(String, Object?)>[];
  final fetched = <(ListingKind, String)>[];
  final whatsApped = <(String, String?)>[];

  ListingContactDeps get deps => ListingContactDeps(
        fetchContact: (kind, id) async {
          fetched.add((kind, id));
          if (gate != null) await gate!.future;
          return contact;
        },
        currentUserId: () => 'me',
        dial: (p) async => dialed.add(p),
        openRoute: (r, a) => routes.add((r, a)),
        info: (_) {},
        openWhatsApp: (p, {message}) async => whatsApped.add((p, message)),
        customer: () => asha,
      );
}

void main() {
  late _Fake fake;
  late int cardTaps;

  setUp(() {
    fake = _Fake();
    cardTaps = 0;
    ListingContactActions.debugDeps = fake.deps;
    ListingContactActions.busy.clear();
  });

  tearDown(() => ListingContactActions.debugDeps = null);

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => Obx(
                () => WideCard(
                  tone: ListingTone.forest,
                  kind: WideKind.photo,
                  title: 'Pine Stay',
                  subtitle: 'Manali',
                  actions: stayContactActions(context, 's1'),
                  onTap: () => cardTaps++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Call dials the visible host phone', (tester) async {
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210');
    await pumpCard(tester);
    await tester.tap(find.text('Call'));
    await tester.pump();
    expect(fake.fetched, [(ListingKind.stay, 's1')]);
    expect(fake.dialed, ['9876543210']);
    expect(fake.routes, isEmpty);
    expect(cardTaps, 0);
  });

  testWidgets('Call with a hidden phone opens the stay detail', (tester) async {
    fake.contact = const ListingContact(ownerId: 'host');
    await pumpCard(tester);
    await tester.tap(find.text('Call'));
    await tester.pump();
    expect(fake.dialed, isEmpty);
    expect(fake.routes.single.$1, AppRoutes.stayDetail);
    expect(fake.routes.single.$2, {'id': 's1'});
  });

  testWidgets('card shows Call and WhatsApp, no Enquiry', (tester) async {
    await pumpCard(tester);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Enquiry'), findsNothing);
  });

  testWidgets('WhatsApp opens the host number with the stay message', (tester) async {
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210', title: 'Pine Stay');
    await pumpCard(tester);
    await tester.tap(find.byKey(stayWhatsAppKey));
    await tester.pump();
    expect(fake.whatsApped, [('9876543210', ContactMessage.stay(stayName: 'Pine Stay', customer: asha))]);
    expect(fake.whatsApped.single.$2, contains('Name: Asha'));
    expect(fake.routes, isEmpty);
    expect(fake.dialed, isEmpty);
    expect(cardTaps, 0);
  });

  testWidgets('WhatsApp with a hidden phone opens the stay detail', (tester) async {
    fake.contact = const ListingContact(ownerId: 'host');
    await pumpCard(tester);
    await tester.tap(find.byKey(stayWhatsAppKey));
    await tester.pump();
    expect(fake.whatsApped, isEmpty);
    expect(fake.routes.single.$1, AppRoutes.stayDetail);
    expect(fake.routes.single.$2, {'id': 's1'});
  });

  testWidgets('card tap still opens the detail callback', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.text('Pine Stay'));
    await tester.pump();
    expect(cardTaps, 1);
    expect(fake.fetched, isEmpty);
  });

  testWidgets('cells show busy and ignore taps while a call is starting', (tester) async {
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210');
    fake.gate = Completer<void>();
    await pumpCard(tester);
    await tester.tap(find.text('Call'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.tap(find.byKey(stayWhatsAppKey));
    await tester.pump();
    expect(fake.whatsApped, isEmpty);
    fake.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(fake.dialed, ['9876543210']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
