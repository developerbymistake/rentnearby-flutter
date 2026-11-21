import 'package:bakhli/features/stay/enquiries/stay_cancel_booking_sheet.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay/enquiries/trip_send_offer_sheet.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../../../support/real_phone.dart';
import 'stay_work_fixtures.dart';

final _stay = StayOwnerModel.fromJson({
  'id': 'stay-1',
  'name': 'Deodar Heights Homestay',
  'status': 'Approved',
  'rooms': [
    {'id': 'r1', 'roomIndex': 1, 'roomName': 'Deluxe Room', 'pricePerNight': 3500, 'maxGuests': 2},
  ],
});

Map<String, dynamic> _ask({int? listed = 9600}) => enquiryJson(
      id: 'o49',
      name: 'Rohit Verma',
      checkIn: '2026-11-04',
      checkOut: '2026-11-07',
      adults: 2,
      listed: listed,
      breakdown: [
        {'roomName': 'Deluxe Room', 'units': 1, 'nights': 2, 'perNight': 3000, 'specialLabel': null},
        {'roomName': 'Deluxe Room', 'units': 1, 'nights': 1, 'perNight': 3600, 'specialLabel': 'Diwali price'},
      ],
    );

class _Host extends StatelessWidget {
  const _Host({required this.open});
  final Future<void> Function(BuildContext) open;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => open(c), child: const Text('open')))),
      );
}

Future<void> _openOffer(WidgetTester t, Map<String, dynamic> json) async {
  final c = setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([json], newCount: 1)});
  await c.load();
  final e = TripEnquiryModel.fromJson(json);
  await pumpPhone(t, _Host(open: (ctx) => TripSendOfferSheet.show(ctx, enquiry: e, stay: _stay)));
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => initTestStorage('a3_sheets'));
  tearDown(tearDownWork);

  testWidgets('o_st_49_startsWithListedBox and aboveListed amber line', (t) async {
    await _openOffer(t, _ask());
    expect(find.text('Listed for these dates'), findsOneWidget);
    expect(find.text('₹9,600'), findsOneWidget);
    expect(find.text('2 nights x ₹3,000 + 1 night x ₹3,600 (Diwali price)'), findsOneWidget);
    expect(find.text('The guest sees only your offer total. The listed price is your own reference. Payment is settled outside the app.'), findsOneWidget);
    expect(find.text('Above your listed price for these dates (₹9,600).'), findsOneWidget);
  });

  testWidgets('o_st_49_listedMissing_boxAndLineHidden', (t) async {
    await _openOffer(t, _ask(listed: null));
    expect(find.text('Listed for these dates'), findsNothing);
    expect(find.textContaining('Above your listed price'), findsNothing);
  });

  testWidgets('o_st_55_a_reasonRequired_counterTo300 and Keep closes', (t) async {
    final json = enquiryJson(id: 'c55', name: 'Rohit Verma', status: 'ConfirmedByBoth', display: 'confirmedByBoth', checkIn: '2026-11-27', checkOut: '2026-11-29', adults: 2, expiresIn: null);
    setUpEnquiries({});
    final e = TripEnquiryModel.fromJson(json);
    await pumpPhone(t, _Host(open: (ctx) => StayCancelBookingSheet.show(ctx, e)));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Cancel booking'), findsWidgets);
    expect(find.text('Rohit Verma · 27 – 29 Nov'), findsOneWidget);
    expect(find.text('Reason'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('0 / 300'), findsOneWidget);
    expect(find.text('Rohit is told at once. Your calendar entry stays, marked Cancelled, with your money notes.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'The water supply is down that week. Very sorry.');
    await t.pump();
    expect(find.text('47 / 300'), findsOneWidget);
    await t.tap(find.text('Keep'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('render o_st_49', (t) async {
    final c = setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([_ask()], newCount: 1)});
    await c.load();
    final e = TripEnquiryModel.fromJson(_ask());
    await renderOwnerFrame(t, 'o_st_49', _Host(open: (ctx) => TripSendOfferSheet.show(ctx, enquiry: e, stay: _stay)), arrange: (t) async {
      await t.tap(find.text('open'));
      await t.pump(const Duration(milliseconds: 600));
    });
  });

  testWidgets('render o_st_55_a', (t) async {
    setUpEnquiries({});
    final e = TripEnquiryModel.fromJson(enquiryJson(id: 'c55', name: 'Rohit Verma', status: 'ConfirmedByBoth', display: 'confirmedByBoth', checkIn: '2026-11-27', checkOut: '2026-11-29', adults: 2, expiresIn: null));
    await renderOwnerFrame(t, 'o_st_55', _Host(open: (ctx) => StayCancelBookingSheet.show(ctx, e)), part: 'A', arrange: (t) async {
      await t.tap(find.text('open'));
      await t.pump(const Duration(milliseconds: 600));
      await t.enterText(find.byType(TextField), 'The water supply is down that week. Very sorry.');
      await t.pump();
    });
  });
}
