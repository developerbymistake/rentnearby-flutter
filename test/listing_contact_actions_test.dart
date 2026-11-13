import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake {
  ListingContact? contact;
  String? me = 'me';
  ConversationModel? conv;
  Completer<void>? gate;
  final dialed = <String>[];
  final routes = <(String, Object?)>[];
  final infos = <String>[];
  final created = <(String, String)>[];
  int fetches = 0;

  ListingContactDeps get deps => ListingContactDeps(
        fetchContact: (kind, id) async {
          fetches++;
          if (gate != null) await gate!.future;
          return contact;
        },
        currentUserId: () => me,
        dial: (p) async => dialed.add(p),
        createConversation: (type, id) async {
          created.add((type, id));
          if (gate != null) await gate!.future;
          return conv;
        },
        openRoute: (r, a) => routes.add((r, a)),
        info: infos.add,
      );
}

ConversationModel _conv() => ConversationModel(
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

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(Builder(builder: (c) {
    ctx = c;
    return const SizedBox();
  }));
  return ctx;
}

void main() {
  late _Fake fake;

  setUp(() {
    fake = _Fake();
    ListingContactActions.debugDeps = fake.deps;
    ListingContactActions.busy.clear();
  });

  tearDown(() => ListingContactActions.debugDeps = null);

  testWidgets('visible phone goes to the launcher', (tester) async {
    final ctx = await _context(tester);
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210');
    final r = await ListingContactActions.call(ctx, kind: ListingKind.stay, id: 's1');
    expect(r, ContactOutcome.dialed);
    expect(fake.dialed, ['9876543210']);
    expect(fake.routes, isEmpty);
  });

  testWidgets('hidden phone falls back to the detail with a short message', (tester) async {
    final ctx = await _context(tester);
    fake.contact = const ListingContact(ownerId: 'host');
    final r = await ListingContactActions.call(ctx, kind: ListingKind.taxi, id: 't1', detailArguments: {'matchedFare': 900});
    expect(r, ContactOutcome.openedDetail);
    expect(fake.dialed, isEmpty);
    expect(fake.infos, [ListingContactActions.phoneHiddenMessage]);
    expect(fake.routes.single.$1, AppRoutes.taxiDetail);
    expect(fake.routes.single.$2, {'matchedFare': 900, 'id': 't1'});
  });

  testWidgets('own listing never dials', (tester) async {
    final ctx = await _context(tester);
    fake.contact = const ListingContact(ownerId: 'me', phone: '9876543210');
    final r = await ListingContactActions.call(ctx, kind: ListingKind.stay, id: 's1');
    expect(r, ContactOutcome.openedDetail);
    expect(fake.dialed, isEmpty);
    expect(fake.infos, isEmpty);
  });

  testWidgets('failed fetch falls back to the detail', (tester) async {
    final ctx = await _context(tester);
    fake.contact = null;
    final r = await ListingContactActions.call(ctx, kind: ListingKind.stay, id: 's1');
    expect(r, ContactOutcome.failed);
    expect(fake.dialed, isEmpty);
    expect(fake.routes.single.$1, AppRoutes.stayDetail);
    expect(fake.routes.single.$2, {'id': 's1'});
  });

  testWidgets('chat creates the conversation and opens the chat', (tester) async {
    final ctx = await _context(tester);
    fake.conv = _conv();
    final r = await ListingContactActions.chat(ctx, kind: ListingKind.stay, id: 's1');
    expect(r, ContactOutcome.chatOpened);
    expect(fake.created, [('Stay', 's1')]);
    expect(fake.routes.single.$1, AppRoutes.chatConversation);
    expect((fake.routes.single.$2 as Map)['conversationId'], 'c1');
  });

  testWidgets('failed chat stays put', (tester) async {
    final ctx = await _context(tester);
    final r = await ListingContactActions.chat(ctx, kind: ListingKind.stay, id: 's1');
    expect(r, ContactOutcome.failed);
    expect(fake.routes, isEmpty);
  });

  testWidgets('taxi chat is not supported and opens the detail', (tester) async {
    final ctx = await _context(tester);
    final r = await ListingContactActions.chat(ctx, kind: ListingKind.taxi, id: 't1');
    expect(ListingContactActions.supportsChat(ListingKind.taxi), isFalse);
    expect(r, ContactOutcome.openedDetail);
    expect(fake.created, isEmpty);
    expect(fake.routes.single.$1, AppRoutes.taxiDetail);
  });

  testWidgets('double tap is ignored while busy', (tester) async {
    final ctx = await _context(tester);
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210');
    fake.gate = Completer<void>();
    final first = ListingContactActions.call(ctx, kind: ListingKind.stay, id: 's1');
    expect(ListingContactActions.isBusy(ListingKind.stay, 's1'), isTrue);
    final second = await ListingContactActions.call(ctx, kind: ListingKind.stay, id: 's1');
    expect(second, ContactOutcome.ignored);
    fake.gate!.complete();
    expect(await first, ContactOutcome.dialed);
    expect(fake.fetches, 1);
    expect(fake.dialed, ['9876543210']);
    expect(ListingContactActions.isBusy(ListingKind.stay, 's1'), isFalse);
  });
}
