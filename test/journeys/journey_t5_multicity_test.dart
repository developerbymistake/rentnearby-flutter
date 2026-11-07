import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_enquiry_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('T5 the same driver gets one row per city and the taxi row counts both asks', () async {
    final start = journeyStart();
    var n = 0;
    installFakeApi([
      FakeRoute('POST', '/trips/t1/enquiries', (o) {
        final days = [for (final d in (o.data as Map)['days'] as List) (d as num).toInt()];
        n++;
        final leg = days.first <= 3 ? 1 : 2;
        return {
          'items': [
            enquiryJson(id: 'l$n', kind: TripEnquiryKinds.taxi, status: TripEnquiryStatuses.asked, start: start, days: days, cityLeg: leg),
          ],
          'skipped': [],
          'updated': [],
          'veryShortNotice': false,
        };
      }, code: 201),
    ]);
    const repo = TripEnquiryRepository();
    final c = TripPlanController();
    c.plan.value = journeyPlan([3, 2], start: start);

    final first = await repo.createLead('t1', days: [1, 2], taxiIds: ['d1']);
    final second = await repo.createLead('t1', days: [4], taxiIds: ['d1']);
    c.applyEnquiries(first.items);
    c.applyEnquiries(second.items);

    expect(c.enquiryList.map((e) => e.cityLeg).toSet(), {1, 2});
    final taxi = c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.taxi))!;
    expect(taxi.state, TripRowState.asked);
    expect(taxi.askedCount, 2);
  });

  test('T5 two of three nights is a partial cover, not done, with the last night left', () {
    final start = journeyStart();
    final c = TripPlanController();
    c.plan.value = journeyPlan([3, 1], start: start);
    c.enquiryList.assignAll([
      TripEnquiryModel.fromJson(
          enquiryJson(id: 'e1', kind: TripEnquiryKinds.stay, status: TripEnquiryStatuses.asked, start: start, day: 1, nights: 2)),
    ]);
    final info = c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.stay, 1))!;
    expect(info.state, TripRowState.asked);
    expect(info.nightsTotal, 3);
    expect(info.nightsCovered, 2);
    expect(info.uncoveredDays, [3]);
    expect(info.partial, isTrue);
    expect(info.isDone, isFalse);
    expect(c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.stay, 2))!.state, TripRowState.todo);
  });

  test('T5 a stay ask goes stale once its places change', () {
    final start = journeyStart();
    final plan = journeyPlan([2], start: start);
    final e = TripEnquiryModel.fromJson(enquiryJson(
        id: 'e1',
        kind: TripEnquiryKinds.stay,
        status: TripEnquiryStatuses.asked,
        start: start,
        day: 1,
        nights: 1,
        contextSpots: ['Place s1']));
    expect(TripEnquiryRules.contextStale(e, plan), isFalse);

    final changed = plan.copyWith(days: [
      TripDay(day: 1, leg: 1, spots: [journeySpot('x')]),
      plan.days[1],
    ]);
    expect(TripEnquiryRules.contextStale(e, changed), isTrue);

    final taxi = TripEnquiryModel.fromJson(
        enquiryJson(id: 't', kind: TripEnquiryKinds.taxi, status: TripEnquiryStatuses.asked, start: start, days: [1]));
    expect(TripEnquiryRules.contextStale(taxi, changed), isFalse);
  });
}
