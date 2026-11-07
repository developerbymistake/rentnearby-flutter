import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/features/trip/utils/trip_enquiry_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('T2 phone booking is a booked row, done on the traveller word, no undo', () async {
    final start = journeyStart();
    Map<String, Object?> row(String status, {int nights = 2}) =>
        enquiryJson(id: 'p1', kind: TripEnquiryKinds.stay, status: status, start: start, day: 1, nights: nights, agreedTotal: 4000);
    installFakeApi([
      FakeRoute.value('POST', '/trips/t1/phone-bookings',
          {'enquiry': row(TripEnquiryStatuses.confirmedByTraveller), 'confirmLink': 'https://x/go/confirm/t', 'whatsAppText': 'Namaste'},
          code: 201),
      FakeRoute.value('PUT', '/trips/enquiries/{id}/phone-booking',
          {'enquiry': row(TripEnquiryStatuses.confirmedByTraveller, nights: 1)}),
      FakeRoute.value('POST', '/trips/enquiries/{id}/cancel', row(TripEnquiryStatuses.cancelledByTraveller)),
    ]);
    const repo = TripEnquiryRepository();
    final c = TripPlanController();
    c.plan.value = journeyPlan([2], start: start);
    const stay = TripEasyRowKey(TripEasyRowKind.stay, 1);

    final created = await repo.createPhoneBooking('t1', {'stayId': 'listing-p1', 'day': 1, 'allNights': true, 'agreedTotal': 4000});
    c.applyEnquiries([created.enquiry]);
    var info = c.easyRowOf(stay)!;
    expect(info.state, TripRowState.booked);
    expect(info.isDone, isTrue);
    expect(info.needsYou, isFalse);
    expect(info.canMark, isFalse);
    expect(c.easyProgress, (done: 1, total: 4, percent: 25));
    expect(await c.markOwn(stay), isA<TripMarkBlocked>());

    final edited = await repo.editPhoneBooking('p1', {'nights': 1, 'agreedTotal': 2000});
    c.applyEnquiries([edited.enquiry]);
    info = c.easyRowOf(stay)!;
    expect(info.state, TripRowState.booked);
    expect(info.nightsTotal, 2);
    expect(info.nightsCovered, 1);
    expect(info.uncoveredDays, [2]);
    expect(info.partial, isTrue);
    expect(info.isDone, isFalse);
    expect(c.easyProgress.done, 0);

    c.applyEnquiries([await repo.cancel('p1')]);
    info = c.easyRowOf(stay)!;
    expect(info.state, TripRowState.todo);
    expect(c.easyProgress.done, 0);
  });

  test('T2 the dates gate: a past start with nothing open reopens as new dates', () {
    final today = TripClock.today();
    final past = today.subtract(const Duration(days: 3));
    expect(TripDatesRules.isStale(past, today, false), isTrue);
    expect(TripDatesRules.isStale(past, today, true), isFalse);
    expect(TripDatesRules.isStale(today.add(const Duration(days: 1)), today, false), isFalse);
    expect(TripDatesRules.isStale(null, today, false), isFalse);
  });
}
