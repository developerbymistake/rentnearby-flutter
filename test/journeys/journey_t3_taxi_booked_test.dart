import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/utils/trip_easy_rules.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('T3 booked taxi plus own stay resolves every row', () async {
    final start = journeyStart();
    installFakeApi([
      FakeRoute.value(
          'POST',
          '/trips/t1/taxi-bookings',
          enquiryJson(
              id: 'x1',
              kind: TripEnquiryKinds.taxi,
              status: TripEnquiryStatuses.bookedByTraveller,
              start: start,
              days: [1, 2],
              cityLeg: 1,
              agreedTotal: 6000),
          code: 201),
    ]);
    const repo = TripEnquiryRepository();
    final c = TripPlanController();
    c.plan.value = journeyPlan([2], start: start);
    const taxi = TripEasyRowKey(TripEasyRowKind.taxi);

    final booked = await repo.taxiBooking('t1', {'taxiId': 'listing-x1', 'days': [1, 2], 'agreedFare': 6000, 'pickupTime': '08:30'});
    expect(booked.cityLeg, 1);
    c.applyEnquiries([booked]);
    final info = c.easyRowOf(taxi)!;
    expect(info.state, TripRowState.booked);
    expect(info.isDone, isTrue);
    expect(info.canMark, isFalse);
    expect(TripEasyRules.allResolved(c.easyRows), isFalse);

    expect(await c.markOwn(const TripEasyRowKey(TripEasyRowKind.stay, 1)), isA<TripMarked>());
    expect(await c.markOwn(const TripEasyRowKey(TripEasyRowKind.gettingThere)), isA<TripMarked>());
    c.skipRow(const TripEasyRowKey(TripEasyRowKind.comingBack));

    expect(TripEasyRules.allResolved(c.easyRows), isTrue);
    expect(c.easyProgress.done, c.easyProgress.total);
    expect(c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.stay, 1))!.state, TripRowState.own);
    expect(TripPlanHeader.hintOf(c, c.easyRows), TripStringsV2Plan.hintAllSet);
  });
}
