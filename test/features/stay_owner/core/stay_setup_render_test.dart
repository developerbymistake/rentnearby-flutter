import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/stay/setup/stay_basic_details_screen.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_screen.dart';
import 'package:bakhli/features/stay_owner/strings/stay_setup_strings.dart';
import 'package:bakhli/widgets/onboarding_closed_dialog.dart';
import 'package:bakhli/features/stay_owner/live_edit/stay_live_edit_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import 'stay_fixtures.dart';
import 'stay_setup_fixtures.dart';

void main() {
  setUpAll(() => initTestStorage('stay_setup_render'));
  useOwnerRenderScale();
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  Future<void> settle(tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('render o_st_4', (tester) async {
    setupFor(stayModel(draftJson(step1: true, rooms: true)));
    await renderOwnerFrame(tester, 'o_st_4', const StayRoomsScreen(), arrange: settle);
    for (final s in ['Rooms', 'Step 2 of 4', '2 room types on Free. Plus lists up to 6.', 'See Plus', 'Add room type']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
  });

  testWidgets('render o_st_16', (tester) async {
    setupFor(
      stayModel({...stayJson(), 'facilities': ['WiFi', 'Parking', 'HotWater'], 'registrationNumber': 'UDYAM-UK-05-0001234', 'address': 'Sargakhet, Mukteshwar', 'stayTypeId': 't1'}),
      stayStatus: 'Approved',
    );
    await renderOwnerFrame(tester, 'o_st_16', const StayLiveEditScreen(), arrange: settle);
  });

  testWidgets('render o_st_2', (tester) async {
    setupFor(stayModel(draftJson(step1: true)));
    await renderOwnerFrame(tester, 'o_st_2', const StayBasicDetailsScreen(photosOnly: true), arrange: settle);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('render o_st_3', (tester) async {
    setupFor(stayModel(draftJson(step1: true)));
    await renderOwnerFrame(tester, 'o_st_3', const StayBasicDetailsScreen(photosOnly: true), arrange: (t) async {
      await settle(t);
      await t.tap(find.byKey(GateKeys.softRow));
      await settle(t);
    });
  });

  testWidgets('render o_st_5', (tester) async {
    setupFor(stayModel(draftJson(step1: true, rooms: true)));
    await renderOwnerFrame(tester, 'o_st_5', const StayRoomsScreen(), arrange: (t) async {
      await settle(t);
      await t.tap(find.byKey(GateKeys.softRow));
      await settle(t);
    });
  });

  testWidgets('render o_st_65 C', (tester) async {
    setupFor(stayModel(draftJson(step1: true)));
    await renderOwnerFrame(tester, 'o_st_65', const StayBasicDetailsScreen(photosOnly: true), part: 'C', arrange: (t) async {
      await settle(t);
      OnboardingClosedDialog.show(t.element(find.byType(StayBasicDetailsScreen)), body: StaySetupStrings.notOpenBody);
      await settle(t);
    });
  });
}
