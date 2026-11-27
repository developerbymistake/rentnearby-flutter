import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/sharing/widgets/owner_overview_seam.dart';
import 'package:bakhli/features/buddy/sharing/widgets/trip_delete_flow.dart';
import 'package:bakhli/features/social/shared/post_removal.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'sharing_fixtures.dart';

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

Future<void> _openMenu(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('overview_menu')));
  await _settle(t);
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).last);
  await t.tap(find.text(text).last);
  await _settle(t);
}

void main() {
  setUp(() {
    DS.applyApproved();
    TripDeleteFlow.debugReset();
    opened.clear();
  });
  tearDown(() {
    DS.debugReset();
    TripDeleteFlow.debugReset();
    Get.reset();
  });

  group('rule (pure)', () {
    test('I-3: no 72-hour lock: a posted trip alone deletes at once', () {
      expect(OwnerOverviewSeam.deleteBlock(aloneBlock()), isNull);
    });

    test('UC43 a posted trip with other travellers asks to remove them first (count from the sharing block)', () {
      final s = sharedBlock(pending: 0, expenses: _settled);
      final b = OwnerOverviewSeam.deleteBlock(s);
      expect(b, isA<MembersFirstBlock>());
      expect((b as MembersFirstBlock).count, 2);
      expect(b.line, 'Remove the other travellers first (2)');
    });

    test('I-3: an ended trip with travellers also asks to remove them first (no ended exemption)', () {
      final s = sharedBlock(pending: 0, expenses: _settled);
      expect(OwnerOverviewSeam.deleteBlock(s), isA<MembersFirstBlock>());
    });

    testWidgets('an ended trip with travellers: Delete greyed with the count', (t) async {
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s, endDate: DateTime.now().subtract(const Duration(days: 3))), s));
      await _openMenu(t);
      expect(find.text('Remove the other travellers first (2)'), findsOneWidget);
    });
  });

  group('overview menu', () {
    testWidgets('UC43 other travellers: Delete greyed with the count; See travellers opens the members page', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(members: api);
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s).copyWith(isPublic: true), s));
      await _openMenu(t);
      expect(find.text('Remove the other travellers first (2)'), findsOneWidget);
      await _tapText(t, 'Delete trip');
      expect(find.text(SocialStrings.removeMembersFirstTitle), findsOneWidget);
      await _tapText(t, SocialStrings.seeTravellers);
      expect(opened.last.$1, AppRoutes.tripTravellers);
      expect(api.deletes, 0);
    });

    testWidgets('alone: the normal red Delete trip, no lock line', (t) async {
      final s = aloneBlock();
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
      await _pump(t, overview(trip(sharing: s).copyWith(isPublic: true), s));
      await _openMenu(t);
      expect(find.text('Delete trip'), findsOneWidget);
      expect(find.textContaining('You can remove this post'), findsNothing);
      expect(find.textContaining('Remove the other travellers'), findsNothing);
    });

    testWidgets('a late RemoveMembersFirst refusal (someone joined meanwhile) shows the members box', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))
        ..deleteResult = const BuddyRefused<void>(type: 'RemoveMembersFirst', statusCode: 409, data: {'count': 2});
      registerFakes(members: api);
      // Alone now but the trip kept shared expenses, so Delete goes through the sharing confirm box that reads the refusal.
      final s = formerBlock(expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Delete');
      expect(find.text(SocialStrings.removeMembersFirstTitle), findsOneWidget);
      expect(find.text('Remove the other travellers first (2).'), findsOneWidget);
    });
  });
}
