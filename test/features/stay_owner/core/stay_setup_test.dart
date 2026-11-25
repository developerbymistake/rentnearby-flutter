import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay/setup/stay_basic_details_screen.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'stay_setup_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _pump(WidgetTester t, Widget screen, {Size size = const Size(360, 1500), double scale = 1}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, screen, size: size, textScale: scale);
  await _settle(t);
}

Iterable<String> _texts(WidgetTester t) => t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '');

void main() {
  setUpAll(() => initTestStorage('stay_setup_test'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  group('o_st_4 / o_st_5 rooms and G6', () {
    testWidgets('o_st_4_free2Rooms_addRowLockedWithChipAndBanner', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)), plan: OwnerPlans.free);
      await _pump(t, const StayRoomsScreen());
      expect(find.byKey(GateKeys.softRow), findsOneWidget);
      expect(find.text('Add room type'), findsOneWidget);
      expect(find.text('2 room types on Free. Plus lists up to 6.'), findsOneWidget);
      final low = _texts(t).map((e) => e.toLowerCase()).toList();
      expect(low, contains('room 1'));
      expect(low, contains('room 2'));
    });

    testWidgets('o_st_4_paymentOff_noLockNoBanner_guardKeys', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)), plan: OwnerPlans.paymentOff);
      await _pump(t, const StayRoomsScreen());
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(_texts(t).where((s) => s.contains('Plus') || s.contains('on Free')), isEmpty);
    });

    testWidgets('o_st_5_sheetTextExact', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)), plan: OwnerPlans.free);
      await _pump(t, const StayRoomsScreen(), size: phoneSize);
      await t.tap(find.byKey(GateKeys.softRow));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text('2 room types on Free'), findsWidgets);
      expect(find.text('Get Plus to list up to 6.'), findsOneWidget);
      expect(find.text('2 room types'), findsOneWidget);
      expect(find.text('6 room types'), findsOneWidget);
      expect(find.text('Plus price'), findsOneWidget);
      expect(find.textContaining('7 days free'), findsOneWidget);
      expect(find.text('See Plus'), findsWidgets);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('o_st_5_noTrial_noSevenDaysFree', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)), plan: OwnerPlans.freeNoTrial);
      await _pump(t, const StayRoomsScreen(), size: phoneSize);
      await t.tap(find.byKey(GateKeys.softRow));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('7 days free'), findsNothing);
      expect(find.textContaining('₹400 / month'), findsOneWidget);
    });

    testWidgets('o_st_5_notNowKeepsRoomsTyped', (t) async {
      final c = setupFor(stayModel(draftJson(step1: true, rooms: true)), plan: OwnerPlans.free);
      await _pump(t, const StayRoomsScreen(), size: phoneSize);
      await t.tap(find.byKey(GateKeys.softRow));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('Not now'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(GateKeys.sheet), findsNothing);
      expect(_texts(t).map((e) => e.toLowerCase()), contains('room 2'));
      expect(c.stay.value!.rooms.length, 2);
    });

    testWidgets('o_st_4_plus6Rooms', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)), plan: OwnerPlans.plus);
      await _pump(t, const StayRoomsScreen());
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.text('Add room type'), findsNothing);
    });
  });

  group('o_st_2 / o_st_3 photos and G5', () {
    testWidgets('o_st_2_free2Photos_thirdTileLockedWithPlusChip', (t) async {
      setupFor(stayModel(draftJson(step1: true)), plan: OwnerPlans.free);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true));
      expect(find.byKey(GateKeys.softRow), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Free plan allows 2 photos. Plus stays can show 8.'), findsOneWidget);
      expect(find.text('Clear day-time photos help guests choose.'), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 15));
    });

    testWidgets('o_st_2_oneOfTwo_noLockNoBanner', (t) async {
      setupFor(stayModel(draftJson(step1: true, photos: 1)), plan: OwnerPlans.free);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true));
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.textContaining('Free plan allows'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 15));
    });

    testWidgets('o_st_2_paymentOff_eightTilesNoLockNoPlusText_guardKeys', (t) async {
      setupFor(stayModel(draftJson(step1: true)), plan: OwnerPlans.paymentOff);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true));
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.text('2 of 8'), findsOneWidget);
      expect(_texts(t).where((s) => s.contains('Plus')), isEmpty);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 15));
    });

    testWidgets('o_st_3_sheetTextExact_withTrial', (t) async {
      setupFor(stayModel(draftJson(step1: true)), plan: OwnerPlans.free);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true), size: phoneSize);
      await t.tap(find.byKey(GateKeys.softRow));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Free plan allows 2 photos'), findsOneWidget);
      expect(find.text('Plus stays can show 8 photos.'), findsOneWidget);
      expect(find.text('2 photos'), findsOneWidget);
      expect(find.text('8 photos'), findsOneWidget);
      expect(find.textContaining('₹400 / month'), findsOneWidget);
      expect(find.textContaining('7 days free'), findsOneWidget);
      await t.tap(find.text('Not now'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(GateKeys.sheet), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 15));
    });

    testWidgets('o_st_3_trialUsed_noSevenDaysFree', (t) async {
      setupFor(stayModel(draftJson(step1: true)), plan: OwnerPlans.freeNoTrial);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true), size: phoneSize);
      await t.tap(find.byKey(GateKeys.softRow));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('7 days free'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 15));
    });
  });

  group('sizes', () {
    testOwnerSizes('rooms free two', () => const StayRoomsScreen(), setUpEach: () => setupFor(stayModel(draftJson(step1: true, rooms: true))), arrange: _settle);
  });
}
