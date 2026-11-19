import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake {
  ListingContact? contact;
  String? me = 'me';
  Completer<void>? gate;
  final dialed = <String>[];
  final routes = <(String, Object?)>[];
  final infos = <String>[];
  final whatsApped = <(String, String?)>[];
  ({String? name, String? phone})? customer = (name: 'Asha Rawat', phone: '9876543210');
  int fetches = 0;

  ListingContactDeps get deps => ListingContactDeps(
        fetchContact: (kind, id) async {
          fetches++;
          if (gate != null) await gate!.future;
          return contact;
        },
        currentUserId: () => me,
        dial: (p) async => dialed.add(p),
        openRoute: (r, a) => routes.add((r, a)),
        info: infos.add,
        openWhatsApp: (p, {message}) async => whatsApped.add((p, message)),
        customer: () => customer,
      );
}

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

  testWidgets('stay WhatsApp sends the stay message', (tester) async {
    final ctx = await _context(tester);
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210', title: 'Pine Stay');
    final r = await ListingContactActions.whatsApp(ctx, kind: ListingKind.stay, id: 's1');
    expect(r, ContactOutcome.whatsAppOpened);
    expect(fake.whatsApped.single.$1, '9876543210');
    expect(fake.whatsApped.single.$2,
        'Hello, I am interested in your stay Pine Stay on Bakhli.\nName: Asha Rawat\nPhone: +91 9876543210\nPlease share availability and price. Thank you.');
  });

  testWidgets('taxi WhatsApp sends the taxi message with the vehicle', (tester) async {
    final ctx = await _context(tester);
    fake.contact = const ListingContact(ownerId: 'driver', phone: '9876543210', whatsApp: '9811122233', title: 'Sedan');
    await ListingContactActions.whatsApp(ctx, kind: ListingKind.taxi, id: 't1');
    expect(fake.whatsApped.single.$1, '9811122233');
    expect(fake.whatsApped.single.$2,
        'Hello, I found your taxi (Sedan) on Bakhli.\nName: Asha Rawat\nPhone: +91 9876543210\nI need a taxi. Please share availability and fare. Thank you.');
  });

  testWidgets('WhatsApp without a customer drops the Name and Phone lines', (tester) async {
    final ctx = await _context(tester);
    fake.customer = null;
    fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210', title: 'Pine Stay');
    await ListingContactActions.whatsApp(ctx, kind: ListingKind.stay, id: 's1');
    expect(fake.whatsApped.single.$2, isNot(contains('Name:')));
    expect(fake.whatsApped.single.$2, isNot(contains('Phone:')));
  });

  testWidgets('own listing never opens WhatsApp', (tester) async {
    final ctx = await _context(tester);
    fake.contact = const ListingContact(ownerId: 'me', phone: '9876543210');
    final r = await ListingContactActions.whatsApp(ctx, kind: ListingKind.stay, id: 's1');
    expect(r, ContactOutcome.openedDetail);
    expect(fake.whatsApped, isEmpty);
    expect(fake.infos, isEmpty);
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
