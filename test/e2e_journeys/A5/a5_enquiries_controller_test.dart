import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  // Real life: the traveller withdrew while the host had the card open; the host taps Not available and the server answers TripEnquiryClosed.
  test('a closed answer refreshes the row so it leaves the New list', () async {
    final start = journeyStart();
    final adapter = installFakeApi([
      FakeRoute.value('POST', '/trips/enquiries/e1/not-available', null, code: 409, errorType: 'TripEnquiryClosed'),
      FakeRoute.value(
        'GET',
        '/trips/enquiries/e1',
        enquiryJson(id: 'e1', kind: TripEnquiryKinds.stay, status: TripEnquiryStatuses.cancelledByTraveller, start: start),
      ),
      FakeRoute.value('GET', '/trips/enquiries/owner', {
        'items': <Object>[],
        'hasMore': false,
        'counts': {'new': 0, 'offered': 0, 'confirmed': 0, 'closed': 1},
      }),
    ]);
    final c = StayEnquiriesController();
    c.items.assignAll([
      TripEnquiryModel.fromJson(enquiryJson(id: 'e1', kind: TripEnquiryKinds.stay, status: TripEnquiryStatuses.asked, start: start)),
    ]);
    expect(c.items, hasLength(1));

    final ok = await c.notAvailable('e1');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(ok, isFalse);
    expect(c.lastErrorType, 'TripEnquiryClosed');
    expect(adapter.calls('GET', '/trips/enquiries/e1'), hasLength(1));
    expect(c.items, isEmpty);
  });

  test('the pending count comes from the list call, not from push', () async {
    installFakeApi([
      FakeRoute.value('GET', '/trips/enquiries/owner', {
        'items': <Object>[],
        'hasMore': false,
        'counts': {'new': 3, 'offered': 0, 'confirmed': 0, 'closed': 0},
      }),
    ]);
    final c = StayEnquiriesController();
    await c.loadBadge();
    expect(c.newCount.value, 3);
  });
}
