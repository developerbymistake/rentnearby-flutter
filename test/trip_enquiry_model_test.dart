import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_offer_model.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> full() => {
        'id': 'e1',
        'tripId': 't1',
        'kind': 'Stay',
        'listingId': 's1',
        'listingName': 'Deodar Homestay',
        'listingLatitude': 29.38,
        'listingLongitude': 79.46,
        'day': 1,
        'days': null,
        'checkIn': '2026-11-01',
        'checkOut': '2026-11-03',
        'nights': 2,
        'conversationId': 'c1',
        'status': 'Offered',
        'failReason': null,
        'displayStatus': 'offered',
        'expiresAt': '2026-10-30T18:30:00Z',
        'isUrgent': true,
        'agreedTotal': null,
        'acceptedOffer': null,
        'openOffer': {
          'id': 'o1',
          'kind': 'Offer',
          'checkIn': '2026-11-01',
          'checkOut': '2026-11-03',
          'nights': 2,
          'lines': [
            {'roomName': 'Deluxe', 'units': 1, 'guests': 4, 'pricePerNight': 1900},
          ],
          'total': 3800,
          'inclusions': 'Breakfast',
          'needsEchoed': ['no_stairs'],
          'advanceAmount': 500,
          'balanceNote': 'at check-in',
          'cancellationText': 'Free till 24 h before',
          'gstInvoice': false,
          'note': null,
          'validUntil': '2026-10-31T10:00:00Z',
          'status': 'Pending',
          'respondedAt': null,
          'messageId': 'm1',
          'createdAt': '2026-10-30T10:00:00Z',
          'datesDiffer': false,
        },
        'offerCount': 1,
        'context': {
          'city': 'Nainital',
          'adults': 2,
          'kids': 2,
          'rooms': 1,
          'needs': ['no_stairs', 'veg_food'],
          'days': [
            {'day': 1, 'date': '2026-11-01', 'minutes': 335, 'spots': ['Mall Road', 'Naini Lake']},
          ],
          'text': 'Hi, trip to Nainital.',
        },
        'phoneBooking': null,
        'hostConfirm': {
          'linkSent': true,
          'linkCount': 1,
          'canResendAt': '2026-10-29T10:15:00Z',
          'answeredAt': null,
          'answer': null,
          'answeredVia': null,
          'canOverrideUntil': null,
        },
        'advance': {'status': 'None'},
        'taxi': null,
        'traveller': {'id': 'u1', 'name': 'Rahul', 'phone': null},
        'owner': {'id': 'u2', 'name': 'Ramesh', 'phone': '9876543210', 'whatsApp': null},
        'cancelledBy': null,
        'cancelReason': null,
        'createdAt': '2026-10-30T09:00:00Z',
        'updatedAt': '2026-10-30T10:00:00Z',
      };

  test('parses the full DTO', () {
    final e = TripEnquiryModel.fromJson(full());
    expect(e.id, 'e1');
    expect(e.tripId, 't1');
    expect(e.listingId, 's1');
    expect(e.listingName, 'Deodar Homestay');
    expect(e.day, 1);
    expect(e.conversationId, 'c1');
    expect(e.isUrgent, isTrue);
    expect(e.display, TripDisplayStatus.offered);
    expect(e.nights, 2);
    expect(e.context.city, 'Nainital');
    expect(e.context.adults, 2);
    expect(e.context.needs, ['no_stairs', 'veg_food']);
    expect(e.traveller.name, 'Rahul');
    expect(e.owner.phone, '9876543210');
    expect(e.hostConfirm.linkSent, isTrue);
    expect(e.hostConfirm.linkCount, 1);
    expect(e.phoneBooking, isNull);
  });

  test('parses the open offer', () {
    final o = TripEnquiryModel.fromJson(full()).openOffer!;
    expect(o.id, 'o1');
    expect(o.total, 3800);
    expect(o.lines.single.roomName, 'Deluxe');
    expect(o.lines.single.pricePerNight, 1900);
    expect(o.advanceAmount, 500);
    expect(o.status, 'Pending');
    expect(o.datesDiffer, isFalse);
  });

  test('tolerates nulls and missing blocks', () {
    final e = TripEnquiryModel.fromJson({'id': 'e2', 'status': 'Asked'});
    expect(e.id, 'e2');
    expect(e.openOffer, isNull);
    expect(e.acceptedOffer, isNull);
    expect(e.phoneBooking, isNull);
    expect(e.context.needs, isEmpty);
    expect(e.display, TripDisplayStatus.none);
  });

  test('unknown displayStatus becomes none', () {
    final j = full()..['displayStatus'] = 'brandNew';
    expect(TripEnquiryModel.fromJson(j).display, TripDisplayStatus.none);
  });

  test('display status flags', () {
    TripEnquiryModel with0(String status, String display) =>
        TripEnquiryModel.fromJson(full()..['status'] = status..['displayStatus'] = display);
    expect(with0('Asked', 'asked').isOpen, isTrue);
    expect(with0('Expired', 'expired').isOpen, isFalse);
    expect(with0('ConfirmedByTraveller', 'confirmedByYou').isConfirmed, isTrue);
    expect(with0('ConfirmedByBoth', 'confirmedByBoth').isConfirmed, isTrue);
    expect(with0('Offered', 'offered').isConfirmed, isFalse);
    expect(with0('NotAvailable', 'notAvailable').isRed, isTrue);
    expect(with0('Failed', 'notMe').isRed, isTrue);
    expect(with0('Closed', 'closed').isRed, isFalse);
  });

  test('coversDate is half open on check-out', () {
    final e = TripEnquiryModel.fromJson(full());
    expect(e.coversDate(DateTime(2026, 11, 1)), isTrue);
    expect(e.coversDate(DateTime(2026, 11, 2)), isTrue);
    expect(e.coversDate(DateTime(2026, 11, 3)), isFalse);
    expect(e.coversDate(DateTime(2026, 10, 31)), isFalse);
  });

  test('overlaps another range', () {
    final e = TripEnquiryModel.fromJson(full());
    expect(e.overlaps(DateTime(2026, 11, 2), DateTime(2026, 11, 4)), isTrue);
    expect(e.overlaps(DateTime(2026, 11, 3), DateTime(2026, 11, 4)), isFalse);
  });

  test('nights from dates when the server omits it', () {
    final e = TripEnquiryModel.fromJson(full()..remove('nights'));
    expect(e.nights, 2);
  });

  test('phone booking and cancelled fields', () {
    final j = full()
      ..['status'] = 'CancelledByOwner'
      ..['displayStatus'] = 'cancelled'
      ..['cancelledBy'] = 'owner'
      ..['cancelReason'] = 'Water issue'
      ..['phoneBooking'] = {
        'hostName': 'Ramesh Bisht',
        'hostPhone': '9876543210',
        'roomName': 'Deluxe',
        'nights': 1,
        'agreedTotal': 3000,
        'advancePaid': false,
        'advanceAmount': null,
        'note': null,
        'recordedAt': '2026-10-28T10:15:00Z',
        'updatedAt': null,
      };
    final e = TripEnquiryModel.fromJson(j);
    expect(e.display, TripDisplayStatus.cancelled);
    expect(e.cancelledBy, 'owner');
    expect(e.cancelReason, 'Water issue');
    expect(e.phoneBooking!.hostName, 'Ramesh Bisht');
    expect(e.phoneBooking!.agreedTotal, 3000);
    expect(e.phoneBooking!.advancePaid, isFalse);
  });

  test('batch parses items, skipped and veryShortNotice', () {
    final b = TripEnquiryBatch.fromJson({
      'items': [full()],
      'skipped': [
        {'listingId': 's2', 'reason': 'AlreadyOpen'},
      ],
      'veryShortNotice': true,
    });
    expect(b.items.single.id, 'e1');
    expect(b.skipped.single.listingId, 's2');
    expect(b.skipped.single.reason, 'AlreadyOpen');
    expect(b.veryShortNotice, isTrue);
  });

  test('batch parses updated ids, AlreadyBooked and asks left', () {
    final b = TripEnquiryBatch.fromJson({
      'items': [full()],
      'skipped': [
        {'listingId': 's3', 'reason': TripSkipReasons.alreadyBooked},
      ],
      'updated': ['e1'],
    }, asksLeft: 7);
    expect(b.isUpdated('e1'), isTrue);
    expect(b.skipped.single.reason, 'AlreadyBooked');
    expect(b.asksLeft, 7);
  });

  test('taxi dates and last date', () {
    final e = TripEnquiryModel.fromJson({
      'id': 't1',
      'kind': 'Taxi',
      'checkIn': '2026-11-01',
      'days': [1, 2, 3],
    });
    expect(e.taxiDates.last, DateTime(2026, 11, 3));
    expect(e.lastDate, DateTime(2026, 11, 3));
    expect(e.coversTaxiDate(DateTime(2026, 11, 2)), isTrue);
    expect(e.coversTaxiDate(DateTime(2026, 11, 4)), isFalse);
  });

  test('owner page parses counts', () {
    final p = TripOwnerEnquiryPage.fromJson({
      'items': [full()],
      'hasMore': true,
      'counts': {'new': 2, 'offered': 1, 'confirmed': 1, 'closed': 7},
    });
    expect(p.hasMore, isTrue);
    expect(p.counts.newCount, 2);
    expect(p.counts.closed, 7);
  });

  test('phone booking result parses link and text', () {
    final r = TripPhoneBookingResult.fromJson({
      'enquiry': full(),
      'confirmLink': 'https://developerbymistake.tech/go/confirm/abc',
      'whatsAppText': 'Namaste',
    });
    expect(r.enquiry.id, 'e1');
    expect(r.confirmLink, endsWith('/abc'));
    expect(r.whatsAppText, 'Namaste');
  });

  Map<String, dynamic> taxi() => full()
    ..['kind'] = 'Taxi'
    ..['listingId'] = 'x1'
    ..['listingName'] = 'Bisht Cabs'
    ..['day'] = null
    ..['days'] = [1, 2]
    ..['conversationId'] = null
    ..['status'] = 'FareSent'
    ..['displayStatus'] = 'fareSent'
    ..['openOffer'] = null
    ..['advance'] = {'status': 'None'}
    ..['taxi'] = {
      'listedRate': 1800,
      'listedTotal': 3600,
      'driverFare': 3800,
      'driverNote': 'Hill route',
      'driverRepliedAt': '2026-10-30T11:00:00Z',
      'fareEditCount': 1,
      'fareEditsLeft': 2,
      'agreedFare': null,
      'tollExtra': false,
      'pickupTime': '08:30',
      'pickupPlace': 'Mallital',
      'bookedAt': null,
    };

  test('parses the taxi block and days', () {
    final e = TripEnquiryModel.fromJson(taxi());
    expect(e.isTaxi, isTrue);
    expect(e.days, [1, 2]);
    expect(e.display, TripDisplayStatus.fareSent);
    expect(e.isFareSent, isTrue);
    expect(e.isBookedByYou, isFalse);
    final t = e.taxi!;
    expect(t.listedRate, 1800);
    expect(t.listedTotal, 3600);
    expect(t.driverFare, 3800);
    expect(t.driverNote, 'Hill route');
    expect(t.driverRepliedAt, DateTime.utc(2026, 10, 30, 11));
    expect(t.fareEditCount, 1);
    expect(t.fareEditsLeft, 2);
    expect(t.agreedFare, isNull);
    expect(t.tollExtra, isFalse);
    expect(t.pickupTime, '08:30');
    expect(t.pickupPlace, 'Mallital');
    expect(t.bookedAt, isNull);
  });

  test('stay rows have no taxi block and empty days', () {
    final e = TripEnquiryModel.fromJson(full());
    expect(e.isTaxi, isFalse);
    expect(e.taxi, isNull);
    expect(e.days, isEmpty);
  });

  test('booked by traveller taxi row', () {
    final j = taxi()
      ..['status'] = 'BookedByTraveller'
      ..['displayStatus'] = 'bookedByYou';
    (j['taxi'] as Map<String, dynamic>)
      ..['agreedFare'] = 3800
      ..['tollExtra'] = true
      ..['bookedAt'] = '2026-10-30T12:00:00Z';
    final e = TripEnquiryModel.fromJson(j);
    expect(e.isBookedByYou, isTrue);
    expect(e.display, TripDisplayStatus.bookedByYou);
    expect(e.taxi!.agreedFare, 3800);
    expect(e.taxi!.tollExtra, isTrue);
    expect(e.taxi!.bookedAt, isNotNull);
  });

  test('hold expired and fare sent display statuses', () {
    final held = TripEnquiryModel.fromJson(full()
      ..['status'] = 'Failed'
      ..['displayStatus'] = 'holdExpired');
    expect(held.display, TripDisplayStatus.holdExpired);
    expect(held.isRed, isTrue);
    expect(TripEnquiryModel.fromJson(taxi()).isOpen, isTrue);
  });

  test('advance fields', () {
    final j = full()
      ..['status'] = 'ConfirmedByBoth'
      ..['displayStatus'] = 'confirmedByBoth'
      ..['advance'] = {
        'status': 'ProofSent',
        'amount': 500,
        'holdUntil': '2026-11-01T12:30:00Z',
        'askedAt': '2026-10-31T06:30:00Z',
        'proofSentAt': '2026-10-31T08:00:00Z',
        'receivedAt': null,
        'notYetAt': '2026-10-31T09:00:00Z',
        'lastHostReminderAt': '2026-10-31T09:00:00Z',
        'nextHostReminderAt': '2026-10-31T10:00:00Z',
        'reminderCount': 3,
      };
    final a = TripEnquiryModel.fromJson(j).advance;
    expect(a.status, 'ProofSent');
    expect(a.amount, 500);
    expect(a.holdUntil, DateTime.utc(2026, 11, 1, 12, 30));
    expect(a.askedAt, DateTime.utc(2026, 10, 31, 6, 30));
    expect(a.proofSentAt, DateTime.utc(2026, 10, 31, 8));
    expect(a.receivedAt, isNull);
    expect(a.notYetAt, DateTime.utc(2026, 10, 31, 9));
    expect(a.nextHostReminderAt, DateTime.utc(2026, 10, 31, 10));
    expect(a.reminderCount, 3);
    expect(a.isProofSent, isTrue);
    expect(a.isPending, isFalse);
    expect(a.isReceived, isFalse);
    expect(a.isHoldExpired, isFalse);
    expect(a.hasRequest, isTrue);
  });

  test('advance defaults to none', () {
    final a = TripEnquiryModel.fromJson({'id': 'e3', 'status': 'ConfirmedByBoth'}).advance;
    expect(a.status, 'None');
    expect(a.hasRequest, isFalse);
    expect(a.isPending, isFalse);
    expect(a.reminderCount, 0);
  });

  test('holdPassed compares with now', () {
    final a = TripAdvanceModel(status: 'Pending', holdUntil: DateTime.utc(2026, 11, 1, 12));
    expect(a.holdPassed(DateTime.utc(2026, 11, 1, 11, 59)), isFalse);
    expect(a.holdPassed(DateTime.utc(2026, 11, 1, 12)), isTrue);
    expect(a.holdPassed(DateTime.utc(2026, 11, 1, 13)), isTrue);
    expect(const TripAdvanceModel(status: 'Pending').holdPassed(DateTime.utc(2030)), isFalse);
  });

  test('driver lead page parses counts', () {
    final p = TripDriverLeadPage.fromJson({
      'items': [taxi()],
      'hasMore': false,
      'counts': {'new': 2, 'replied': 1, 'booked': 1, 'closed': 4},
    });
    expect(p.items.single.isTaxi, isTrue);
    expect(p.hasMore, isFalse);
    expect(p.counts.newOnes, 2);
    expect(p.counts.replied, 1);
    expect(p.counts.booked, 1);
    expect(p.counts.closed, 4);
  });

  Map<String, dynamic> offerJson(String id, String kind, {int total = 3800, String status = 'Pending'}) => {
        'id': id,
        'kind': kind,
        'checkIn': '2026-11-01',
        'checkOut': '2026-11-02',
        'nights': 1,
        'lines': [
          {'roomName': 'Family room', 'units': 2, 'guests': 4, 'pricePerNight': 1900},
        ],
        'total': total,
        'status': status,
      };

  test('negotiation fields default to none', () {
    final e = TripEnquiryModel.fromJson(full());
    expect(e.pendingCounter, isNull);
    expect(e.pendingRevised, isNull);
    expect(e.pendingChange, isNull);
    expect(e.counterCount, 0);
    expect(e.revisedCount, 0);
    expect(e.hasPendingRevised, isFalse);
    expect(e.hasPendingChange, isFalse);
  });

  test('parses pending counter, revised and change rows', () {
    final j = full()
      ..['pendingCounter'] = offerJson('c1', 'Counter', total: 3600)
      ..['pendingRevised'] = (offerJson('r1', 'Revised', total: 4200)
        ..['oldTotal'] = 3800
        ..['reason'] = 'Diwali week rate'
        ..['note'] = 'Diwali week rate')
      ..['pendingChange'] = (offerJson('x1', 'ChangeRequest')
        ..['adults'] = 3
        ..['kids'] = 1)
      ..['counterCount'] = 2
      ..['revisedCount'] = 1;
    final e = TripEnquiryModel.fromJson(j);
    expect(e.pendingCounter!.isCounter, isTrue);
    expect(e.pendingCounter!.lines.single.pricePerNight, 1900);
    expect(e.pendingRevised!.isRevised, isTrue);
    expect(e.pendingRevised!.oldTotal, 3800);
    expect(e.pendingRevised!.total, 4200);
    expect(e.pendingRevised!.reason, 'Diwali week rate');
    expect(e.pendingChange!.isChangeRequest, isTrue);
    expect(e.pendingChange!.adults, 3);
    expect(e.pendingChange!.kids, 1);
    expect(e.pendingChange!.rooms, 2);
    expect(e.pendingChange!.guests, 4);
    expect(e.counterCount, 2);
    expect(e.revisedCount, 1);
    expect(e.hasPendingRevised, isTrue);
    expect(e.hasPendingChange, isTrue);
  });

  test('offer kind getters', () {
    expect(TripOfferModel.fromJson(offerJson('a', 'Offer')).isCounter, isFalse);
    expect(TripOfferModel.fromJson(offerJson('b', 'Counter')).isCounter, isTrue);
    expect(TripOfferModel.fromJson(offerJson('c', 'Revised')).isRevised, isTrue);
    expect(TripOfferModel.fromJson(offerJson('d', 'ChangeRequest')).isChangeRequest, isTrue);
    final o = TripOfferModel.fromJson(offerJson('e', 'Offer'));
    expect(o.adults, isNull);
    expect(o.kids, isNull);
    expect(o.oldTotal, isNull);
  });

  test('canCounter follows status, limit and conversation', () {
    expect(TripEnquiryModel.fromJson(full()).canCounter, isTrue);
    expect(TripEnquiryModel.fromJson(full()..['displayStatus'] = 'asked').canCounter, isTrue);
    expect(TripEnquiryModel.fromJson(full()..['counterCount'] = 3).canCounter, isFalse);
    expect(TripEnquiryModel.fromJson(full()..['counterCount'] = 2).canCounter, isTrue);
    expect(TripEnquiryModel.fromJson(full()..['conversationId'] = null).canCounter, isFalse);
    expect(TripEnquiryModel.fromJson(full()..['displayStatus'] = 'confirmedByBoth').canCounter, isFalse);
    expect(TripEnquiryModel.fromJson(full()..['displayStatus'] = 'notAvailable').canCounter, isFalse);
  });

  test('canChangeRequest needs a confirmed stay with an accepted offer and no pending change', () {
    final confirmed = full()
      ..['status'] = 'ConfirmedByBoth'
      ..['displayStatus'] = 'confirmedByBoth'
      ..['agreedTotal'] = 3800
      ..['acceptedOffer'] = offerJson('o1', 'Offer', status: 'Accepted');
    expect(TripEnquiryModel.fromJson(confirmed).canChangeRequest, isTrue);
    expect(TripEnquiryModel.fromJson(Map<String, dynamic>.from(confirmed)..['acceptedOffer'] = null).canChangeRequest, isFalse);
    expect(
      TripEnquiryModel.fromJson(Map<String, dynamic>.from(confirmed)..['pendingChange'] = offerJson('x1', 'ChangeRequest')).canChangeRequest,
      isFalse,
    );
    expect(TripEnquiryModel.fromJson(full()).canChangeRequest, isFalse);
  });

  test('agreedTotalLocked ignores a pending revised total', () {
    final j = full()
      ..['status'] = 'ConfirmedByBoth'
      ..['displayStatus'] = 'confirmedByBoth'
      ..['agreedTotal'] = 3800
      ..['acceptedOffer'] = offerJson('o1', 'Offer', status: 'Accepted')
      ..['pendingRevised'] = offerJson('r1', 'Revised', total: 4200);
    expect(TripEnquiryModel.fromJson(j).agreedTotalLocked, 3800);
  });

  test('trip summary model exposes the booking state', () {
    final s = TripSummaryModel.fromJson({
      'id': 't1',
      'title': 'Nainital trip',
      'status': 'Planned',
      'cityName': 'Nainital',
      'updatedAt': '2026-11-01T10:00:00Z',
      'bookingState': 'confirming',
      'staysConfirmed': 1,
      'staysTotal': 2,
      'taxisConfirmed': 0,
      'taxisTotal': 1,
      'agreedTotal': 3800,
      'completedAt': null,
    });
    expect(s.state, TripBookingState.confirming);
    expect(s.staysConfirmed, 1);
    expect(s.staysTotal, 2);
    expect(s.taxisTotal, 1);
    expect(s.agreedTotal, 3800);
    expect(s.isCompleted, isFalse);
    expect(TripSummaryModel.fromJson({'id': 't2', 'status': 'Completed', 'bookingState': 'completed'}).isCompleted, isTrue);
    expect(TripSummaryModel.fromJson({'id': 't3'}).state, TripBookingState.draft);
  });
}
