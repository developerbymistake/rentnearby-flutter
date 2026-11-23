import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/controllers/owner_sharing_controller.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/sharing/screens/travellers_owner_screen.dart';
import 'package:bakhli/features/buddy/sharing/sharing_strings.dart';
import 'package:bakhli/features/buddy/sharing/widgets/invite_sheet.dart';
import 'package:bakhli/features/buddy/sharing/widgets/overview_expenses_card.dart';
import 'package:bakhli/features/buddy/sharing/widgets/trip_delete_flow.dart';
import 'package:bakhli/features/trip/utils/trip_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'sharing_fixtures.dart';

const _openPayments = TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, dayToday: 4, openPayments: 2, settled: false);
const _settled = TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, openPayments: 0, settled: true);

Future<void> _pump(WidgetTester t, Widget home) async {
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(784, 1600);
  addTearDown(t.view.reset);
  await t.pumpWidget(app(home));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _drain(WidgetTester t) async => t.pump(const Duration(seconds: 6));

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).last);
  await t.tap(find.text(text).last);
  await _settle(t);
}

Future<void> _openMenu(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('overview_menu')));
  await _settle(t);
}

void main() {
  setUp(() {
    DS.applyApproved();
    opened.clear();
  });
  tearDown(() {
    DS.debugReset();
    TripDeleteFlow.debugReset();
    Get.reset();
  });

  test('owner sharing controller reloads on live ticks and keeps the last block on failure', () async {
    var calls = 0;
    BuddyResult<TripSharingBlock?> next = BuddyOk(sharedBlock());
    final c = Get.put(OwnerSharingController('t1', initial: aloneBlock(), fetch: (_) async {
      calls++;
      return next;
    }), tag: 't1');
    BuddyLive.tripView('t1').value++;
    await pumpEventQueue();
    expect(calls, 1);
    expect(c.sharing.value!.viewerCount, 2);
    next = const BuddyOffline();
    BuddyLive.expenses('t1').value++;
    await pumpEventQueue();
    expect(calls, 2);
    expect(c.sharing.value!.viewerCount, 2);
    OwnerSharingController.release('t1');
    expect(OwnerSharingController.of('t1'), isNull);
  });

  group('owner overview 3.1', () {
    testWidgets('alone: header, trip line, progress line and the two new cards', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock()));
      expect(find.text('Your plan is saved'), findsOneWidget);
      expect(find.text('3 cities · 7 days · 1 traveller'), findsOneWidget);
      expect(find.text('All set. Invite your friends.'), findsOneWidget);
      expect(find.text('Travellers'), findsOneWidget);
      expect(find.text('Only you'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview_traveller_dots')), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('progress line stays the old one below 100 percent', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock(), parts: TripParts.saved));
      expect(find.text('All set. Invite your friends.'), findsNothing);
    });

    testWidgets('Invite on a trip without places shows the toast', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock(), spotCount: 0), aloneBlock()));
      await _tapText(t, 'Invite');
      expect(find.text('Add places to the plan first.'), findsOneWidget);
      expect(find.text('Invite to this trip'), findsNothing);
      await _drain(t);
    });

    testWidgets('Invite opens the invite sheet', (t) async {
      registerFakes(
        members: FakeMembersApi(membersResult: BuddyOk(membersSample())),
        buddies: FakeBuddiesApi({null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275')]))}),
      );
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock()));
      await _tapText(t, 'Invite');
      expect(find.text('Invite to this trip'), findsOneWidget);
      expect(find.text('Aman'), findsOneWidget);
    });

    testWidgets('Add expense opens the expenses page without opening the sheet', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock()));
      await _tapText(t, 'Add expense');
      expect(opened.last.$1, AppRoutes.tripExpenses);
      expect(opened.last.$2, {'tripId': tripId});
    });

    testWidgets('an old server without sharing keeps the screen as today', (t) async {
      await _pump(t, overview(trip(), null));
      expect(find.text('Travellers'), findsNothing);
      expect(find.text('Expenses'), findsNothing);
      await _openMenu(t);
      expect(find.text('View plan'), findsOneWidget);
      expect(find.text('Delete trip'), findsNothing);
    });

    testWidgets('dots menu gains Delete trip', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock()));
      await _openMenu(t);
      expect(find.text('View plan'), findsOneWidget);
      expect(find.text('Delete trip'), findsOneWidget);
    });
  });

  group('owner overview 3.11', () {
    testWidgets('shared: subtitle, no progress, live numbers', (t) async {
      final s = sharedBlock();
      await _pump(t, overview(trip(sharing: s), s));
      expect(find.text('Shared with 2 people'), findsOneWidget);
      expect(find.text('3 cities · 7 days · 3 travellers'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview_progress_card')), findsNothing);
      expect(find.text('3 joined · 1 invite waiting'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('Day 4'), findsOneWidget);
      expect(find.text('Spent ₹32,300 · Your share ₹11,618'), findsOneWidget);
      expect(find.text('View'), findsNWidgets(2));
    });

    testWidgets('Manage opens Travellers, View opens expenses while the trip runs', (t) async {
      final s = sharedBlock();
      await _pump(t, overview(trip(sharing: s), s));
      await _tapText(t, 'Manage');
      expect(opened.last.$1, AppRoutes.tripTravellers);
      expect(opened.last.$2, {'tripId': tripId});
      Get.back();
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('overview_expenses_button')));
      await _settle(t);
      expect(opened.last.$1, AppRoutes.tripExpenses);
    });

    testWidgets('View after the end: open payments -> settle up, settled -> summary', (t) async {
      final ended = DateTime.now().subtract(const Duration(days: 3));
      final open = sharedBlock(expenses: const TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, openPayments: 1, settled: false));
      await _pump(t, overview(trip(sharing: open, endDate: ended), open));
      expect(find.text('Spent ₹32,300 · 1 payment open'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('overview_expenses_button')));
      await _settle(t);
      expect(opened.last.$1, AppRoutes.tripSettle);
      Get.back();
      await _settle(t);
      final done = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: done, endDate: ended), done));
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('Spent ₹32,300 · All settled'), findsOneWidget);
      expect(find.text('3 joined'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('overview_expenses_button')));
      await _settle(t);
      expect(opened.last.$1, AppRoutes.tripMoneySummary);
    });

    test('card copy rules', () {
      expect(SharingStrings.sharedWith(1), 'Shared with 1 person');
      expect(SharingStrings.joinedLine(4, 2), '4 joined · 2 invites waiting');
      expect(SharingStrings.joinedLine(3, 0), '3 joined');
      expect(OverviewExpensesCard.lineOf(_openPayments, tripEnded: true), 'Spent ₹32,300 · 2 payments open');
      expect(OverviewExpensesCard.chipOf(_openPayments, tripEnded: false), 'Day 4');
      expect(OverviewExpensesCard.chipOf(TripExpenseCard.none, tripEnded: false), isNull);
      expect(OverviewExpensesCard.lineOf(TripExpenseCard.none, tripEnded: true), 'No expenses yet');
    });
  });

  group('delete trip 3.11a / 3.11b', () {
    testWidgets('open payments show Settle up first with every open line', (t) async {
      registerFakes(ledger: FakeLedgerApi(BuddyOk(balancesSample())), members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
      final s = sharedBlock(pending: 0);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      expect(find.text('Settle up first'), findsOneWidget);
      expect(find.text('Open payments stay with your travellers.'), findsOneWidget);
      expect(find.text('Aman 8275 pays Rahul 1736 · ₹11,816'), findsOneWidget);
      expect(find.text('Priya 7139 pays Rahul 1736 · ₹6,366'), findsOneWidget);
      await _tapText(t, 'Open expenses');
      expect(opened.last.$1, AppRoutes.tripExpenses);
      expect(opened.last.$2, {'tripId': tripId, 'tab': 'balances'});
    });

    testWidgets('Close closes the settle box', (t) async {
      registerFakes(ledger: FakeLedgerApi(BuddyOk(balancesSample())));
      final s = sharedBlock(pending: 0);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Close');
      expect(find.text('Settle up first'), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('nothing open: confirm names the joined viewers, Delete deletes once', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(members: api);
      var tripsOpened = 0;
      TripDeleteFlow.debugOpenTrips = () => tripsOpened++;
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      expect(find.text('Delete this trip?'), findsOneWidget);
      expect(find.text('Aman and Priya will lose the plan and the expenses. This cannot be undone.'), findsOneWidget);
      await _tapText(t, 'Delete');
      expect(api.deletes, 1);
      expect(tripsOpened, 1);
      expect(find.text('Trip deleted'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('Cancel keeps the trip', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(members: api);
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Cancel');
      expect(api.deletes, 0);
      expect(find.text('Delete this trip?'), findsNothing);
    });

    testWidgets('409 TripHasOpenBalances from data.openPayments', (t) async {
      final lines = [
        {
          'from': const MoneyPerson(userId: aman, name: 'Aman', last4: '8275', initial: 'A', isMe: false, status: 'Joined').toJson(),
          'to': const MoneyPerson(userId: rahul, name: 'Rahul', last4: '1736', initial: 'R', isMe: true, status: 'Owner').toJson(),
          'amount': 11816,
          'state': 'Open',
        },
      ];
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))
        ..deleteResult = BuddyRefused<void>(type: 'TripHasOpenBalances', statusCode: 409, data: {'openPayments': lines});
      registerFakes(members: api);
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Delete');
      expect(find.text('Settle up first'), findsOneWidget);
      expect(find.text('Aman 8275 pays Rahul 1736 · ₹11,816'), findsOneWidget);
      await _tapText(t, 'Close');
      expect(api.deletes, 1);
    });

    testWidgets('offline delete shows the offline toast and keeps the box', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))..deleteResult = const BuddyOffline<void>();
      registerFakes(members: api);
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Delete');
      expect(find.text('You are offline. Try again when you are back online.'), findsOneWidget);
      expect(find.text('Delete this trip?'), findsOneWidget);
      await _drain(t);
    });

    test('names in the confirm body', () {
      expect(SharingStrings.deleteBody(['Aman']), startsWith('Aman will lose'));
      expect(SharingStrings.deleteBody(['Aman', 'Priya', 'Neha', 'Vikram']), startsWith('Aman, Priya and 2 others will lose'));
      expect(SharingStrings.deleteBody(['Aman', 'Priya', 'Neha']), startsWith('Aman, Priya and 1 other will lose'));
      expect(TripDeleteFlow.usesPlainDelete(aloneBlock()), isTrue);
      expect(TripDeleteFlow.usesPlainDelete(sharedBlock()), isFalse);
      expect(TripDeleteFlow.usesPlainDelete(null), isTrue);
    });
  });

  group('invite sheet 3.2 / 3.4 / 3.12b', () {
    Widget host() => Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => InviteSheet.show(c, tripId), child: const Text('open')))));

    Future<void> open(WidgetTester t) async {
      await _pump(t, host());
      await t.tap(find.text('open'));
      await _settle(t);
    }

    testWidgets('lists buddies, ticks, sends, closes with the snack', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(
        members: api,
        buddies: FakeBuddiesApi({null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275'), buddy(neha, 'Neha', 'Bakhli#73019462')]))}),
      );
      await open(t);
      expect(find.text('Invite to this trip'), findsOneWidget);
      expect(find.text('They join as viewers after they accept.'), findsOneWidget);
      expect(find.text('Bakhli#61408275'), findsOneWidget);
      expect(find.text('Only your buddies are listed here. To invite someone else, add them as a buddy first.'), findsOneWidget);
      expect(find.text('Send invite'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('invite_send')));
      await _settle(t);
      expect(api.invites, isEmpty);
      await _tapText(t, 'Aman');
      expect(find.text('Send invite (1)'), findsOneWidget);
      await _tapText(t, 'Aman');
      expect(find.text('Send invite'), findsOneWidget);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Send invite (1)');
      expect(api.invites.single, [aman]);
      expect(find.text('Invite to this trip'), findsNothing);
      expect(find.text('Invite sent to Aman'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('two invites read Invites sent to 2 buddies', (t) async {
      registerFakes(
        members: FakeMembersApi(membersResult: BuddyOk(membersSample())),
        buddies: FakeBuddiesApi({null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275'), buddy(neha, 'Neha', 'Bakhli#73019462')]))}),
      );
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Neha');
      await _tapText(t, 'Send invite (2)');
      expect(find.text('Invites sent to 2 buddies'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('invited and joined rows carry badges and cannot be ticked', (t) async {
      registerFakes(
        members: FakeMembersApi(membersResult: BuddyOk(membersSample())),
        buddies: FakeBuddiesApi({
          null: BuddyOk(buddyList([
            buddy(aman, 'Aman', 'Bakhli#61408275', state: 'Joined'),
            buddy(neha, 'Neha', 'Bakhli#73019462', state: 'Invited'),
            buddy(vikram, 'Vikram', 'Bakhli#19053382'),
          ])),
        }),
      );
      await open(t);
      expect(find.text('On this trip'), findsOneWidget);
      expect(find.text('Invite sent'), findsOneWidget);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Neha');
      expect(find.text('Send invite'), findsOneWidget);
    });

    testWidgets('NotBuddy outcome shows Could not invite and keeps the sheet', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))
        ..inviteResult = const BuddyOk(InviteResult(results: [InviteOutcome(userId: aman, outcome: 'NotBuddy')], seatsLeft: 8));
      registerFakes(members: api, buddies: FakeBuddiesApi({null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275')]))}));
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Send invite (1)');
      expect(find.text('Could not invite Aman.'), findsOneWidget);
      expect(find.text('Invite to this trip'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('a new request id after a finished send, same id on a retry', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))..inviteResult = const BuddyOffline();
      registerFakes(members: api, buddies: FakeBuddiesApi({null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275')]))}));
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Send invite (1)');
      expect(find.text('You are offline. Try again when you are back online.'), findsOneWidget);
      await _tapText(t, 'Send invite (1)');
      expect(api.requestIds.toSet().length, 1);
      await _drain(t);
    });

    testWidgets('409 TripFull shows the seats line, 0 seats reads This trip is full', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))
        ..inviteResult = const BuddyRefused(type: 'TripFull', statusCode: 409, data: {'seatsLeft': 1});
      registerFakes(members: api, buddies: FakeBuddiesApi({null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275'), buddy(neha, 'Neha', 'Bakhli#73019462')]))}));
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Neha');
      await _tapText(t, 'Send invite (2)');
      expect(find.text('Only 1 seat left. A trip can have up to 12 travellers.'), findsOneWidget);
      api.inviteResult = const BuddyRefused(type: 'TripFull', statusCode: 409, data: {'seatsLeft': 0});
      await _tapText(t, 'Send invite (2)');
      expect(find.text('This trip is full'), findsOneWidget);
    });

    testWidgets('TripCompleted, NoPlaces and 429 toasts', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))..inviteResult = const BuddyRefused(type: 'TripCompleted', statusCode: 409);
      registerFakes(members: api, buddies: FakeBuddiesApi({null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275')]))}));
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Send invite (1)');
      expect(find.text('This trip is complete. Plan changes are off.'), findsOneWidget);
      api.inviteResult = const BuddyRefused(type: 'NoPlaces', statusCode: 400);
      await _tapText(t, 'Send invite (1)');
      expect(find.text('Add places to the plan first.'), findsOneWidget);
      api.inviteResult = const BuddyRefused(type: 'TooManyRequests', statusCode: 429);
      await _tapText(t, 'Send invite (1)');
      expect(find.text('Please try again in a few minutes'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('no buddies: empty state, Find a buddy opens Buddies on Find', (t) async {
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())), buddies: FakeBuddiesApi({}));
      await open(t);
      expect(find.text('No buddies yet'), findsOneWidget);
      expect(find.text('Add a buddy first, then invite them to your trip.'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite_send')), findsNothing);
      await _tapText(t, 'Find a buddy');
      expect(find.text('Invite to this trip'), findsNothing);
      expect(opened.last.$1, AppRoutes.buddies);
      expect((opened.last.$2 as Map)['tab'], 'find');
    });

    testWidgets('few seats: seats line, a tick past the last seat is refused', (t) async {
      registerFakes(
        members: FakeMembersApi(membersResult: BuddyOk(tenMembers())),
        buddies: FakeBuddiesApi({
          null: BuddyOk(buddyList([buddy(neha, 'Neha', 'Bakhli#73019462'), buddy(vikram, 'Vikram', 'Bakhli#19053382'), buddy(karan, 'Divya', 'Bakhli#64417820')])),
        }),
      );
      await open(t);
      expect(find.text('2 seats left'), findsOneWidget);
      expect(find.text('They join as viewers after they accept.'), findsNothing);
      await _tapText(t, 'Neha');
      await _tapText(t, 'Vikram');
      await _tapText(t, 'Divya');
      expect(find.text('Send invite (2)'), findsOneWidget);
      expect(find.text('Only 2 seats left. A trip can have up to 12 travellers.'), findsOneWidget);
      await _tapText(t, 'Vikram');
      await _tapText(t, 'Divya');
      expect(find.text('Send invite (2)'), findsOneWidget);
      expect(find.text('Only 2 seats left. A trip can have up to 12 travellers.'), findsNothing);
    });

    testWidgets('loads the next page at the end of the list', (t) async {
      final buddies = FakeBuddiesApi({
        null: BuddyOk(buddyList([buddy(aman, 'Aman', 'Bakhli#61408275')], next: 'c2')),
        'c2': BuddyOk(buddyList([buddy(neha, 'Neha', 'Bakhli#73019462')])),
      });
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())), buddies: buddies);
      await open(t);
      expect(buddies.cursors, [null, 'c2']);
      expect(find.text('Neha'), findsOneWidget);
    });

    testWidgets('close button closes', (t) async {
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())), buddies: FakeBuddiesApi({}));
      await open(t);
      await t.tap(find.bySemanticsLabel('Close').last);
      await _settle(t);
      expect(find.text('Invite to this trip'), findsNothing);
    });
  });

  group('travellers owner 3.12 / 3.12a / 3.13', () {
    Widget screen(TripMembers m) => TravellersOwnerScreen(tripId: tripId, members: m);

    testWidgets('joined and invited sections', (t) async {
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
      await _pump(t, screen(membersSample()));
      expect(find.text('Travellers'), findsOneWidget);
      expect(find.text('Uttarakhand Hills Trip'), findsOneWidget);
      expect(find.text('3 of 12 travellers'), findsOneWidget);
      expect(find.text('1 invite waiting'), findsOneWidget);
      expect(find.text('JOINED'), findsOneWidget);
      expect(find.text('Rahul (You)'), findsOneWidget);
      expect(find.text('Bakhli#48291736 · Created the trip'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Bakhli#61408275 · Joined 16 May'), findsOneWidget);
      expect(find.text('Bakhli#50267139 · Joined 18 May'), findsOneWidget);
      expect(find.text('Viewer'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('traveller_dots_$rahul')), findsNothing);
      expect(find.byKey(const ValueKey('traveller_dots_$aman')), findsOneWidget);
      expect(find.text('INVITED'), findsOneWidget);
      expect(find.text('Bakhli#73019462 · Invite sent, waiting'), findsOneWidget);
      expect(find.text('Cancel invite'), findsOneWidget);
      expect(find.text('This trip is full'), findsNothing);
    });

    testWidgets('no invites: INVITED hidden, count line reads joined', (t) async {
      await _pump(t, screen(tenMembers()));
      expect(find.text('INVITED'), findsNothing);
      expect(find.text('10 of 12 travellers'), findsOneWidget);
      expect(find.text('10 joined'), findsOneWidget);
      expect(find.text('+7'), findsOneWidget);
    });

    testWidgets('trip full: grey Invite with the red line, +9 stack', (t) async {
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(fullMembers())));
      await _pump(t, screen(fullMembers()));
      expect(find.text('12 of 12 travellers'), findsOneWidget);
      expect(find.text('11 joined · 1 invite waiting'), findsOneWidget);
      expect(find.text('+9'), findsOneWidget);
      expect(find.text('This trip is full'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('travellers_invite')));
      await _settle(t);
      expect(find.text('Invite to this trip'), findsNothing);
      expect(find.text('Bakhli#30419736 · Joined 18 May'), findsOneWidget);
    });

    testWidgets('Invite opens the sheet', (t) async {
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())), buddies: FakeBuddiesApi({}));
      await _pump(t, screen(membersSample()));
      await t.tap(find.byKey(const ValueKey('travellers_invite')));
      await _settle(t);
      expect(find.text('Invite to this trip'), findsOneWidget);
    });

    testWidgets('Cancel invite removes the row and shows the snack', (t) async {
      final m = membersSample();
      final after = TripMembers(
        tripId: m.tripId,
        title: m.title,
        role: m.role,
        ownerName: m.ownerName,
        travellerCount: 3,
        maxTravellers: 12,
        pendingInvites: 0,
        seatsLeft: 9,
        joined: m.joined,
        invited: const [],
        canInvite: true,
        canLeave: false,
      );
      final api = FakeMembersApi(membersResult: BuddyOk(after));
      registerFakes(members: api);
      await _pump(t, screen(m));
      await _tapText(t, 'Cancel invite');
      expect(api.cancels, [neha]);
      expect(find.text('Neha'), findsNothing);
      expect(find.text('INVITED'), findsNothing);
      expect(find.text('Invite cancelled'), findsOneWidget);
      expect(find.text('3 joined'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('Cancel invite offline and 429 toasts', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))..cancelResult = const BuddyOffline<void>();
      registerFakes(members: api);
      await _pump(t, screen(membersSample()));
      await _tapText(t, 'Cancel invite');
      expect(find.text('You are offline. Try again when you are back online.'), findsOneWidget);
      api.cancelResult = const BuddyRefused<void>(type: 'TooManyRequests', statusCode: 429);
      await _tapText(t, 'Cancel invite');
      expect(find.text('Please try again in a few minutes'), findsOneWidget);
      await _drain(t);
    });

    Future<void> openRemove(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('traveller_dots_$aman')));
      await _settle(t);
      expect(find.text('Remove from trip'), findsOneWidget);
      await _tapText(t, 'Remove from trip');
    }

    testWidgets('remove: box copy with the shared expenses, Remove removes', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(members: api);
      await _pump(t, screen(membersSample()));
      await openRemove(t);
      expect(find.text('Remove Aman from this trip?'), findsOneWidget);
      expect(find.text('Aman shares 6 expenses. They stay as they are. You can still settle with Aman.'), findsOneWidget);
      expect(find.text('Aman will lose the plan. He keeps a page with his share until it is settled.'), findsOneWidget);
      await _tapText(t, 'Remove');
      expect(api.removes, [aman]);
      expect(find.text('Remove Aman from this trip?'), findsNothing);
      expect(find.text('Aman removed'), findsOneWidget);
      expect(api.memberCalls, greaterThanOrEqualTo(1));
      await _drain(t);
    });

    testWidgets('remove: one expense and no expense copy', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))..countResult = const BuddyOk(1);
      registerFakes(members: api);
      await _pump(t, screen(membersSample()));
      await openRemove(t);
      expect(find.text('Aman shares 1 expense. It stays as it is. You can still settle with Aman.'), findsOneWidget);
      await _tapText(t, 'Cancel');
      expect(api.removes, isEmpty);
      api.countResult = const BuddyOk(0);
      await openRemove(t);
      expect(find.byKey(const ValueKey('remove_shares_line')), findsNothing);
      expect(find.text('Aman will lose the plan.'), findsOneWidget);
    });

    testWidgets('remove: NotOnTrip closes, reloads and toasts', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))
        ..removeResult = const BuddyRefused<RemoveResult>(type: 'NotOnTrip', statusCode: 409);
      registerFakes(members: api);
      await _pump(t, screen(membersSample()));
      await openRemove(t);
      await _tapText(t, 'Remove');
      expect(find.text('Remove Aman from this trip?'), findsNothing);
      expect(find.text('Aman is no longer on this trip.'), findsOneWidget);
      expect(api.memberCalls, 1);
      await _drain(t);
    });

    testWidgets('remove offline keeps the box and toasts', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))..removeResult = const BuddyOffline<RemoveResult>();
      registerFakes(members: api);
      await _pump(t, screen(membersSample()));
      await openRemove(t);
      await _tapText(t, 'Remove');
      expect(find.text('Remove Aman from this trip?'), findsOneWidget);
      expect(find.text('You are offline. Try again when you are back online.'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('dots menu opens expenses', (t) async {
      await _pump(t, screen(membersSample()));
      await t.tap(find.byKey(const ValueKey('travellers_menu')));
      await _settle(t);
      await _tapText(t, 'Open expenses');
      expect(opened.last.$1, AppRoutes.tripExpenses);
    });

    testWidgets('trip gone after a reload shows the gone view', (t) async {
      final api = FakeMembersApi(membersResult: const BuddyRefused(type: 'TripNotFound', statusCode: 404));
      registerFakes(members: api);
      await _pump(t, screen(membersSample()));
      await t.tap(find.text('Cancel invite'));
      await _settle(t);
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Rahul (You)'), findsNothing);
      await _drain(t);
    });
  });
}
