import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/sharing/screens/invite_people_screen.dart';
import 'package:bakhli/features/buddy/sharing/screens/travellers_owner_screen.dart';
import 'package:bakhli/features/buddy/sharing/widgets/trip_delete_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'sharing_fixtures.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f.last);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _delete(WidgetTester t) async {
  await _tap(t, find.byKey(const ValueKey('overview_menu')));
  await _tap(t, find.text('Delete trip'));
}

Future<void> _render(WidgetTester t, String id, Widget screen, {Future<void> Function(WidgetTester)? arrange}) async {
  final f = await renderFrame(t, id, screen, arrange: arrange);
  expect(t.takeException(), isNull);
  expect(f.existsSync(), isTrue);
  await t.pump(const Duration(seconds: 6));
}

void main() {
  useBuddyRenderScale();
  tearDown(() {
    TripDeleteFlow.debugReset();
    Get.reset();
  });

  testWidgets('3.1 owner overview', (t) async {
    await _render(t, '3.1', overview(trip(sharing: aloneBlock()), aloneBlock()));
  });

  testWidgets('3.2 invite people I follow', (t) async {
    registerFakes(
      members: FakeMembersApi(membersResult: BuddyOk(TripMembers.fromJson({...sample('s1_members_owner'), 'seatsLeft': 11})), candidatePages: {
        null: BuddyOk(candidates([follow(aman, 'Aman', 'Bakhli#61408275', isBuddy: true), follow(neha, 'Neha', 'Bakhli#73019462')])),
      }),
    );
    await _render(t, '3.2', const InvitePeopleScreen(tripId: tripId), arrange: (t) async {
      await _tap(t, find.text('Aman'));
    });
  });

  testWidgets('3.4 invite nobody followed', (t) async {
    registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
    await _render(t, '3.4', const InvitePeopleScreen(tripId: tripId));
  });

  testWidgets('3.11 owner overview shared', (t) async {
    final s = sharedBlock(expenses: const TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, dayToday: 4, openPayments: 2, settled: false));
    await _render(t, '3.11', overview(trip(sharing: s), s));
  });

  testWidgets('3.11a settle up first', (t) async {
    registerFakes(ledger: FakeLedgerApi(BuddyOk(balancesSample())));
    final s = formerBlock(expenses: const TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, dayToday: 4, openPayments: 2, settled: false));
    final ended = DateTime.now().subtract(const Duration(days: 1));
    await _render(t, '3.11a', overview(trip(sharing: s, endDate: ended), s), arrange: _delete);
  });

  testWidgets('3.11b delete confirm', (t) async {
    TripDeleteFlow.debugOpenTrips = () {};
    registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
    final s = formerBlock(expenses: const TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, openPayments: 0, settled: true));
    final ended = DateTime.now().subtract(const Duration(days: 1));
    await _render(t, '3.11b', overview(trip(sharing: s, endDate: ended), s), arrange: _delete);
  });

  testWidgets('3.12 travellers owner', (t) async {
    registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
    await _render(t, '3.12', TravellersOwnerScreen(tripId: tripId, members: membersSample()));
  });

  testWidgets('3.12a trip full', (t) async {
    registerFakes(members: FakeMembersApi(membersResult: BuddyOk(fullMembers())));
    await _render(t, '3.12a', TravellersOwnerScreen(tripId: tripId, members: fullMembers()));
  });

  testWidgets('3.12b invite seats left', (t) async {
    registerFakes(
      members: FakeMembersApi(membersResult: BuddyOk(tenMembers()), candidatePages: {
        null: BuddyOk(candidates([
          follow(neha, 'Neha', 'Bakhli#73019462', isBuddy: true),
          follow(vikram, 'Vikram', 'Bakhli#19053382'),
          follow(karan, 'Divya', 'Bakhli#64417820'),
        ])),
      }),
    );
    await _render(t, '3.12b', const InvitePeopleScreen(tripId: tripId), arrange: (t) async {
      await _tap(t, find.text('Neha'));
      await _tap(t, find.text('Vikram'));
      await _tap(t, find.text('Divya'));
    });
  });

  testWidgets('3.13 remove a traveller', (t) async {
    registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
    await _render(t, '3.13', TravellersOwnerScreen(tripId: tripId, members: membersSample()), arrange: (t) async {
      await _tap(t, find.byKey(const ValueKey('traveller_dots_$aman')));
      await _tap(t, find.text('Remove from trip'));
    });
  });
}
