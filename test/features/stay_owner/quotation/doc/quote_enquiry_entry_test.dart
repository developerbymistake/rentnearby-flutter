import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_prefill.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_offer_model.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
