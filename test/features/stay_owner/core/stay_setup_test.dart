import 'package:bakhli/design/design.dart';
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
    testWidgets('o_st_4_free2Rooms_normalAddRowStaysEnabled_noBanner', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)), plan: OwnerPlans.free);
      await _pump(t, const StayRoomsScreen());
      expect(find.byKey(GateKeys.softRow), findsOneWidget);
      expect(find.text('Add another room'), findsOneWidget);
      expect(find.text('2 room types on Free. Plus lists up to 6.'), findsNothing);
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

  group('C3 rooms and prices page (manage mode)', () {
    Map<String, dynamic> withRooms(int n, {List<Map<String, dynamic>> hidden = const []}) => {
          ...draftJson(step1: true, rooms: true, rules: true, status: 'Approved'),
          'rooms': [
            for (var i = 0; i < n; i++) {'id': 'r$i', 'roomIndex': i + 1, 'roomName': ['Deluxe', 'Family Room', 'Standard', 'Suite', 'Cottage', 'Dormitory'][i], 'pricePerNight': 3000 + i * 500, 'maxGuests': 3, 'meals': 'Breakfast'},
          ],
          'hiddenRooms': hidden,
        };

    GradientPillButton addButton(WidgetTester t) => t.widget<GradientPillButton>(find.widgetWithText(GradientPillButton, 'Add room type'));

    testWidgets('free 2 of 2: header, strip, one card per room with 3 pills, Add opens the Plus sheet', (t) async {
      setupFor(stayModel(withRooms(2)), plan: OwnerPlans.free, stayStatus: 'Approved');
      await _pump(t, const StayRoomsScreen(manage: true), size: const Size(360, 1200));
      expect(find.text('Rooms and prices'), findsOneWidget);
      expect(find.text('2 of 2 room types used'), findsOneWidget);
      expect(find.byKey(GateKeys.planStrip), findsOneWidget);
      expect(find.text('2 room types on Free. Plus lists up to 6.'), findsOneWidget);
      expect(find.text('ROOM 1'), findsOneWidget);
      expect(find.text('ROOM 2'), findsOneWidget);
      expect(find.text('Edit price'), findsNWidgets(2));
      expect(find.text('Edit room'), findsNWidgets(2));
      expect(find.text('Delete'), findsNWidgets(2));
      expect(find.text('Save'), findsNothing);
      expect(addButton(t).enabled, isTrue);
      await t.tap(find.text('Add room type'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
    });

    testWidgets('free 1 of 2: Add opens the room form, no sheet', (t) async {
      setupFor(stayModel(withRooms(1)), plan: OwnerPlans.free, stayStatus: 'Approved');
      await _pump(t, const StayRoomsScreen(manage: true), size: const Size(360, 1400));
      await t.tap(find.text('Add room type'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(GateKeys.sheet), findsNothing);
      expect(find.text('Room Type'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('plus 6 of 6: no strip, Add greyed with the limit line', (t) async {
      setupFor(stayModel(withRooms(6)), plan: OwnerPlans.plus, stayStatus: 'Approved');
      await _pump(t, const StayRoomsScreen(manage: true), size: const Size(360, 2400));
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(find.text('6 of 6 room types used'), findsOneWidget);
      expect(addButton(t).enabled, isFalse);
      expect(find.text('6 of 6 · limit reached'), findsOneWidget);
    });

    testWidgets('after Plus: a hidden room is an INACTIVE card, edits greyed, Delete and Choose what stays', (t) async {
      setupFor(
        stayModel(withRooms(2, hidden: [{'id': 'h1', 'roomIndex': 1001, 'roomName': 'Suite', 'pricePerNight': 6000, 'maxGuests': 4, 'meals': 'Breakfast'}])),
        plan: OwnerPlans.free,
        stayStatus: 'Approved',
      );
      await _pump(t, const StayRoomsScreen(manage: true), size: const Size(360, 1600));
      expect(find.byKey(GateKeys.inactiveRow), findsOneWidget);
      expect(find.text('Inactive: the Free plan allows 2 room types.'), findsOneWidget);
      expect(find.text('ROOM 3'), findsOneWidget);
      final inactive = find.byKey(GateKeys.inactiveRow);
      expect(find.descendant(of: inactive, matching: find.text('INACTIVE')), findsOneWidget);
      expect(find.descendant(of: inactive, matching: find.text('Inactive: the Free plan allows 2 room types.')), findsOneWidget);
      expect(find.descendant(of: inactive, matching: find.text('Delete')), findsOneWidget);
      for (final label in ['Edit price', 'Edit room']) {
        final pill = find.descendant(of: inactive, matching: find.widgetWithText(WhitePillButton, label));
        expect(t.widget<WhitePillButton>(pill).enabled, isFalse, reason: label);
      }
      expect(find.text('Choose what stays'), findsOneWidget);
    });

    testWidgets('setup mode is unchanged: no manage header or strip', (t) async {
      setupFor(stayModel(withRooms(2)), plan: OwnerPlans.free);
      await _pump(t, const StayRoomsScreen());
      expect(find.text('Rooms and prices'), findsNothing);
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(find.text('Edit price'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('o_st_2 / o_st_3 photos and G5', () {
    testWidgets('o_st_2_free2Photos_normalAddTileOpensPlus_noBanner', (t) async {
      setupFor(stayModel(draftJson(step1: true)), plan: OwnerPlans.free);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true));
      expect(find.byKey(GateKeys.softRow), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Free plan allows 2 photos. Plus stays can show 8.'), findsNothing);
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
