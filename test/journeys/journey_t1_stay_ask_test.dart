import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_easy_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('T1 ask -> asked row -> offer needs you -> confirmed', () async {
    final start = journeyStart();
    Map<String, Object?> row(String status, String display) => enquiryJson(
        id: 'e1', kind: TripEnquiryKinds.stay, status: status, start: start, day: 1, nights: 2, displayStatus: display, agreedTotal: 4000);
    final api = installFakeApi([
      FakeRoute.value('POST', '/trips/t1/enquiries',
          {'items': [row(TripEnquiryStatuses.asked, 'asked')], 'skipped': [], 'updated': [], 'veryShortNotice': false},
          code: 201, headers: {'x-trip-asks-left': '19'}),
      FakeRoute.value('POST', '/trips/enquiries/{id}/offers/{offer}/accept', row(TripEnquiryStatuses.confirmedByBoth, 'confirmed')),
    ]);
    const repo = TripEnquiryRepository();
    final c = TripPlanController();
    c.plan.value = journeyPlan([2], start: start);
    const stay = TripEasyRowKey(TripEasyRowKind.stay, 1);

    expect(c.easyRowOf(stay)!.state, TripRowState.todo);

    final batch = await repo.create('t1', day: 1, stayIds: ['listing-1'], nights: 2);
    expect(batch.asksLeft, 19);
    c.applyEnquiries(batch.items);
    var info = c.easyRowOf(stay)!;
    expect(info.state, TripRowState.asked);
    expect(info.askedCount, 1);
    expect(info.needsYou, isFalse);
    expect(info.partial, isFalse);

    c.applyEnquiries([TripEnquiryModel.fromJson(row(TripEnquiryStatuses.offered, 'offered'))]);
    info = c.easyRowOf(stay)!;
    expect(info.state, TripRowState.offer);
    expect(info.needsYou, isTrue);

    final accepted = await repo.acceptOffer('e1', 'o1');
    c.applyEnquiries([accepted]);
    info = c.easyRowOf(stay)!;
    expect(info.state, TripRowState.confirmed);
    expect(info.isDone, isTrue);
    expect(api.calls('POST', '/trips/enquiries/e1/offers/o1/accept'), hasLength(1));

    expect(await c.markOwn(const TripEasyRowKey(TripEasyRowKind.gettingThere)), isA<TripMarked>());
    expect(await c.markOwn(const TripEasyRowKey(TripEasyRowKind.taxi)), isA<TripMarked>());
    c.skipRow(const TripEasyRowKey(TripEasyRowKind.comingBack));
    final progress = c.easyProgress;
    expect(progress.total, 3);
    expect(progress.done, 3);
    expect(TripEasyRules.allResolved(c.easyRows), isTrue);
  });
}
