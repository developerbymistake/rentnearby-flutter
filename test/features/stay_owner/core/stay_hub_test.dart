import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_controller.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_screen.dart';
import 'package:bakhli/features/stay_owner/hub/stay_preview_card.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'stay_fixtures.dart';

final _now = DateTime.utc(2026, 11, 22, 10);

StayHubController _hub(Map<String, dynamic>? stay, {MyPlanModel plan = OwnerPlans.free, DateTime? now, Future<Map<String, dynamic>> Function()? fetch}) {
  Get.reset();
  Get.testMode = true;
  Get.put<TabConfigController>(FakeTabs());
  final auth = StayFakeAuth();
  Get.put<AuthController>(auth);
  auth.signIn(role: 'STAY_OWNER', stayStatus: 'Approved');
  PlanGate.debugPlan = plan;
  return Get.put(StayHubController(userId: () => 'user-a', clock: () => now ?? _now, fetch: fetch ?? () async => {'data': stay}), tag: StayHubController.tag);
}

Future<void> _pump(WidgetTester t, StayHubController c, {Size size = const Size(360, 2400), double scale = 1}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, StayHubScreen(root: true, controller: c), size: size, textScale: scale);
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
}

Iterable<String> _texts(WidgetTester t) => t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '');

StayHubController _ctl() => Get.find<StayHubController>(tag: StayHubController.tag);

void main() {
  setUpAll(() => initTestStorage('stay_hub_test'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    OwnerApi.debugReset();
    resetOwnerTestState();
  });

  group('o_st_13 / o_st_14 hub', () {
    testWidgets('o_st_13_free_structureAndOrder', (t) async {
      await _pump(t, _hub(stayJson()));
      final order = ['Rooms and prices', 'Special prices', 'Photos', 'Calendar', 'Stay details', 'Delete stay'];
      final card = find.descendant(of: find.byType(StayPreviewCard), matching: find.byType(Text));
      final inCard = card.evaluate().toSet();
      var last = t.getBottomLeft(find.byType(StayPreviewCard)).dy;
      for (final s in order) {
        final f = find.text(s);
        expect(f, findsWidgets, reason: s);
        final outside = f.evaluate().where((e) => !inCard.contains(e)).toList();
        expect(outside, isNotEmpty, reason: s);
        final y = t.getTopLeft(find.byElementPredicate((e) => e == outside.first)).dy;
        expect(y, greaterThan(last), reason: s);
        last = y;
      }
    });

    testWidgets('o_st_13_noListNoAddStayNoPlanStripNoSwitch', (t) async {
      await _pump(t, _hub(stayJson()));
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Add stay'), findsNothing);
    });

    testWidgets('o_st_13_roomsOneRowOpensRoomsPage_noLockRow', (t) async {
      await _pump(t, _hub(stayJson()));
      expect(find.text('Your rooms'), findsOneWidget);
      expect(find.text('Deluxe Room, Family Room · from ₹3,000'), findsOneWidget);
      expect(find.text('2 rooms'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      for (final gone in ['Edit price', 'Add room type', 'See Plus', 'Share']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    });

    testWidgets('o_st_13_photoAddAtFreeLimitOpensPlusSheet', (t) async {
      await _pump(t, _hub(stayJson()));
      await t.tap(find.text('+ Add'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
    });

    testWidgets('o_st_13_hiddenRoomsLeaveHub_hiddenPhotoKeepsLock', (t) async {
      await _pump(t, _hub(stayJson(hiddenRooms: 1, hiddenPhotos: 1)));
      expect(find.text('Hidden on Free'), findsNothing);
      expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.locked), findsOneWidget);
    });

    testWidgets('PHOTOS-AFTER_hiddenPhotoHasReasonAndDelete', (t) async {
      await _pump(t, _hub(stayJson(hiddenPhotos: 1)));
      expect(find.text('Inactive: the Free plan allows 2 photos.'), findsOneWidget);
      expect(find.text('Choose what stays'), findsOneWidget);
      await t.tap(find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.locked));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Delete this photo?'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
    });

    testWidgets('o_st_13_specialPricesAndDeleteRows', (t) async {
      await _pump(t, _hub(stayJson()));
      expect(find.text('Your special prices'), findsOneWidget);
      expect(find.text('Diwali week · 20% higher'), findsOneWidget);
      expect(find.text('1 set'), findsOneWidget);
      expect(find.text('Remove this listing'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('o_st_13_previewCardThreeParts', (t) async {
      await _pump(t, _hub(stayJson()));
      expect(find.text('Mukteshwar, Nainital · Accepting guests'), findsOneWidget);
      for (final s in ['LIVE', 'Rooms', 'Photos', 'From / night', '₹3,000', 'View']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
    });

    testWidgets('o_st_13_paymentOff_noLocks_guardKeys', (t) async {
      await _pump(t, _hub(stayJson(), plan: OwnerPlans.paymentOff));
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(_texts(t).where((s) => s.contains('Plus') || s.contains('on Free')), isEmpty);
    });

    testWidgets('o_st_13_oldServerNoNewFields_stillRenders', (t) async {
      final j = stayJson()
        ..remove('meters')
        ..remove('hiddenRooms')
        ..remove('hiddenPhotos')
        ..remove('specialPricesRow')
        ..remove('calendarRow')
        ..remove('pendingEdit')
        ..remove('lastEditResult');
      await _pump(t, _hub(j));
      expect(t.takeException(), isNull);
      expect(find.text('Rooms and prices'), findsWidgets);
    });

    testWidgets('o_st_14_plus_noLocks_featuredChip', (t) async {
      await _pump(t, _hub(stayJson(rooms: 4, photos: 6, featured: true, meters: [{'key': 'Photos', 'used': 6, 'limit': 8}, {'key': 'RoomTypes', 'used': 4, 'limit': 6}]), plan: OwnerPlans.plus));
      expect(find.text('★ Featured'), findsWidgets);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.text('6 of 8'), findsWidgets);
      expect(find.text('4 rooms'), findsOneWidget);
    });

    testWidgets('o_st_14_plusFullPhotos_addTileGreyedWithCalmLine', (t) async {
      await _pump(t, _hub(stayJson(photos: 8, meters: [{'key': 'Photos', 'used': 8, 'limit': 8}, {'key': 'RoomTypes', 'used': 2, 'limit': 6}]), plan: OwnerPlans.plus));
      expect(find.text('+ Add'), findsOneWidget);
      final ink = t.widget<InkWell>(find.ancestor(of: find.text('+ Add'), matching: find.byType(InkWell)).first);
      expect(ink.onTap, isNull);
      expect(find.text('8 of 8 · limit reached'), findsOneWidget);
    });
  });

  group('o_st_64 review strips', () {
    testWidgets('o_st_64_a_pendingStripAndRowSubline', (t) async {
      await _pump(t, _hub(stayJson(pendingEdit: {'fields': {'name': 'New Name'}, 'at': '2026-11-21T10:00:00Z'})));
      expect(find.text('Name change sent for review. Travellers still see Deodar Heights Homestay.'), findsOneWidget);
      expect(find.text('Change waiting for review'), findsOneWidget);
    });

    testWidgets('o_st_64_b_approvedStripAndNewName', (t) async {
      await _pump(t, _hub(stayJson(name: 'Deodar Heights Mountain Homestay', lastEditResult: {'result': 'Approved', 'at': '2026-11-21T10:00:00Z', 'fieldsChanged': ['name']})));
      expect(find.text('Your change is live. Name updated to Deodar Heights Mountain Homestay.'), findsOneWidget);
    });

    testWidgets('o_st_64_c_rejectedStripWithReasonAndEditAgain', (t) async {
      await _pump(t, _hub(stayJson(lastEditResult: {'result': 'Rejected', 'reason': 'the name must match your registration', 'at': '2026-11-21T10:00:00Z', 'fieldsChanged': ['name']})));
      expect(find.text('Change not approved: the name must match your registration. Your stay stays live.'), findsOneWidget);
      expect(find.text('Edit again'), findsOneWidget);
    });

    testWidgets('o_st_64_stripGoneAfter7Days_fakeClock', (t) async {
      final j = stayJson(lastEditResult: {'result': 'Rejected', 'reason': 'x', 'at': '2026-11-10T10:00:00Z', 'fieldsChanged': ['name']});
      await _pump(t, _hub(j));
      expect(find.text('Edit again'), findsNothing);
      await _pump(t, _hub(j, now: DateTime.utc(2026, 11, 12)));
      expect(find.text('Edit again'), findsOneWidget);
    });

    testWidgets('o_st_64_newerPendingHidesResult', (t) async {
      await _pump(t, _hub(stayJson(pendingEdit: {'fields': {'name': 'N'}, 'at': '2026-11-21T12:00:00Z'}, lastEditResult: {'result': 'Rejected', 'reason': 'x', 'at': '2026-11-21T10:00:00Z', 'fieldsChanged': ['name']})));
      expect(find.text('Edit again'), findsNothing);
      expect(find.textContaining('sent for review'), findsOneWidget);
    });

    testWidgets('o_st_64_resultReasonMissing_genericLine', (t) async {
      await _pump(t, _hub(stayJson(lastEditResult: {'result': 'Rejected', 'at': '2026-11-21T10:00:00Z', 'fieldsChanged': ['name']})));
      expect(find.text('Change not approved. Your stay stays live.'), findsOneWidget);
    });
  });

  group('o_st_63 delete and empty hub', () {
    testWidgets('o_st_63_emptyHub_noStayYet', (t) async {
      await _pump(t, _hub(null));
      expect(find.text('No stay yet'), findsWidgets);
      expect(find.text('Set up your stay to get enquiries from travellers.'), findsOneWidget);
    });

    testWidgets('o_st_63_confirmDelete_mentionsBookings', (t) async {
      await _pump(t, _hub(stayJson(confirmed: 2)), size: const Size(360, 800));
      await t.ensureVisible(find.text('Delete stay'));
      await t.tap(find.text('Delete stay'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Delete stay?'), findsOneWidget);
      expect(find.textContaining('2 confirmed bookings will be cancelled'), findsOneWidget);
      await t.tap(find.text('Keep'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Delete stay?'), findsNothing);
    });
  });

  group('o_st_67 hub states', () {
    testWidgets('o_st_67_a_hubError_sameView', (t) async {
      await _pump(t, _hub(null, fetch: () async => throw Exception('down')), size: const Size(360, 800));
      expect(find.text('Couldn’t load'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('o_st_67_a_errorWithCopy_keepsCopy', (t) async {
      final c = _hub(null, fetch: () async => throw Exception('down'));
      OwnerCache.write('user-a', OwnerCacheKeys.listing, stayJson());
      Get.delete<StayHubController>(tag: StayHubController.tag, force: true);
      final c2 = Get.put(StayHubController(userId: () => 'user-a', clock: () => _now, fetch: () async => throw Exception('down')), tag: StayHubController.tag);
      expect(c, isNotNull);
      await _pump(t, c2, size: const Size(360, 2400));
      expect(find.text('Rooms and prices'), findsWidgets);
      expect(find.text('Couldn’t load'), findsNothing);
    });
  });

  group('sizes', () {
    testOwnerSizes('hub free', () => StayHubScreen(root: true, controller: _ctl()), setUpEach: () => _hub(stayJson()), arrange: (t) async {
      await t.pump(const Duration(milliseconds: 200));
    });
    testOwnerSizes('hub plus max rows', () => StayHubScreen(root: true, controller: _ctl()), setUpEach: () => _hub(stayJson(rooms: 6, photos: 8, featured: true, meters: [{'key': 'Photos', 'used': 8, 'limit': 8}, {'key': 'RoomTypes', 'used': 6, 'limit': 6}]), plan: OwnerPlans.plus), arrange: (t) async {
      await t.pump(const Duration(milliseconds: 200));
    });
    testOwnerSizes('hub empty', () => StayHubScreen(root: true, controller: _ctl()), setUpEach: () => _hub(null), arrange: (t) async {
      await t.pump(const Duration(milliseconds: 200));
    });
  });
}
