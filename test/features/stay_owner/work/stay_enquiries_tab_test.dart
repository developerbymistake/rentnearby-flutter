import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:dio/dio.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay_owner/enquiries_tab/stay_enquiries_tab.dart';
import 'package:bakhli/features/stay_owner/enquiries_tab/stay_owner_enquiry_card.dart';
import 'package:bakhli/features/stay_owner/enquiries_tab/stay_quiet_week_banner.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'stay_work_fixtures.dart';

const _free = MyPlanModel(paymentEnabled: true, trialAvailable: true);
const _off = OwnerPlans.paymentOff;
const _plus = OwnerPlans.plus;

final _rohitNew = enquiryJson(id: 'e1', name: 'Rohit Sharma', city: 'Nainital, Mukteshwar');
final _anjaliNew = enquiryJson(
  id: 'e2',
  name: 'Anjali Verma',
  checkIn: '2026-12-02',
  checkOut: '2026-12-05',
  adults: 6,
  rooms: 2,
  listed: 27000,
  expiresIn: const Duration(hours: 24),
  breakdown: [
    {'roomName': 'Family Room', 'units': 2, 'nights': 3, 'perNight': 4500},
  ],
);

final _counter = enquiryJson(
  id: 'e3',
  name: 'Rohit Sharma',
  status: 'Countered',
  display: 'asked',
  openOffer: offerJson(id: 'o-open', perNight: 3000, checkIn: '2026-11-24', checkOut: '2026-11-26'),
  pendingCounter: offerJson(id: 'c1', kind: 'Counter', perNight: 2700, proposed: 2700, total: 5400, checkIn: '2026-11-24', checkOut: '2026-11-26', validUntil: iso(frameNow.add(const Duration(hours: 5)))),
  counterCount: 1,
);

Map<String, dynamic> _confirmed({String id = 'e4', Map<String, dynamic>? change, Map<String, dynamic>? revised, bool problem = false}) => enquiryJson(
      id: id,
      name: 'Rohit Verma',
      status: 'ConfirmedByBoth',
      display: 'confirmedByBoth',
      checkIn: '2026-11-27',
      checkOut: '2026-11-29',
      adults: 2,
      expiresIn: null,
      acceptedOffer: offerJson(id: 'acc', perNight: 3600, respondedAt: iso(DateTime(2026, 11, 21, 9))),
      agreedTotal: 7200,
      calendarEntryId: 'cal-1',
      confirmedAt: iso(DateTime(2026, 11, 21, 9)),
      pendingChange: change,
      pendingRevised: revised,
      problemReported: problem,
    );

final _offered = enquiryJson(
  id: 'e5',
  name: 'Anjali Verma',
  status: 'Offered',
  display: 'offered',
  checkIn: '2026-12-02',
  checkOut: '2026-12-05',
  adults: 6,
  rooms: 2,
  offerCount: 1,
  openOffer: offerJson(id: 'o5', room: 'Family Room', perNight: 4500, units: 2, nights: 3, checkIn: '2026-12-02', checkOut: '2026-12-05', validUntil: iso(DateTime(2026, 11, 21, 18, 40))),
);

Map<String, dynamic> _closed(String id, String name, String checkIn, String checkOut, String kind, {String room = 'Deluxe Room', String? reason}) => enquiryJson(
      id: id,
      name: name,
      status: 'Closed',
      display: 'closed',
      checkIn: checkIn,
      checkOut: checkOut,
      expiresIn: null,
      closedKind: kind,
      cancelReason: reason,
      calendarEntryId: kind == 'CancelledByOwner' ? 'cal-2' : null,
      cancelledAt: kind == 'CancelledByOwner' ? iso(DateTime(2026, 11, 21, 9)) : null,
      breakdown: [
        {'roomName': room, 'units': 1, 'nights': 2, 'perNight': 3000},
      ],
    );

final _closedTen = [
  _closed('k1', 'Kavya Iyer', '2026-12-12', '2026-12-14', 'Expired'),
  _closed('k2', 'Sanjay Rao', '2026-12-09', '2026-12-10', 'OfferDeclined', room: 'Family Room'),
  _closed('k3', 'Ankit Mehra', '2026-12-15', '2026-12-17', 'OfferExpired'),
  _closed('k4', 'Pooja Nair', '2027-01-02', '2027-01-04', 'TravellerLeft'),
  _closed('k5', 'Vikas Jain', '2026-12-05', '2026-12-07', 'BookedElsewhere', room: 'Family Room'),
  _closed('k6', 'Manish Rawat', '2026-12-20', '2026-12-22', 'BookedByPhone'),
  _closed('k7', 'Rohit Sharma', '2026-11-24', '2026-11-26', 'CancelledByGuest'),
  _closed('k8', 'Rohit Verma', '2026-11-27', '2026-11-29', 'CancelledByOwner', reason: 'The water supply is down that week.'),
  _closed('k9', 'Amit Sinha', '2026-12-19', '2026-12-20', 'ClosedByAdmin'),
  _closed('k10', 'Neeraj Das', '2026-12-01', '2026-12-03', 'NotAvailable', room: 'Family Room'),
];

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openBucket(WidgetTester t, String label) async {
  await t.tap(find.text(label).first);
  await _settle(t);
}

void main() {
  setUpAll(() => initTestStorage('a3_enquiries'));
  tearDown(tearDownWork);

  group('o_st_17 New bucket', () {
    testWidgets('o_st_17_newBucket_cardsShowListedWhenAskedAndCountdown', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_rohitNew, _anjaliNew], newCount: 2)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('Enquiries'), findsOneWidget);
      expect(find.text('Deodar Heights Homestay'), findsOneWidget);
      expect(find.text('New (2)'), findsOneWidget);
      expect(find.text('Offered'), findsOneWidget);
      expect(find.text('Rohit Sharma'), findsOneWidget);
      expect(find.text('24 – 26 Nov · 3 guests'), findsOneWidget);
      expect(find.text('1 room x 2 nights · Listed when asked ₹6,000'), findsOneWidget);
      expect(find.text('2 rooms x 3 nights · Listed when asked ₹27,000'), findsOneWidget);
      expect(find.text('2 h'), findsOneWidget);
      expect(find.text('24 h'), findsOneWidget);
      expect(find.text('Send offer'), findsNWidgets(2));
      expect(find.text('Call guest'), findsNWidgets(2));
      expect(find.text('Not available'), findsNWidgets(2));
      expect(find.textContaining('dvance'), findsNothing);
    });

    testWidgets('o_st_17_pushFocus_scrollsToAndHighlightsTheCard', (t) async {
      final many = [for (var i = 0; i < 12; i++) enquiryJson(id: 'f$i', name: 'Guest $i')];
      final c = setUpEnquiries({StayEnquiryBucket.newOnes: pageJson(many, newCount: 12)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('Guest 11'), findsNothing);
      c.focusId.value = 'f11';
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await _settle(t);
      expect(find.text('Guest 11').hitTestable(), findsOneWidget);
      final card = t.widget<StayOwnerEnquiryCard>(find.ancestor(of: find.text('Guest 11'), matching: find.byType(StayOwnerEnquiryCard)));
      expect(card.highlighted, isTrue);
      expect(t.widget<StayOwnerEnquiryCard>(find.byType(StayOwnerEnquiryCard).first).highlighted, isFalse);
    });

    testWidgets('o_st_17_listedMissing_partDropped and callHiddenWithoutPhone', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([enquiryJson(id: 'x', name: 'Rohit Sharma', listed: null, phone: null)], newCount: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('1 room x 2 nights'), findsOneWidget);
      expect(find.textContaining('Listed when asked'), findsNothing);
      expect(find.text('Call guest'), findsNothing);
    });

    testWidgets('o_st_17_under72h_titleStartsUrgent', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([enquiryJson(id: 'u', name: 'Rohit Sharma', checkIn: '2026-11-22', checkOut: '2026-11-24')], newCount: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('Urgent: Rohit Sharma'), findsOneWidget);
    });

    testWidgets('o_st_17_pillCountOnSelectedOnly and centre badge source', (t) async {
      final c = setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_rohitNew], newCount: 2, offered: 1, confirmed: 3)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('New (2)'), findsOneWidget);
      expect(find.text('Offered'), findsOneWidget);
      expect(find.text('Offered (1)'), findsNothing);
      expect(c.newCount.value, 2);
    });

    testWidgets('o_st_17_noCapOnEnquiries_50Rows_builder', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([for (var i = 0; i < 50; i++) enquiryJson(id: 'n$i', name: 'Guest $i')], newCount: 50)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.byType(ListView), findsWidgets);
      expect(find.text('New (50)'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('o_st_17_neverGated_guardKeys with payment off', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_rohitNew], newCount: 1)}, plan: _off);
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
    });
  });

  group('o_st_18 expanded', () {
    testWidgets('o_st_18_expandedRowsRoomTripOfferWithin', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_rohitNew], newCount: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await t.tap(find.text('Rohit Sharma'));
      await _settle(t);
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Deluxe Room'), findsOneWidget);
      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('Nainital, Mukteshwar · trip in 3 days'), findsOneWidget);
      expect(find.text('Offer within'), findsOneWidget);
      expect(find.text('Ask advance'), findsNothing);
    });

    testWidgets('o_st_18_notAvailableConfirm opens the dialog', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_rohitNew], newCount: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await t.tap(find.text('Not available').first);
      await _settle(t);
      expect(find.text('Mark as not available?'), findsOneWidget);
    });
  });

  group('o_st_19 empty New', () {
    testWidgets('o_st_19_freeEmptyNew_showsBannerAndSeePlus', (t) async {
      setUpEnquiries({}, plan: _free);
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('No enquiries yet'), findsOneWidget);
      expect(find.text('Trip enquiries for your stay show here.'), findsOneWidget);
      expect(find.text('Quiet week? Plus puts your stay first in trip plans.'), findsOneWidget);
      expect(find.text('See Plus'), findsOneWidget);
    });

    for (final (label, plan) in [('o_st_19_plus_noBanner', _plus), ('o_st_19_paymentOff_noBannerNoGateKey', _off)]) {
      testWidgets(label, (t) async {
        setUpEnquiries({}, plan: plan);
        await pumpPhone(t, const StayEnquiriesTab());
        await _settle(t);
        expect(find.text('No enquiries yet'), findsOneWidget);
        expect(find.byType(StayQuietWeekBanner), findsOneWidget);
        expect(find.text('See Plus'), findsNothing);
        expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
        expect(find.textContaining('Plus'), findsNothing);
      });
    }

    testWidgets('o_st_19_otherBucketEmpty_noBanner', (t) async {
      setUpEnquiries({}, plan: _free);
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Offered');
      expect(find.text('No enquiries yet'), findsOneWidget);
      expect(find.text('See Plus'), findsNothing);
    });
  });

  group('o_st_67 B and C', () {
    testWidgets('o_st_67_c_plannerOffEmptyCard', (t) async {
      setUpEnquiries({});
      StayEnquiriesController.debugFetch = (s, p, n) async => throw _executionDisabled();
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('Not available right now'), findsOneWidget);
      expect(find.text('New enquiries will come back soon. You can still answer the open ones.'), findsOneWidget);
    });

    testWidgets('error with no copy shows Couldn\'t load and Try again', (t) async {
      setUpEnquiries({});
      StayEnquiriesController.debugFetch = (s, p, n) async => throw Exception('x');
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('o_st_67_b_offlineKeepsLastListWithStrip', (t) async {
      final c = setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_rohitNew], newCount: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      StayEnquiriesController.debugFetch = (s, p, n) async => throw Exception('offline');
      await c.refreshList();
      await _settle(t);
      expect(find.text('Rohit Sharma'), findsOneWidget);
      expect(find.text('Could not refresh. Showing your last list.'), findsOneWidget);
    });
  });

  group('o_st_53 counter', () {
    testWidgets('o_st_53_counterCard_rowsAndChip', (t) async {
      setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_counter], newCount: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      expect(find.text('New price'), findsOneWidget);
      expect(find.text('1 room x 2 nights · Deluxe Room'), findsOneWidget);
      expect(find.text('Your offer'), findsOneWidget);
      expect(find.text('₹3,000 / night'), findsOneWidget);
      expect(find.text('Rohit asks'), findsOneWidget);
      expect(find.text('₹2,700 / night'), findsOneWidget);
      expect(find.text('Total at his price'), findsOneWidget);
      expect(find.text('₹5,400'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('5 h'), findsOneWidget);
      expect(find.text('Accept price sends him an offer at ₹2,700 a night.'), findsOneWidget);
      expect(find.text('Accept price'), findsOneWidget);
      expect(find.text('Send a different offer'), findsOneWidget);
    });
  });

  group('o_st_56 offered, menu, revised', () {
    testWidgets('o_st_56_a_offeredCardRows_timerAndOffersSent', (t) async {
      setUpEnquiries({StayEnquiryBucket.offered: pageJson([_offered], offered: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Offered');
      expect(find.text('Offered (1)'), findsOneWidget);
      expect(find.text('2 – 5 Dec · 6 guests'), findsOneWidget);
      expect(find.text('2 rooms x 3 nights'), findsOneWidget);
      expect(find.text('Family Room · ₹4,500 / night'), findsOneWidget);
      expect(find.text('₹27,000'), findsOneWidget);
      expect(find.text('6:40 pm'), findsOneWidget);
      expect(find.text('Send new offer'), findsOneWidget);
    });

    testWidgets('o_st_56_b_menuItemsAndOrder and o_st_56_c revised note', (t) async {
      setUpEnquiries({StayEnquiryBucket.confirmed: pageJson([_confirmed(revised: offerJson(id: 'r1', kind: 'Revised', perNight: 3400))], confirmed: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Confirmed');
      expect(find.text('Agreed price'), findsOneWidget);
      expect(find.text('₹3,600 / night'), findsOneWidget);
      expect(find.text('Revised offer ₹3,400 / night · Not accepted yet'), findsOneWidget);
      expect(find.text('The agreed price stays until Rohit accepts.'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('More actions for Rohit Verma'));
      await _settle(t);
      expect(find.text('Send a revised offer'), findsNothing);
      expect(find.text('Open chat'), findsOneWidget);
      expect(find.text('Report traveller'), findsOneWidget);
      expect(find.text('Cancel booking'), findsOneWidget);
    });
  });

  group('o_st_39 confirmed actions', () {
    testWidgets('o_st_39_confirmedCard_rowsAndInfoStrip', (t) async {
      setUpEnquiries({StayEnquiryBucket.confirmed: pageJson([_confirmed()], confirmed: 3)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Confirmed');
      expect(find.text('Confirmed (3)'), findsOneWidget);
      await t.tap(find.text('Rohit Verma'));
      await _settle(t);
      expect(find.text('1 room x 2 nights · Offer ₹7,200'), findsOneWidget);
      expect(find.text('By both, 21 Nov'), findsOneWidget);
      expect(find.text('In your calendar'), findsOneWidget);
      expect(find.text('27 – 29 Nov'), findsOneWidget);
      expect(find.text('Money is settled between you and the guest, outside the app.'), findsOneWidget);
      expect(find.text('Share UPI and WhatsApp'), findsOneWidget);
      expect(find.text('Open chat'), findsOneWidget);
      expect(find.textContaining('dvance'), findsNothing);
    });

    testWidgets('o_st_39_noCalendarEntry_rowHidden', (t) async {
      final j = _confirmed()..remove('calendarEntryId');
      setUpEnquiries({StayEnquiryBucket.confirmed: pageJson([j], confirmed: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Confirmed');
      await t.tap(find.text('Rohit Verma'));
      await _settle(t);
      expect(find.text('In your calendar'), findsNothing);
    });
  });

  group('o_st_54 change request', () {
    testWidgets('o_st_54_changeCard_oldNewSideBySide', (t) async {
      final change = offerJson(id: 'ch1', kind: 'ChangeRequest', perNight: 3600, checkIn: '2026-11-28', checkOut: '2026-11-30', adults: 3, validUntil: iso(frameNow.add(const Duration(hours: 20))));
      setUpEnquiries({StayEnquiryBucket.confirmed: pageJson([_confirmed(change: change)], confirmed: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Confirmed');
      expect(find.text('Change request'), findsOneWidget);
      expect(find.text('Confirmed · Deluxe Room'), findsOneWidget);
      expect(find.text('Dates'), findsOneWidget);
      expect(find.textContaining('28 – 30 Nov'), findsOneWidget);
      expect(find.text('Guests'), findsOneWidget);
      expect(find.text('Agreed price'), findsOneWidget);
      expect(find.text('20 h'), findsOneWidget);
      expect(find.text('Your calendar moves only when you accept. Money notes stay as they are.'), findsOneWidget);
      expect(find.text('Accept change'), findsOneWidget);
      expect(find.text('Cancel booking'), findsOneWidget);
    });

    testWidgets('o_st_54_unchangedGuests_rowHidden', (t) async {
      final change = offerJson(id: 'ch1', kind: 'ChangeRequest', perNight: 3600, checkIn: '2026-11-28', checkOut: '2026-11-30', adults: 2);
      setUpEnquiries({StayEnquiryBucket.confirmed: pageJson([_confirmed(change: change)], confirmed: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Confirmed');
      expect(find.text('Guests'), findsNothing);
    });
  });

  group('o_st_57 closed', () {
    testWidgets('o_st_57_tenEndStateChips_exactTexts', (t) async {
      setUpEnquiries({StayEnquiryBucket.closed: pageJson(_closedTen)});
      await pumpPhone(t, const StayEnquiriesTab(), size: const Size(392, 1500));
      await _settle(t);
      await _openBucket(t, 'Closed');
      for (final chip in ['Expired', 'Offer declined', 'Offer expired', 'Traveller left', 'Booked elsewhere', 'Booked by phone', 'Cancelled by guest', 'Cancelled by you', 'Closed by Bakhli']) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(find.text('12 – 14 Dec · no reply in time'), findsOneWidget);
      expect(find.text('2 – 4 Jan · trip cancelled'), findsOneWidget);
      expect(find.text('20 – 22 Dec · by phone'), findsOneWidget);
    });

    testWidgets('o_st_57_unknownEndKind_noChipNoCrash and row menu', (t) async {
      setUpEnquiries({StayEnquiryBucket.closed: pageJson([_closed('z', 'Zed', '2026-12-01', '2026-12-02', 'SomethingNew')])});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Closed');
      expect(find.text('Zed'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('More actions for Zed'));
      await _settle(t);
      expect(find.text('Open chat'), findsOneWidget);
      expect(find.text('Report traveller'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
    });

    testWidgets('o_st_55_b_closedCardRowsAndButtons', (t) async {
      setUpEnquiries({StayEnquiryBucket.closed: pageJson([_closedTen[7]])});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Closed');
      await t.tap(find.text('Rohit Verma'));
      await _settle(t);
      expect(find.text('Cancelled by you on 21 Nov'), findsOneWidget);
      expect(find.text('The water supply is down that week.'), findsOneWidget);
      expect(find.text('Calendar entry'), findsOneWidget);
      expect(find.text('Open chat'), findsOneWidget);
    });

    testWidgets('o_st_57_problemStripOnConfirmedWithOpen', (t) async {
      setUpEnquiries({StayEnquiryBucket.confirmed: pageJson([_confirmed(problem: true)], confirmed: 1)});
      await pumpPhone(t, const StayEnquiriesTab());
      await _settle(t);
      await _openBucket(t, 'Confirmed');
      expect(find.text('The guest reported a problem. Bakhli will contact you.'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('WORK-STD sizes', () {
    for (final (name, data, bucket) in [
      ('new 0 rows', <Map<String, dynamic>>[], 'New'),
      ('new 1 row', [_rohitNew], 'New'),
      ('new 2 rows + counter', [_rohitNew, _anjaliNew, _counter], 'New'),
      ('confirmed with change', [_confirmed(change: offerJson(id: 'c', kind: 'ChangeRequest', checkIn: '2026-11-28', checkOut: '2026-11-30', adults: 6))], 'Confirmed'),
      ('closed ten', _closedTen, 'Closed'),
    ]) {
      testOwnerSizes(
        'enquiries tab $name',
        () => const StayEnquiriesTab(),
        setUpEach: () => setUpEnquiries({
          StayEnquiryBucket.newOnes: pageJson(bucket == 'New' ? data : const [], newCount: data.length),
          StayEnquiryBucket.confirmed: pageJson(bucket == 'Confirmed' ? data : const []),
          StayEnquiryBucket.closed: pageJson(bucket == 'Closed' ? data : const []),
        }),
        arrange: (t) async {
          await _settle(t);
          if (bucket != 'New') await _openBucket(t, bucket);
        },
      );
    }
  });

  group('renders', () {
    Future<void> render(WidgetTester t, String id, Map<String, Map<String, dynamic>> data, {String? part, String? bucket, String? expand, MyPlanModel plan = _free}) async {
      setUpEnquiries(data, plan: plan);
      await renderOwnerFrame(t, id, const StayEnquiriesTab(), part: part, arrange: (t) async {
        await _settle(t);
        if (bucket != null) await _openBucket(t, bucket);
        if (expand != null) {
          await t.tap(find.text(expand).first);
          await _settle(t);
        }
      });
    }

    testWidgets('render o_st_17', (t) => render(t, 'o_st_17', {StayEnquiryBucket.newOnes: pageJson([_rohitNew, _anjaliNew], newCount: 2)}));
    testWidgets('render o_st_18', (t) => render(t, 'o_st_18', {StayEnquiryBucket.newOnes: pageJson([_rohitNew], newCount: 2)}, expand: 'Rohit Sharma'));
    testWidgets('render o_st_19', (t) => render(t, 'o_st_19', {}));
    testWidgets('render o_st_39', (t) => render(t, 'o_st_39', {StayEnquiryBucket.confirmed: pageJson([_confirmed()], confirmed: 3)}, bucket: 'Confirmed', expand: 'Rohit Verma'));
    testWidgets('render o_st_53', (t) => render(t, 'o_st_53', {StayEnquiryBucket.newOnes: pageJson([_counter], newCount: 1)}));
    testWidgets(
        'render o_st_54',
        (t) => render(t, 'o_st_54', {
              StayEnquiryBucket.confirmed: pageJson([
                _confirmed(change: offerJson(id: 'ch', kind: 'ChangeRequest', perNight: 3600, checkIn: '2026-11-28', checkOut: '2026-11-30', adults: 3, validUntil: iso(frameNow.add(const Duration(hours: 20))))),
              ]),
            }, bucket: 'Confirmed'));
    testWidgets('render o_st_55_b', (t) => render(t, 'o_st_55', {StayEnquiryBucket.closed: pageJson([_closedTen[7]])}, part: 'B', bucket: 'Closed', expand: 'Rohit Verma'));
    testWidgets('render o_st_56_a', (t) => render(t, 'o_st_56', {StayEnquiryBucket.offered: pageJson([_offered], offered: 1)}, part: 'A', bucket: 'Offered'));
    testWidgets('render o_st_56_b', (t) async {
      await render(t, 'o_st_56', {StayEnquiryBucket.confirmed: pageJson([_confirmed()])}, part: 'B', bucket: 'Confirmed');
    });
    testWidgets('render o_st_56_c', (t) => render(t, 'o_st_56', {StayEnquiryBucket.confirmed: pageJson([_confirmed(revised: offerJson(id: 'r', kind: 'Revised', perNight: 3400))])}, part: 'C', bucket: 'Confirmed'));
    testWidgets('render o_st_57', (t) => render(t, 'o_st_57', {StayEnquiryBucket.closed: pageJson(_closedTen)}, bucket: 'Closed'));
  });
}

DioException _executionDisabled() {
  final req = RequestOptions(path: '/trips/enquiries/owner');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: 403, data: <String, dynamic>{
      'error': <String, dynamic>{'type': 'TripExecutionDisabled', 'message': 'off'},
    }),
  );
}
