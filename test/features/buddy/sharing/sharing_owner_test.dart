import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/controllers/owner_sharing_controller.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/sharing/screens/invite_people_screen.dart';
import 'package:bakhli/features/buddy/sharing/screens/travellers_owner_screen.dart';
import 'package:bakhli/features/buddy/sharing/sharing_strings.dart';
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
    testWidgets('alone: header, trip line, progress status and the two new cards', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock()));
      expect(find.text('Your plan is saved'), findsOneWidget);
      expect(find.text('3 cities · 7 days · 1 traveller'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Plan progress, 100 percent\. All set\. Invite your friends\.')), findsOneWidget);
      expect(find.text('Invite travellers'), findsOneWidget);
      expect(find.text('Invite your friends on this trip'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
      expect(find.text('Trip expenses'), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview_traveller_dots')), findsNothing);
      expect(find.bySemanticsLabel('Invite travellers, Invite'), findsOneWidget);
      expect(find.bySemanticsLabel('Trip expenses, Add expense'), findsOneWidget);
    });

    testWidgets('progress status stays the old one below 100 percent', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock(), parts: TripParts.saved));
      expect(find.bySemanticsLabel(RegExp('All set. Invite your friends.')), findsNothing);
    });

    for (final size in const [Size(360, 800), Size(392, 800), Size(412, 915)]) {
      testWidgets('the trip card and five cards fill the screen down to the bottom button at $size', (t) async {
        t.view.devicePixelRatio = 2;
        t.view.physicalSize = size * 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(app(overview(trip(sharing: aloneBlock()), aloneBlock())));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        final last = t.getRect(find.byKey(const ValueKey('overview_expenses_card')));
        final bar = t.getRect(find.ancestor(of: find.byKey(const ValueKey('overview_done_button')), matching: find.byType(DecoratedBox)).first);
        expect(last.height, greaterThanOrEqualTo(DS.s(100) - 0.5));
        if (size.height > 900) expect(last.height, greaterThan(DS.s(100) + 0.5));
        if (last.height > DS.s(100) + 0.5) expect(bar.top - last.bottom, closeTo(DS.s(16), 1));
      });
    }

    testWidgets('Invite tap anywhere on the card opens the flow', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock(), spotCount: 0), aloneBlock()));
      await t.tap(find.byKey(const ValueKey('overview_travellers_card')));
      await _settle(t);
      expect(find.text('Add places to the plan first.'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('Invite on a trip without places shows the toast', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock(), spotCount: 0), aloneBlock()));
      await _tapText(t, 'Invite');
      expect(find.text('Add places to the plan first.'), findsOneWidget);
      expect(find.text('Invite to this trip'), findsNothing);
      await _drain(t);
    });

    testWidgets('Invite opens the invite page', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock()));
      await _tapText(t, 'Invite');
      expect(opened.last.$1, AppRoutes.tripInvitePeople);
      expect(opened.last.$2, {'tripId': tripId});
    });

    testWidgets('Add expense opens the expenses page without opening the sheet', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock()), aloneBlock()));
      await _tapText(t, 'Add expense');
      expect(opened.last.$1, AppRoutes.tripExpenses);
      expect(opened.last.$2, {'tripId': tripId});
    });

    testWidgets('Expenses is off until the itinerary has places', (t) async {
      await _pump(t, overview(trip(sharing: aloneBlock(), spotCount: 0), aloneBlock()));
      opened.clear();
      await t.tap(find.byKey(const ValueKey('overview_expenses_card')), warnIfMissed: false);
      await _settle(t);
      expect(opened, isEmpty);
      final dim = t.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('overview_expenses_card')), matching: find.byType(Opacity)).first);
      expect(dim.opacity, 0.5);
    });

    testWidgets('an old server without sharing keeps the screen as today', (t) async {
      await _pump(t, overview(trip(), null));
      expect(find.text('Invite travellers'), findsNothing);
      expect(find.text('Trip expenses'), findsNothing);
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
      expect(find.byKey(const ValueKey('overview_trip_name')), findsOneWidget);
      expect(find.text('Invite travellers'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview_traveller_dots')), findsOneWidget);
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
      await t.tap(find.byKey(const ValueKey('overview_expenses_card')));
      await _settle(t);
      expect(opened.last.$1, AppRoutes.tripExpenses);
    });

    testWidgets('View after the end: open payments -> settle up, settled -> summary', (t) async {
      final ended = DateTime.now().subtract(const Duration(days: 3));
      final open = sharedBlock(expenses: const TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, openPayments: 1, settled: false));
      await _pump(t, overview(trip(sharing: open, endDate: ended), open));
      expect(find.text('Spent ₹32,300 · 1 payment open'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('overview_expenses_card')));
      await _settle(t);
      expect(opened.last.$1, AppRoutes.tripSettle);
      Get.back();
      await _settle(t);
      final done = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: done, endDate: ended), done));
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('Spent ₹32,300 · All settled'), findsOneWidget);
      expect(find.text('3 joined'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('overview_expenses_card')));
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
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    testWidgets('I-3: a running trip with joined travellers cannot be deleted until they are removed or have left', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(members: api);
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      expect(find.text('Remove the other travellers first (2)'), findsOneWidget);
      await _tapText(t, 'Delete trip');
      expect(find.text('Delete this trip?'), findsNothing);
      expect(find.text('Other travellers are on this trip'), findsOneWidget);
      expect(find.text('Remove the travellers or wait until they leave, then delete.'), findsOneWidget);
      expect(api.deletes, 0);
    });

    testWidgets('open payments show Settle up first with every open line', (t) async {
      registerFakes(ledger: FakeLedgerApi(BuddyOk(balancesSample())), members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
      final s = formerBlock();
      await _pump(t, overview(trip(sharing: s, endDate: yesterday), s));
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
      final s = formerBlock();
      await _pump(t, overview(trip(sharing: s, endDate: yesterday), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Close');
      expect(find.text('Settle up first'), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('owner alone, nothing open: confirm names the travellers the server lists, Delete deletes once', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(members: api);
      var tripsOpened = 0;
      TripDeleteFlow.debugOpenTrips = () => tripsOpened++;
      final s = formerBlock(expenses: _settled);
      await _pump(t, overview(trip(sharing: s, endDate: yesterday), s));
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
      final s = formerBlock(expenses: _settled);
      await _pump(t, overview(trip(sharing: s, endDate: yesterday), s));
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
      final s = formerBlock(expenses: _settled);
      await _pump(t, overview(trip(sharing: s, endDate: yesterday), s));
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
      final s = formerBlock(expenses: _settled);
      await _pump(t, overview(trip(sharing: s, endDate: yesterday), s));
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

  group('invite page 3.2 / 3.4 / 3.12b', () {
    Widget host() => Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: TextButton(onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const InvitePeopleScreen(tripId: tripId))), child: const Text('open')),
            ),
          ),
        );

    Future<void> open(WidgetTester t) async {
      await _pump(t, host());
      await t.tap(find.text('open'));
      await _settle(t);
    }

    FakeMembersApi api(List<InviteCandidate> people, {TripMembers? members, String? next, List<InviteCandidate> more = const []}) {
      final a = FakeMembersApi(
        membersResult: BuddyOk(members ?? membersSample()),
        candidatePages: {null: BuddyOk(candidates(people, next: next)), if (next != null) next: BuddyOk(candidates(more))},
      );
      registerFakes(members: a);
      return a;
    }

    testWidgets('lists people I follow, buddies with a star, ticks, sends, back to the plan with the toast', (t) async {
      final a = api([follow(aman, 'Aman', 'Bakhli#61408275', isBuddy: true), follow(neha, 'Neha', 'Bakhli#73019462')]);
      await open(t);
      expect(find.text('Invite to this trip'), findsOneWidget);
      expect(find.text('They join as viewers after they accept.'), findsOneWidget);
      expect(find.text('Bakhli#61408275'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite_star_$aman')), findsOneWidget);
      expect(find.byKey(const ValueKey('invite_star_$neha')), findsNothing);
      expect(find.text('People you follow are listed here. Buddies have a star.'), findsOneWidget);
      expect(find.text('Send invites'), findsOneWidget);
      expect(find.text('Back to plan'), findsOneWidget);
      await t.tap(find.byKey(InvitePeopleScreen.sendKey));
      await _settle(t);
      expect(a.invites, isEmpty);
      await _tapText(t, 'Neha');
      expect(find.text('Send invites (1)'), findsOneWidget);
      await _tapText(t, 'Neha');
      expect(find.text('Send invites'), findsOneWidget);
      await _tapText(t, 'Neha');
      await _tapText(t, 'Send invites (1)');
      expect(a.invites.single, [neha]);
      expect(find.text('Invite to this trip'), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Invite sent to Neha'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('My buddies ticks every buddy at once and unticks them again', (t) async {
      api([
        follow(aman, 'Aman', 'Bakhli#61408275', isBuddy: true),
        follow(priya, 'Priya', 'Bakhli#50267139', isBuddy: true, state: 'Joined'),
        follow(vikram, 'Vikram', 'Bakhli#19053382', isBuddy: true),
        follow(neha, 'Neha', 'Bakhli#73019462'),
      ]);
      await open(t);
      expect(find.byKey(InvitePeopleScreen.myBuddiesKey), findsOneWidget);
      await t.tap(find.byKey(InvitePeopleScreen.myBuddiesKey));
      await _settle(t);
      expect(find.text('Send invites (2)'), findsOneWidget);
      await _tapText(t, 'Neha');
      expect(find.text('Send invites (3)'), findsOneWidget);
      await t.tap(find.byKey(InvitePeopleScreen.myBuddiesKey));
      await _settle(t);
      expect(find.text('Send invites (1)'), findsOneWidget);
    });

    testWidgets('no buddies in the list: no My buddies row', (t) async {
      api([follow(neha, 'Neha', 'Bakhli#73019462')]);
      await open(t);
      expect(find.byKey(InvitePeopleScreen.myBuddiesKey), findsNothing);
      expect(find.text('Neha'), findsOneWidget);
    });

    testWidgets('two invites read Invites sent to 2 people', (t) async {
      api([follow(aman, 'Aman', 'Bakhli#61408275'), follow(neha, 'Neha', 'Bakhli#73019462')]);
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Neha');
      await _tapText(t, 'Send invites (2)');
      expect(find.text('Invites sent to 2 people'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('Back to plan leaves the page without sending', (t) async {
      final a = api([follow(aman, 'Aman', 'Bakhli#61408275')]);
      await open(t);
      await _tapText(t, 'Aman');
      await t.tap(find.byKey(InvitePeopleScreen.backKey));
      await _settle(t);
      expect(a.invites, isEmpty);
      expect(find.text('Invite to this trip'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('invited and joined rows carry badges and cannot be ticked', (t) async {
      api([
        follow(aman, 'Aman', 'Bakhli#61408275', state: 'Joined'),
        follow(neha, 'Neha', 'Bakhli#73019462', state: 'Invited'),
        follow(vikram, 'Vikram', 'Bakhli#19053382'),
      ]);
      await open(t);
      expect(find.text('On this trip'), findsOneWidget);
      expect(find.text('Invite sent'), findsOneWidget);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Neha');
      expect(find.text('Send invites'), findsOneWidget);
    });

    testWidgets('a refused outcome shows Could not invite and keeps the page', (t) async {
      final a = api([follow(aman, 'Aman', 'Bakhli#61408275')])
        ..inviteResult = const BuddyOk(InviteResult(results: [InviteOutcome(userId: aman, outcome: 'NotBuddy')], seatsLeft: 8));
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Send invites (1)');
      expect(a.invites, hasLength(1));
      expect(find.text('Could not invite Aman.'), findsOneWidget);
      expect(find.text('Invite to this trip'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('a new request id after a finished send, same id on a retry', (t) async {
      final a = api([follow(aman, 'Aman', 'Bakhli#61408275')])..inviteResult = const BuddyOffline();
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Send invites (1)');
      expect(find.text('You are offline. Try again when you are back online.'), findsOneWidget);
      await _tapText(t, 'Send invites (1)');
      expect(a.requestIds.toSet().length, 1);
      await _drain(t);
    });

    testWidgets('409 TripFull shows the seats line, 0 seats reads This trip is full', (t) async {
      final a = api([follow(aman, 'Aman', 'Bakhli#61408275'), follow(neha, 'Neha', 'Bakhli#73019462')])
        ..inviteResult = const BuddyRefused(type: 'TripFull', statusCode: 409, data: {'seatsLeft': 1});
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Neha');
      await _tapText(t, 'Send invites (2)');
      expect(find.text('Only 1 seat left. A trip can have up to 12 travellers.'), findsOneWidget);
      a.inviteResult = const BuddyRefused(type: 'TripFull', statusCode: 409, data: {'seatsLeft': 0});
      await _tapText(t, 'Send invites (2)');
      expect(find.text('This trip is full'), findsOneWidget);
    });

    testWidgets('TripCompleted, NoPlaces and 429 toasts', (t) async {
      final a = api([follow(aman, 'Aman', 'Bakhli#61408275')])..inviteResult = const BuddyRefused(type: 'TripCompleted', statusCode: 409);
      await open(t);
      await _tapText(t, 'Aman');
      await _tapText(t, 'Send invites (1)');
      expect(find.text('This trip is complete. Plan changes are off.'), findsOneWidget);
      a.inviteResult = const BuddyRefused(type: 'NoPlaces', statusCode: 400);
      await _tapText(t, 'Send invites (1)');
      expect(find.text('Add places to the plan first.'), findsOneWidget);
      a.inviteResult = const BuddyRefused(type: 'TooManyRequests', statusCode: 429);
      await _tapText(t, 'Send invites (1)');
      expect(find.text('Please try again in a few minutes'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('nobody followed: empty state, Find people opens People on Following', (t) async {
      api(const []);
      await open(t);
      expect(find.text('No one to invite yet'), findsOneWidget);
      expect(find.text('Follow people first, then invite them to your trip.'), findsOneWidget);
      expect(find.byKey(InvitePeopleScreen.sendKey), findsNothing);
      expect(find.byKey(InvitePeopleScreen.backKey), findsOneWidget);
      await _tapText(t, 'Find people');
      expect(opened.last.$1, AppRoutes.people);
      expect((opened.last.$2 as Map)['tab'], 'following');
    });

    testWidgets('few seats: seats line, a tick past the last seat is refused, My buddies stops at the seats', (t) async {
      api(
        [
          follow(neha, 'Neha', 'Bakhli#73019462', isBuddy: true),
          follow(vikram, 'Vikram', 'Bakhli#19053382', isBuddy: true),
          follow(karan, 'Divya', 'Bakhli#64417820', isBuddy: true),
        ],
        members: tenMembers(),
      );
      await open(t);
      expect(find.text('2 seats left'), findsOneWidget);
      await _tapText(t, 'Neha');
      await _tapText(t, 'Vikram');
      await _tapText(t, 'Divya');
      expect(find.text('Send invites (2)'), findsOneWidget);
      expect(find.text('Only 2 seats left. A trip can have up to 12 travellers.'), findsOneWidget);
      await _tapText(t, 'Vikram');
      await _tapText(t, 'Neha');
      expect(find.text('Send invites'), findsOneWidget);
      await t.tap(find.byKey(InvitePeopleScreen.myBuddiesKey));
      await _settle(t);
      expect(find.text('Send invites (2)'), findsOneWidget);
      expect(find.text('Only 2 seats left. A trip can have up to 12 travellers.'), findsOneWidget);
    });

    testWidgets('loads the next page at the end of the list', (t) async {
      final a = api([follow(aman, 'Aman', 'Bakhli#61408275')], next: 'c2', more: [follow(neha, 'Neha', 'Bakhli#73019462')]);
      await open(t);
      expect(a.candidateCursors, [null, 'c2']);
      expect(find.text('Neha'), findsOneWidget);
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

    testWidgets('Invite opens the invite page', (t) async {
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
      await _pump(t, screen(membersSample()));
      await t.tap(find.byKey(const ValueKey('travellers_invite')));
      await _settle(t);
      expect(opened.last.$1, AppRoutes.tripInvitePeople);
      expect(opened.last.$2, {'tripId': tripId});
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
