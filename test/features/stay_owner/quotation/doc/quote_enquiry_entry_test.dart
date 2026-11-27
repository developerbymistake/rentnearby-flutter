import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_prefill.dart';
import 'package:bakhli/features/stay_owner/quotation/widgets/quote_enquiry_pick_sheet.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_offer_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

TripEnquiryModel enquiry({TripOfferModel? offer}) => TripEnquiryModel(
      id: 'enq-1',
      status: TripEnquiryStatuses.offered,
      checkIn: DateTime(2026, 11, 23),
      checkOut: DateTime(2026, 11, 25),
      traveller: const TripPartyModel(id: 't1', name: 'Harshit Rawat', phone: '9910023456', whatsApp: '9910023456'),
      context: const TripEnquiryContext(adults: 12, kids: 2, rooms: 5, city: 'Ramnagar', text: 'secret trip notes'),
      openOffer: offer,
    );

TripOfferModel offer() => TripOfferModel.fromJson({
      'id': 'o1',
      'kind': 'Offer',
      'status': 'Open',
      'nights': 2,
      'total': 100000,
      'lines': [
        {'roomName': 'Deluxe room', 'units': 5, 'guests': 10, 'pricePerNight': 10000},
        {'roomName': null, 'units': 1, 'guests': 2, 'pricePerNight': 4000},
      ],
    });

void main() {
  group('Q2 entry from an enquiry, prefilled on the phone only', () {
    test('name, phone, dates, adults, kids, rooms and offer lines', () {
      final p = QuotePrefill.fromEnquiry(enquiry(offer: offer()));
      expect(p.enquiryId, 'enq-1');
      expect(p.guestName, 'Harshit Rawat');
      expect(p.guestPhone, '9910023456');
      expect(p.adults, 12);
      expect(p.kids, 2);
      expect(p.rooms, 5);
      expect(p.lines.length, 2);
      expect(p.lines.first.description, 'Deluxe room');
      expect(p.lines.first.rate, 10000);
      expect(p.lines.first.qty, 5);
      expect(p.lines.first.nights, 2);
      expect(p.lines.last.description, 'Room, double occupancy');
    });

    test('route arguments round trip (the prefill survives the first-time chain)', () {
      final p = QuotePrefill.fromEnquiry(enquiry(offer: offer()));
      final back = QuotePrefill.fromArgs({'prefill': p.toArgs()})!;
      expect(back.guestName, p.guestName);
      expect(back.checkIn, p.checkIn);
      expect(back.lines.length, 2);
      expect(QuotePrefill.fromArgs({'new': true}), isNull);
    });

    test('applying keeps lines already typed, fills the form fields', () {
      final p = QuotePrefill.fromEnquiry(enquiry(offer: offer()));
      final typed = QuoteDraft.blank(documentId: 'doc-00000001', today: DateTime(2026, 11, 12))
          .copyWith(lines: const [QuoteLine(id: 'x', description: 'Bonfire', rate: 6000, qty: 1, nights: 1)]);
      var n = 0;
      final d = p.applyTo(typed, () => 'n${n++}');
      expect(d.lines.length, 3);
      expect(d.lines.first.description, 'Bonfire');
      expect(d.guestName, 'Harshit Rawat');
      expect(d.nights, 2);
      expect(d.adults, 12);
      expect(d.enquiryId, 'enq-1');
    });

    test('reads only what the enquiry card shows (no trip notes, no city text)', () {
      final args = QuotePrefill.fromEnquiry(enquiry(offer: offer())).toArgs().toString();
      expect(args.contains('secret trip notes'), isFalse);
      expect(args.contains('Ramnagar'), isFalse);
    });

    test('no offer: no lines', () {
      expect(QuotePrefill.fromEnquiry(enquiry()).lines, isEmpty);
    });
  });

  group('I1 Choose an enquiry loads New, Offered and Confirmed through the owner list', () {
    final soon = DateTime.now().add(const Duration(days: 10));
    TripEnquiryModel e(String id, String status, String name, {DateTime? out}) => TripEnquiryModel(
          id: id,
          status: status,
          checkIn: soon,
          checkOut: out ?? soon.add(const Duration(days: 2)),
          traveller: TripPartyModel(id: 't$id', name: name),
        );

    final pages = <String, List<TripEnquiryModel>>{
      StayEnquiryBucket.newOnes: [e('a', TripEnquiryStatuses.asked, 'Asha')],
      StayEnquiryBucket.offered: [e('b', TripEnquiryStatuses.offered, 'Bina'), e('a', TripEnquiryStatuses.asked, 'Asha')],
      StayEnquiryBucket.confirmed: [
        e('c', TripEnquiryStatuses.confirmedByBoth, 'Chetan'),
        e('d', TripEnquiryStatuses.confirmedByBoth, 'Old stay', out: DateTime.now().subtract(const Duration(days: 3))),
      ],
    };
    Future<List<TripEnquiryModel>> loader(String bucket) async => pages[bucket] ?? const [];

    test('pages merged in bucket order, de-duplicated, an ended confirmed stay left out', () async {
      final asked = <String>[];
      final list = await QuoteEnquiryPickSheet.loadOpen(loader: (b) {
        asked.add(b);
        return loader(b);
      });
      expect(asked, [StayEnquiryBucket.newOnes, StayEnquiryBucket.offered, StayEnquiryBucket.confirmed]);
      expect(list.map((x) => x.id).toList(), ['a', 'b', 'c']);
    });

    test('a failed bucket does not hide the others', () async {
      final list = await QuoteEnquiryPickSheet.loadOpen(loader: (b) async {
        if (b == StayEnquiryBucket.newOnes) throw StateError('offline');
        return pages[b] ?? const [];
      });
      expect(list.map((x) => x.id).toList(), ['b', 'a', 'c']);
    });

    group('sheet', () {
      setUp(DS.applyApproved);
      tearDown(() {
        DS.debugReset();
        Get.reset();
      });

      Future<void> open(WidgetTester t, QuoteEnquiryLoader l) async {
        await t.pumpWidget(GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => Center(child: ElevatedButton(onPressed: () => QuoteEnquiryPickSheet.pick(c, loader: l), child: const Text('go'))),
            ),
          ),
        ));
        await t.tap(find.text('go'));
        await t.pumpAndSettle();
      }

      testWidgets('lists New, Offered and Confirmed rows with no Enquiries tab controller', (t) async {
        expect(Get.isRegistered<StayEnquiriesController>(), isFalse);
        await open(t, loader);
        expect(find.text('Asha'), findsOneWidget);
        expect(find.text('Bina'), findsOneWidget);
        expect(find.text('Chetan'), findsOneWidget);
        expect(find.text('Old stay'), findsNothing);
        expect(Get.isRegistered<StayEnquiriesController>(), isFalse);
      });

      testWidgets('no enquiries: the empty line', (t) async {
        await open(t, (_) async => const []);
        expect(find.text(StayQuoteStrings.noEnquiries), findsOneWidget);
      });
    });
  });
}
