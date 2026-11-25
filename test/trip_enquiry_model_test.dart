import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_offer_model.dart';
import 'package:bakhli/features/trip/widgets/trip_lifecycle_actions.dart';
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
          'days': [
            {'day': 1, 'date': '2026-11-01', 'minutes': 335, 'spots': ['Mall Road', 'Naini Lake']},
          ],
          'text': 'Hi, trip to Nainital.',
        },
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
    expect(e.traveller.name, 'Rahul');
    expect(e.owner.phone, '9876543210');
  });

  test('parses the open offer', () {
    final o = TripEnquiryModel.fromJson(full()).openOffer!;
    expect(o.id, 'o1');
    expect(o.total, 3800);
    expect(o.lines.single.roomName, 'Deluxe');
    expect(o.lines.single.pricePerNight, 1900);
    expect(o.status, 'Pending');
    expect(o.datesDiffer, isFalse);
  });

  test('tolerates nulls and missing blocks', () {
    final e = TripEnquiryModel.fromJson({'id': 'e2', 'status': 'Asked'});
    expect(e.id, 'e2');
    expect(e.openOffer, isNull);
    expect(e.acceptedOffer, isNull);
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

  test('cancelled fields', () {
    final j = full()
      ..['status'] = 'CancelledByOwner'
      ..['displayStatus'] = 'cancelled'
      ..['cancelledBy'] = 'owner'
      ..['cancelReason'] = 'Water issue';
    final e = TripEnquiryModel.fromJson(j);
    expect(e.display, TripDisplayStatus.cancelled);
    expect(e.cancelledBy, 'owner');
    expect(e.cancelReason, 'Water issue');
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

  test('an old holdExpired wire status reads as none and fare sent stays open', () {
    final old = TripEnquiryModel.fromJson(full()
      ..['status'] = 'Failed'
      ..['displayStatus'] = 'holdExpired');
    expect(old.display, TripDisplayStatus.none);
    expect(TripEnquiryModel.fromJson(taxi()).isOpen, isTrue);
  });

  test('an old payload with an advance block and offer advanceAmount still parses', () {
    final j = full()
      ..['status'] = 'ConfirmedByBoth'
      ..['displayStatus'] = 'confirmedByBoth'
      ..['advance'] = {'status': 'ProofSent', 'amount': 500, 'holdUntil': '2026-11-01T12:30:00Z'};
    (j['openOffer'] as Map<String, dynamic>)['advanceAmount'] = 500;
    final e = TripEnquiryModel.fromJson(j);
    expect(e.isConfirmedByBoth, isTrue);
    expect(e.openOffer!.total, 3800);
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

  test('silence fields: isQuiet, stepKey fallback, endReason, undoUntil, offersLeft, ownerShare', () {
    final plain = TripEnquiryModel.fromJson(full());
    expect(plain.isQuiet, isFalse);
    expect(plain.endReason, isNull);
    expect(plain.undoUntil, isNull);
    expect(plain.ownerShare, isNull);
    expect(plain.stepKeyOrLeg, 'stay:1');
    expect(TripEnquiryModel.fromJson(full()..['cityLeg'] = 2).stepKeyOrLeg, 'stay:2');
    final e = TripEnquiryModel.fromJson(full()
      ..['isQuiet'] = true
      ..['quietAt'] = '2026-10-30T06:30:00Z'
      ..['stepKey'] = 'stay:3'
      ..['endReason'] = 'stayPaused'
      ..['undoUntil'] = '2026-10-30T06:30:10Z'
      ..['offersLeft'] = 0
      ..['waitingHours'] = 13
      ..['ownerShare'] = {'upiId': 'host@upi', 'whatsApp': '9876543210', 'sharedAt': '2026-10-30T07:00:00Z'});
    expect(e.isQuiet, isTrue);
    expect(e.quietAt, DateTime.utc(2026, 10, 30, 6, 30));
    expect(e.stepKeyOrLeg, 'stay:3');
    expect(e.endReason, TripEndReasons.stayPaused);
    expect(e.canUndoAt(DateTime.utc(2026, 10, 30, 6, 30, 5)), isTrue);
    expect(e.canUndoAt(DateTime.utc(2026, 10, 30, 6, 30, 11)), isFalse);
    expect(e.offersLeft, 0);
    expect(e.waitingHours, 13);
    expect(e.ownerShare?.upiId, 'host@upi');
    expect(e.ownerShare?.whatsApp, '9876543210');
  });

  test('send result carries the other trip and maps the new skip reasons', () {
    final r = TripSendResult.fromJson({'listingId': 's1', 'status': 'OpenInAnotherTrip', 'otherTripId': 't9', 'otherTripTitle': 'Goa trip', 'otherEnquiryId': 'e9'});
    expect((r.otherTrip, r.otherTripId, r.otherTripTitle, r.otherEnquiryId), (true, 't9', 'Goa trip', 'e9'));
    const batch = TripEnquiryBatch(items: [], skipped: [
      TripSkipped(listingId: 'a', reason: TripSkipReasons.alreadyBooked),
      TripSkipped(listingId: 'b', reason: TripSkipReasons.openForOtherNights),
    ], veryShortNotice: false);
    expect([for (final x in batch.perRecipient) x.status], ['AlreadyBooked', 'OpenForOtherNights']);
  });

  test('trip delete lines name the open asks and the bookings', () {
    TripEnquiryModel row(String id, String name, String status) =>
        TripEnquiryModel.fromJson({...full(), 'id': id, 'listingId': id, 'listingName': name, 'status': status});
    final lines = TripLifecycleActions.deleteLines([
      row('a', 'Deodar Homestay', 'Asked'),
      row('b', 'Lake View', 'Offered'),
      row('c', 'Pine Cottage', 'ConfirmedByBoth'),
      row('d', 'Old Inn', 'Closed'),
    ]);
    expect(lines, [
      'Your enquiries to Deodar Homestay, Lake View will be withdrawn.',
      'Your booking at Pine Cottage is cancelled and the host is told.',
    ]);
  });

  test('a full stay keeps status NotAvailable and reads full on dates', () {
    final r = TripSendResult.fromJson({'listingId': 's1', 'status': 'NotAvailable', 'reason': 'FullOnDates'});
    expect((r.gone, r.fullOnDates), (true, true));
    expect(TripSendResult.fromJson({'listingId': 's2', 'status': 'NotAvailable', 'reason': 'NotAvailable'}).fullOnDates, false);
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
    expect(s.agreedTotal, 3800);
    expect(s.isCompleted, isFalse);
    expect(TripSummaryModel.fromJson({'id': 't2', 'status': 'Completed', 'bookingState': 'completed'}).isCompleted, isTrue);
    expect(TripSummaryModel.fromJson({'id': 't3'}).state, TripBookingState.draft);
  });

  test('wrong city and outside trip flags parse, defaults on an old row (MC-C)', () {
    final e = TripEnquiryModel.fromJson({
      'id': 'e9',
      'kind': 'Stay',
      'wrongCity': true,
      'wrongNights': 1,
      'wrongTotal': 3,
      'wrongFirstDay': 2,
      'wrongDayCity': 'Badrinath',
      'outsideTrip': true,
    });
    expect(e.wrongCity, isTrue);
    expect(e.wrongNights, 1);
    expect(e.wrongTotal, 3);
    expect(e.wrongFirstDay, 2);
    expect(e.wrongDayCity, 'Badrinath');
    expect(e.outsideTrip, isTrue);
    final old = TripEnquiryModel.fromJson({'id': 'e10', 'kind': 'Stay'});
    expect(old.wrongCity, isFalse);
    expect(old.wrongNights, 0);
    expect(old.wrongTotal, 0);
    expect(old.wrongFirstDay, isNull);
    expect(old.wrongDayCity, isNull);
    expect(old.outsideTrip, isFalse);
  });

  test('journey row context carries the role; problem statuses are host or driver side only', () {
    final e = TripEnquiryModel.fromJson({
      'id': 'r1',
      'tripId': 't1',
      'kind': 'Taxi',
      'day': 3,
      'status': 'Asked',
      'context': {'journeyId': 'j1', 'journeyLegIndex': 2, 'role': 'comingBack'},
    });
    expect(e.context.role, 'comingBack');
    expect(e.isSegment, isTrue);
    expect(TripEnquiryModel.fromJson({'id': 'x', 'context': {'role': ''}}).context.role, isNull);
    for (final s in ['NotAvailable', 'Expired', 'Failed', 'CancelledByOwner']) {
      expect(TripEnquiryModel(id: 'p', status: s).isProblem, isTrue, reason: s);
    }
    for (final s in ['Declined', 'CancelledByTraveller', 'Closed', 'Asked', 'ConfirmedByBoth']) {
      expect(TripEnquiryModel(id: 'p', status: s).isProblem, isFalse, reason: s);
    }
  });

  test('cityLeg is parsed and optional', () {
    expect(TripEnquiryModel.fromJson({'id': 'a', 'kind': 'Taxi', 'cityLeg': 2}).cityLeg, 2);
    expect(TripEnquiryModel.fromJson({'id': 'b', 'kind': 'Taxi'}).cityLeg, isNull);
  });
}
