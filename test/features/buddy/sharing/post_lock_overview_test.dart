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
  final later = DateTime.now().toUtc().add(const Duration(hours: 30));
  final passed = DateTime.now().toUtc().subtract(const Duration(hours: 1));

  setUp(() {
    DS.applyApproved();
    opened.clear();
  });
  tearDown(() {
    DS.debugReset();
    TripDeleteFlow.debugReset();
    Get.reset();
  });

  group('rule (pure)', () {
    test('UC39/42 inside 72 h the delete is blocked with the unlock moment; after it, it is free', () {
      final s = aloneBlock();
      final locked = OwnerOverviewSeam.deleteBlock(trip(sharing: s).copyWith(isPublic: true, postUnlocksAt: later), s, ended: false);
      expect(locked, isA<PostLockedBlock>());
      expect(locked!.line, SocialStrings.postLockedLine(later));
      expect(OwnerOverviewSeam.deleteBlock(trip(sharing: s).copyWith(isPublic: true, postUnlocksAt: passed), s, ended: false), isNull);
    });

    test('UC43 a posted trip with other travellers asks to remove them first (count from the sharing block)', () {
      final s = sharedBlock(pending: 0, expenses: _settled);
      final b = OwnerOverviewSeam.deleteBlock(trip(sharing: s).copyWith(isPublic: true), s, ended: false);
      expect(b, isA<MembersFirstBlock>());
      expect((b as MembersFirstBlock).count, 2);
      expect(b.line, 'Remove the other travellers first (2)');
    });

    test('UC43 unpublish-then-delete: a private trip the server marks deleteNeedsAlone still asks to remove the others', () {
      final s = sharedBlock(pending: 0, expenses: _settled);
      final b = OwnerOverviewSeam.deleteBlock(trip(sharing: s).copyWith(deleteNeedsAlone: true), s, ended: false);
      expect(b, isA<MembersFirstBlock>());
    });

    test('a never-posted private trip with travellers deletes as before (rule is for posted trips)', () {
      final s = sharedBlock(pending: 0, expenses: _settled);
      expect(OwnerOverviewSeam.deleteBlock(trip(sharing: s), s, ended: false), isNull);
    });

    test('UC44 an ended trip skips the travellers rule once the 72 hours passed', () {
      final s = sharedBlock(pending: 0, expenses: _settled);
      expect(OwnerOverviewSeam.deleteBlock(trip(sharing: s).copyWith(isPublic: true, postUnlocksAt: passed), s, ended: true), isNull);
      expect(OwnerOverviewSeam.deleteBlock(trip(sharing: s).copyWith(isPublic: true), s, ended: true), isNull);
    });

    test('safety review 2: an ended trip inside the 72 hours is still locked (trip dates can be edited)', () {
      final s = sharedBlock(pending: 0, expenses: _settled);
      final b = OwnerOverviewSeam.deleteBlock(trip(sharing: s).copyWith(isPublic: true, postUnlocksAt: later), s, ended: true);
      expect(b, isA<PostLockedBlock>());
      expect((b! as PostLockedBlock).unlocksAt, later);
    });
  });

  group('overview menu', () {
    testWidgets('UC39 locked: Delete trip stays visible, greyed with the unlock line; a tap explains and never deletes', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()));
      registerFakes(members: api);
      final s = aloneBlock();
      await _pump(t, overview(trip(sharing: s).copyWith(isPublic: true, postUnlocksAt: later), s));
      await _openMenu(t);
      expect(find.text('Delete trip'), findsOneWidget);
      expect(find.text(SocialStrings.postLockedLine(later)), findsOneWidget);
      await _tapText(t, 'Delete trip');
      expect(find.text(SocialStrings.postLockedTitle), findsOneWidget);
      expect(find.text('${SocialStrings.postLockedLine(later)}.'), findsOneWidget);
      expect(find.text('Delete this trip?'), findsNothing);
      expect(api.deletes, 0);
      expect(t.takeException(), isNull);
    });

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

    testWidgets('unlocked and alone: the normal red Delete trip (missing fields never block)', (t) async {
      final s = sharedBlock(pending: 0, expenses: _settled);
      registerFakes(members: FakeMembersApi(membersResult: BuddyOk(membersSample())));
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      expect(find.text('Delete trip'), findsOneWidget);
      expect(find.textContaining('You can remove this post'), findsNothing);
      expect(find.textContaining('Remove the other travellers'), findsNothing);
    });

    testWidgets('a late PostLocked refusal (clock skew) closes the confirm and explains with the server moment', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))
        ..deleteResult = BuddyRefused<void>(type: 'PostLocked', statusCode: 409, data: {'unlocksAt': later.toIso8601String()});
      registerFakes(members: api);
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Delete');
      expect(api.deletes, 1);
      expect(find.text('Delete this trip?'), findsNothing);
      expect(find.text(SocialStrings.postLockedTitle), findsOneWidget);
      expect(find.text('${SocialStrings.postLockedLine(later)}.'), findsOneWidget);
    });

    testWidgets('UC43 unpublish-then-delete: a RemoveMembersFirst refusal shows the members box', (t) async {
      final api = FakeMembersApi(membersResult: BuddyOk(membersSample()))
        ..deleteResult = const BuddyRefused<void>(type: 'RemoveMembersFirst', statusCode: 409, data: {'count': 2});
      registerFakes(members: api);
      final s = sharedBlock(pending: 0, expenses: _settled);
      await _pump(t, overview(trip(sharing: s), s));
      await _openMenu(t);
      await _tapText(t, 'Delete trip');
      await _tapText(t, 'Delete');
      expect(find.text(SocialStrings.removeMembersFirstTitle), findsOneWidget);
      expect(find.text('Remove the other travellers first (2).'), findsOneWidget);
    });
  });
}
