import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/guest/v2/stay_card_actions.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Fake {
  ListingContact? contact;
  ConversationModel? conv;
  Completer<void>? gate;
  final dialed = <String>[];
  final routes = <(String, Object?)>[];
  final created = <(String, String)>[];
  final fetched = <(ListingKind, String)>[];

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
          return conv;
        },
        openRoute: (r, a) => routes.add((r, a)),
        info: (_) {},
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

  testWidgets('Enquiry opens the chat with the host', (tester) async {
    fake.conv = ConversationModel(
      id: 'c1',
      listingType: 'Stay',
      listingId: 's1',
      listingTitle: 'Pine Stay',
      otherPartyId: 'host',
      otherPartyName: 'Host',
      isOwner: false,
      status: 'Active',
      lastMessageAt: DateTime(2026, 11, 13),
      unreadCount: 0,
    );
    await pumpCard(tester);
    await tester.tap(find.text('Enquiry'));
    await tester.pump();
    expect(fake.created, [('Stay', 's1')]);
    expect(fake.routes.single.$1, AppRoutes.chatConversation);
    expect(fake.dialed, isEmpty);
    expect(cardTaps, 0);
  });

  testWidgets('card tap still opens the detail callback', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.text('Pine Stay'));
    await tester.pump();
    expect(cardTaps, 1);
    expect(fake.fetched, isEmpty);
    expect(fake.created, isEmpty);
  });

  testWidgets('cells show busy and ignore taps while a call is starting', (tester) async {
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210');
    fake.gate = Completer<void>();
    await pumpCard(tester);
    await tester.tap(find.text('Call'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.tap(find.text('Enquiry'));
    await tester.pump();
    expect(fake.created, isEmpty);
    fake.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(fake.dialed, ['9876543210']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
