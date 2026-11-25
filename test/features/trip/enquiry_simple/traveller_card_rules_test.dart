import 'package:bakhli/design/extra/k2_states.dart';
import 'package:bakhli/features/trip/enquiries/traveller_enquiry_card.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/trip_strings_enquiry_simple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

TripEnquiryModel _e(String status, String display, {bool quiet = false, bool offer = false, String? endReason, String? failReason}) =>
    TripEnquiryModel.fromJson({
      'id': 'e-$display',
      'tripId': 't1',
      'kind': 'Stay',
      'listingId': 's1',
      'listingName': 'Lakeside Rooms',
      'day': 1,
      'checkIn': '2026-12-01',
      'checkOut': '2026-12-03',
      'status': status,
      'displayStatus': display,
      'isQuiet': quiet,
      'endReason': ?endReason,
      'failReason': ?failReason,
      'createdAt': DateTime.now().toUtc().subtract(const Duration(hours: 14)).toIso8601String(),
      if (offer) 'openOffer': {'id': 'o1', 'total': 3600, 'nights': 2},
    });

Future<void> _pump(WidgetTester t, TripEnquiryModel e) async {
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(412, 900)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: TravellerEnquiryCard(enquiry: e, phone: '9876543210', onSimilar: () {}, onFindAnother: () {}),
        ),
      ),
    ),
  ));
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('kind follows display status and Quiet', () {
    expect(TravellerEnquiryCard.kindOf(_e('Asked', 'asked')), TravellerCardKind.waiting);
    expect(TravellerEnquiryCard.kindOf(_e('Asked', 'asked', quiet: true)), TravellerCardKind.quiet);
    expect(TravellerEnquiryCard.kindOf(_e('Offered', 'offered', offer: true)), TravellerCardKind.offer);
    expect(TravellerEnquiryCard.kindOf(_e('Offered', 'offered')), TravellerCardKind.offerMissing);
    expect(TravellerEnquiryCard.kindOf(_e('ConfirmedByBoth', 'confirmedByBoth')), TravellerCardKind.booked);
    expect(TravellerEnquiryCard.kindOf(_e('NotAvailable', 'notAvailable')), TravellerCardKind.ended);
    expect(TravellerEnquiryCard.kindOf(_e('Closed', 'closed')), TravellerCardKind.ended);
  });

  test('honest closed reasons, never the word blocked', () {
    expect(TravellerEnquiryCard.label(_e('Asked', 'asked', quiet: true)), TripStringsEnq.quietPill);
    expect(TravellerEnquiryCard.label(_e('Closed', 'closed', endReason: 'datesChanged')), TripStringsEnq.closedDates);
    expect(TravellerEnquiryCard.label(_e('Closed', 'closed', endReason: 'stayRemoved')), TripStringsEnq.stayRemoved);
    expect(TravellerEnquiryCard.label(_e('Closed', 'closed', endReason: 'stayPaused')), TripStringsEnq.notTaking);
    final blocked = TravellerEnquiryCard.label(_e('Closed', 'closed', endReason: 'hostBlocked'));
    expect(blocked, TripStringsEnq.hostCant);
    expect(blocked.toLowerCase(), isNot(contains('block')));
    expect(TravellerEnquiryCard.label(_e('Closed', 'closed', failReason: 'Withdrawn')), 'Withdrawn');
  });

  final exits = <String, (TripEnquiryModel, List<String>)>{
    'waiting': (_e('Asked', 'asked'), ['Withdraw', TripStringsEnq.seeSimilar]),
    'quiet': (_e('Asked', 'asked', quiet: true), [TripStringsEnq.seeSimilar, 'Withdraw']),
    'offer': (_e('Offered', 'offered', offer: true), ['Decline']),
    'offer missing': (_e('Offered', 'offered'), ['Withdraw']),
    'booked': (_e('ConfirmedByBoth', 'confirmedByBoth'), ['Cancel booking']),
    'ended': (_e('NotAvailable', 'notAvailable'), [TripStringsEnq.seeSimilar, 'Find another stay']),
  };

  for (final entry in exits.entries) {
    testWidgets('every state has a visible exit: ${entry.key}', (t) async {
      final (e, labels) = entry.value;
      await _pump(t, e);
      for (final l in labels) {
        expect(find.text(l), findsWidgets, reason: '${entry.key}: $l');
      }
      expect(find.text('Open chat'), findsNothing);
      expect(find.text('Propose a price'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('quiet card uses the calm grey tone', (t) async {
    await _pump(t, _e('Asked', 'asked', quiet: true));
    expect(find.text(TripStringsEnq.quietPill), findsOneWidget);
    expect(t.widget<ReplyCard3D>(find.byType(ReplyCard3D)).status, StatusTone3D.closed);
  });
}
