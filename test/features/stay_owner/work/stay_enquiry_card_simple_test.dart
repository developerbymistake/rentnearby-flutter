import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/tab_slot.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay_owner/enquiries_tab/stay_enquiries_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import 'stay_work_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> _confirmed({Map<String, dynamic>? change}) => enquiryJson(
      id: 'c1',
      name: 'Rohit Verma',
      status: 'ConfirmedByBoth',
      display: 'confirmedByBoth',
      checkIn: '2026-11-27',
      checkOut: '2026-11-29',
      expiresIn: null,
      acceptedOffer: offerJson(id: 'acc', perNight: 3600),
      agreedTotal: 7200,
      pendingChange: change,
    );

void main() {
  setUpAll(() => initTestStorage('enquiry_card_simple'));
  tearDown(tearDownWork);

  testWidgets('new card: Send offer, Not available, Call; no chat or counter', (t) async {
    setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([enquiryJson(id: 'n1', name: 'Rohit Sharma')..['waitingHours'] = 5], newCount: 1)});
    await pumpPhone(t, const StayEnquiriesTab());
    await _settle(t);
    expect(find.text('Send offer'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('NEW ENQUIRY'), findsOneWidget);
    for (final w in ['Open chat', 'Accept price', 'Send a different offer', 'Propose a price']) {
      expect(find.text(w), findsNothing, reason: w);
    }
  });

  testWidgets('offersLeft 0 hides Send offer', (t) async {
    setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([enquiryJson(id: 'n2', name: 'Rohit Sharma')..['offersLeft'] = 0], newCount: 1)});
    await pumpPhone(t, const StayEnquiriesTab());
    await _settle(t);
    expect(find.text('Send offer'), findsNothing);
    expect(find.text('Not available'), findsOneWidget);
  });

  testWidgets('legacy Countered renders the New card', (t) async {
    final j = enquiryJson(id: 'n3', name: 'Rohit Sharma', status: 'Countered', pendingCounter: offerJson(id: 'c', kind: 'Counter', perNight: 2700));
    setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([j], newCount: 1)});
    await pumpPhone(t, const StayEnquiriesTab());
    await _settle(t);
    expect(find.text('New'), findsWidgets);
    expect(find.text('New price'), findsNothing);
    expect(find.text('Send offer'), findsOneWidget);
  });

  testWidgets('confirmed card shows Share UPI and WhatsApp and Call without opening', (t) async {
    setUpEnquiries({StayEnquiryBucket.newOnes: pageJson(const []), StayEnquiryBucket.confirmed: pageJson([_confirmed()], confirmed: 1)});
    await pumpPhone(t, const StayEnquiriesTab());
    await _settle(t);
    await t.tap(find.text('Confirmed').first);
    await _settle(t);
    expect(find.text('Share UPI and WhatsApp'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Open chat'), findsNothing);
  });

  testWidgets('legacy change card has Accept change and Cancel booking only', (t) async {
    final change = offerJson(id: 'ch1', kind: 'ChangeRequest', checkIn: '2026-11-28', checkOut: '2026-11-30', adults: 3);
    setUpEnquiries({StayEnquiryBucket.newOnes: pageJson(const []), StayEnquiryBucket.confirmed: pageJson([_confirmed(change: change)], confirmed: 1)});
    await pumpPhone(t, const StayEnquiriesTab());
    await _settle(t);
    await t.tap(find.text('Confirmed').first);
    await _settle(t);
    expect(find.text('Accept change'), findsOneWidget);
    expect(find.text('Cancel booking'), findsOneWidget);
    expect(find.text('Send a different offer'), findsNothing);
  });

  testWidgets('notAvailable intent opens the confirm dialog, nothing declined', (t) async {
    final c = setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([enquiryJson(id: 'n4', name: 'Rohit Sharma')], newCount: 1)});
    Get.put<TabConfigController>(FakeTabs());
    final auth = FakeAuth()..signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved');
    Get.put<AuthController>(auth);
    auth.tabIntent.value = const TabIntent(index: AppTabs.centre, args: {'enquiryId': 'n4', 'bucket': 'New', 'action': 'notAvailable'}, seq: 1);
    await pumpPhone(t, const StayEnquiriesTab());
    await _settle(t);
    expect(find.text('Mark as not available?'), findsOneWidget);
    expect(c.items.single.id, 'n4');
  });
}
