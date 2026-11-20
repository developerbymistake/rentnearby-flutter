import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/widgets/trip_add_city_card.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_header.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import 'support/engine_rig.dart';
import 'trip_day_plan_screen_test.dart';

const _byBooking = TripPlanLock(
  locked: true,
  reason: TripPlanLockReasons.taxiBookingActive,
  requestId: '7e0a3c92-1d4f-4f5b-c8a3-9b2d5e1f3a44',
);

const _stayId = '5b1d7e20-8c3a-4f61-9d2e-0a4c6b8e1f37';

const _byStay = TripPlanLock(locked: true, reason: TripPlanLockReasons.stayBookingActive, enquiryId: _stayId);

TripEnquiryModel _bookedStay(int day) => TripEnquiryModel.fromJson({
      'id': _stayId,
      'tripId': 't1',
      'kind': 'Stay',
      'listingId': 'l1',
      'listingName': 'Pine Stay',
      'day': day,
      'status': 'ConfirmedByBoth',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  testWidgets('banner_text_for_both_reasons', (t) async {
    await pumpDayPlan(t, dayPlanFixture(), lock: lockedByRequest);
    var banner = find.byKey(TripPlanScreen.lockedBannerKey);
    expect(banner, findsOneWidget);
    expect(find.descendant(of: banner, matching: find.text(TripStringsDayplan.lockedByRequest)), findsOneWidget);
    expect(find.text('Plan is locked while your taxi request is active. Cancel the request to edit.'), findsOneWidget);
    expect(find.text(TripStringsDayplan.viewRequest), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
    Get.reset();
    await pumpDayPlan(t, dayPlanFixture(), lock: _byBooking);
    banner = find.byKey(TripPlanScreen.lockedBannerKey);
    expect(find.descendant(of: banner, matching: find.text(TripStringsDayplan.lockedByBooking)), findsOneWidget);
    expect(find.text('Plan is locked while your booking is active. Cancel the booking to edit.'), findsOneWidget);
    expect(find.text(TripStringsDayplan.viewBooking), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
    Get.reset();
    await pumpDayPlan(t, dayPlanFixture(), lock: _byStay);
    banner = find.byKey(TripPlanScreen.lockedBannerKey);
    expect(find.descendant(of: banner, matching: find.text(TripStringsDayplan.lockedByStay)), findsOneWidget);
    expect(find.text('Plan is locked while your stay booking is active. Cancel the stay booking to edit.'), findsOneWidget);
    expect(find.text(TripStringsDayplan.viewStay), findsOneWidget);
    expect(find.text(TripStringsDayplan.viewRequest), findsNothing);
    expect(find.text(TripStringsDayplan.viewBooking), findsNothing);
  });

  testWidgets('stay_lock_banner_uses_the_server_message', (t) async {
    const server = 'Server says the plan is locked.';
    await pumpDayPlan(t, dayPlanFixture(),
        lock: const TripPlanLock(locked: true, reason: TripPlanLockReasons.stayBookingActive, enquiryId: _stayId, message: server));
    final banner = find.byKey(TripPlanScreen.lockedBannerKey);
    expect(find.descendant(of: banner, matching: find.text(server)), findsOneWidget);
    expect(find.text(TripStringsDayplan.viewStay), findsOneWidget);
  });

  testWidgets('view_stay_opens_the_stay_replies_never_the_taxi_status', (t) async {
    Object? replies;
    var taxi = 0;
    final c = await pumpDayPlan(t, dayPlanFixture(), lock: _byStay, pages: [
      GetPage(name: AppRoutes.tripReplies, page: () {
        replies = Get.arguments;
        return const Scaffold(body: Text('replies'));
      }),
      GetPage(name: AppRoutes.tripTaxiStatus, page: () {
        taxi++;
        return const Scaffold(body: Text('status'));
      }),
    ]);
    c.enquiryList.assignAll([_bookedStay(2)]);
    await t.pump();
    await t.tap(find.byKey(TripPlanScreen.viewButtonKey));
    await t.pumpAndSettle();
    expect(find.text('replies'), findsOneWidget);
    expect(taxi, 0);
    expect(replies, {'tripId': 't1', 'day': 2, 'enquiryId': _stayId});
  });

  testWidgets('taxi_lock_without_request_id_does_not_open_the_status', (t) async {
    var taxi = 0;
    await pumpDayPlan(t, dayPlanFixture(),
        lock: const TripPlanLock(locked: true, reason: TripPlanLockReasons.taxiRequestActive),
        pages: [
          GetPage(name: AppRoutes.tripTaxiStatus, page: () {
            taxi++;
            return const Scaffold(body: Text('status'));
          }),
        ]);
    expect(find.text(TripStringsDayplan.viewRequest), findsOneWidget);
    await t.tap(find.byKey(TripPlanScreen.viewButtonKey));
    await t.pumpAndSettle();
    expect(taxi, 0);
    expect(find.text('status'), findsNothing);
    await drainSave(t);
  });

  testWidgets('stay_lock_keeps_structure_locked_but_frees_the_taxi_mark', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture(), lock: _byStay);
    const taxi = TripEasyRowKey(TripEasyRowKind.taxi);
    expect(c.isPlanLocked, isTrue);
    expect(c.canEditStructure, isFalse);
    expect(c.planLockEnquiryId, _stayId);
    expect(c.planLockRequestId, isNull);
    expect(c.canMarkRow(taxi), isTrue);
    await t.pumpWidget(const SizedBox.shrink());
    Get.reset();
    final r = await pumpDayPlan(t, dayPlanFixture(), lock: lockedByRequest);
    expect(r.canMarkRow(taxi), isFalse);
  });

  testWidgets('edit_entry_points_hidden', (t) async {
    var fired = 0;
    final c = await pumpDayPlan(t, dayPlanFixture(), lock: lockedByRequest, pages: [
      GetPage(name: AppRoutes.tripCustomize, page: () {
        fired++;
        return const Scaffold();
      }),
    ]);
    expect(c.canEditStructure, isFalse);
    expect(find.byType(TripAddCityCard), findsNothing);
    expect(find.text(TripStringsDayplan.saveTrip), findsNothing);
    expect(find.text(TripStringsV2Plan.removeDay), findsNothing);
    expect(find.text(TripStringsV2Plan.addDay), findsNothing);

    await t.tap(find.byKey(TripLegSectionHeader.customizeKey));
    await t.pumpAndSettle();
    expect(fired, 0);

    await t.longPress(find.text('L1d1s0').first);
    await t.pumpAndSettle();
    expect(c.editMode.value, isFalse);

    await t.tap(find.byKey(TripMenuDots.boxKey).first);
    await t.pumpAndSettle();
    expect(find.text(TripStringsV2Plan.menuRename), findsOneWidget);
    expect(find.text(TripStringsV2Plan.menuSaveExit), findsOneWidget);
    expect(find.text(TripStringsV2Plan.menuEditDays), findsNothing);
    expect(find.text(TripStringsV2Plan.menuEditDates), findsNothing);
    expect(find.text(TripStringsV2Plan.menuMap), findsOneWidget);
  });

  testWidgets('view_button_navigates_with_ids', (t) async {
    Object? args;
    await pumpDayPlan(t, dayPlanFixture(), lock: lockedByRequest, pages: [
      GetPage(name: AppRoutes.tripTaxiStatus, page: () {
        args = Get.arguments;
        return const Scaffold(body: Text('status'));
      }),
    ]);
    await t.tap(find.byKey(TripPlanScreen.viewButtonKey));
    await t.pumpAndSettle();
    expect(find.text('status'), findsOneWidget);
    expect(args, {'tripId': 't1', 'requestId': lockedByRequest.requestId});
  });

  testWidgets('locked_rename_still_saves_the_name', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture(), size: const Size(360, 800), lock: lockedByRequest);
    await openRename(t);
    final input = find.descendant(of: find.byKey(TripPlanScreen.renameFieldKey), matching: find.byType(TextField));
    await t.enterText(input, 'Lake days');
    await t.tap(find.text(TripStringsV2Plan.save));
    await t.pumpAndSettle();
    expect(c.title, 'Lake days');
    expect(c.canEditStructure, isFalse);
    await drainSave(t);
  });

  testWidgets('locked_plan_five_sizes', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]), size: size, lock: _byBooking);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      expect(find.text(TripStringsDayplan.viewBooking).hitTestable(), findsOneWidget, reason: sizeLabel(size));
    }
  });

  testWidgets('stay_locked_plan_five_sizes', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]), size: size, lock: _byStay);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      expect(find.text(TripStringsDayplan.viewStay).hitTestable(), findsOneWidget, reason: sizeLabel(size));
      expect(find.descendant(of: find.byKey(TripPlanScreen.lockedBannerKey), matching: find.text(TripStringsDayplan.lockedByStay)),
          findsOneWidget, reason: sizeLabel(size));
    }
  });
}
