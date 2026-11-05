import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_mcb_a1.dart';
import 'package:bakhli/features/trip/utils/trip_travel_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final _travelDate = DateTime(2030, 11, 2);

const _arrival = TripTravel.journey(fromName: 'Haridwar', journeyId: 'j1', cars: 2);

TripJourneyLeg _car(int i, {String status = 'Unknown', String? asked, bool available = true, String name = ''}) =>
    TripJourneyLeg(
      legIndex: i,
      fromName: 'Haridwar',
      toName: 'Badrinath',
      lastKnownStatus: status,
      lastEnquiryId: asked,
      driverAvailable: available,
      driverName: name,
      taxiId: 'taxi$i',
    );

TripJourney _journey(List<TripJourneyLeg> legs, {DateTime? date}) => TripJourney(
      id: 'j1',
      fromName: 'Haridwar',
      toName: 'Badrinath',
      date: date ?? _travelDate,
      cars: legs.length,
      legs: legs,
      legIndex: 2,
      travelDay: 2,
    );

TripEnquiryModel _row(int car, String status, {String journeyId = 'j1'}) => TripEnquiryModel(
      id: 'e$car$status',
      tripId: 't1',
      kind: TripEnquiryKinds.taxi,
      day: 2,
      status: status,
      context: TripEnquiryContext(journeyId: journeyId, journeyLegIndex: car),
    );

TripTravelState _state(TripJourney? j, {List<TripEnquiryModel> rows = const [], TripTravel? arrival = _arrival, bool gap = false}) =>
    TripTravelRules.stateOf(arrival: arrival, journey: j, journeyRows: rows, travelDate: _travelDate, gap: gap);

void main() {
  group('travel state table (D7)', () {
    test('1 no arrival with a session gap is gap', () {
      expect(_state(null, arrival: null, gap: true), TripTravelState.gap);
    });

    test('2 no arrival is not planned', () {
      expect(_state(null, arrival: null), TripTravelState.notPlanned);
    });

    test('3 own arrival is own, even with a gap', () {
      expect(_state(null, arrival: const TripTravel.own(fromName: 'Haridwar'), gap: true), TripTravelState.own);
    });

    test('4 missing journey is not planned', () {
      expect(_state(null), TripTravelState.notPlanned);
    });

    test('5 date changed beats car missing', () {
      final j = _journey([_car(1, status: 'NotFree', asked: 'x')], date: DateTime(2030, 11, 3));
      expect(_state(j), TripTravelState.dateChanged);
    });

    test('6 a car whose driver said not free, or every asked row is red, is car missing', () {
      expect(_state(_journey([_car(1), _car(2, status: 'NotFree', asked: 'x')])), TripTravelState.carMissing);
      final j = _journey([_car(1, asked: 'a'), _car(2)]);
      expect(_state(j, rows: [_row(1, 'NotAvailable'), _row(1, 'Expired')]), TripTravelState.carMissing);
    });

    test('7 a paused driver on an unbooked car is driver unavailable; a booked car stays booked', () {
      expect(_state(_journey([_car(1, available: false), _car(2)])), TripTravelState.driverUnavailable);
      final j = _journey([_car(1, available: false, asked: 'a')]);
      expect(_state(j, rows: [_row(1, TripEnquiryStatuses.bookedByTraveller)]), TripTravelState.booked);
    });

    test('8 every car booked is booked, every car confirmed is confirmed', () {
      final j = _journey([_car(1, asked: 'a'), _car(2, asked: 'b')]);
      expect(
        _state(j, rows: [_row(1, TripEnquiryStatuses.bookedByTraveller), _row(2, TripEnquiryStatuses.confirmedByBoth)]),
        TripTravelState.booked,
      );
      expect(
        _state(j, rows: [_row(1, TripEnquiryStatuses.confirmedByBoth), _row(2, TripEnquiryStatuses.confirmedByBoth)]),
        TripTravelState.confirmed,
      );
    });

    test('9 some car booked is partly booked', () {
      final j = _journey([_car(1, asked: 'a'), _car(2, asked: 'b')]);
      expect(_state(j, rows: [_row(1, TripEnquiryStatuses.bookedByTraveller)]), TripTravelState.partlyBooked);
    });

    test('10 nobody asked is saved', () {
      expect(_state(_journey([_car(1), _car(2)])), TripTravelState.saved);
    });

    test('11 every asked car free is free', () {
      final j = _journey([_car(1, status: 'Free', asked: 'a', name: 'Sunil'), _car(2, status: 'Free', asked: 'b')]);
      expect(_state(j), TripTravelState.free);
      expect(TripTravelRules.freeNames(j, const []), ['Sunil']);
    });

    test('12 asked without every answer is asked', () {
      final j = _journey([_car(1, status: 'Free', asked: 'a'), _car(2, asked: 'b')]);
      expect(_state(j), TripTravelState.asked);
      expect(TripTravelRules.answeredCount(j), 1);
    });

    test('closed rows and rows of another journey are ignored', () {
      final j = _journey([_car(1, asked: 'a')]);
      final rows = TripTravelRules.liveRowsOf('j1', [
        _row(1, TripEnquiryStatuses.closed),
        _row(1, TripEnquiryStatuses.bookedByTraveller, journeyId: 'j9'),
      ]);
      expect(rows, isEmpty);
      expect(_state(j, rows: rows), TripTravelState.asked);
    });
  });

  group('impact and booking per car', () {
    test('impact counts booked and open rows, never red', () {
      final i = TripTravelRules.impactOf([
        _row(1, TripEnquiryStatuses.bookedByTraveller),
        _row(2, TripEnquiryStatuses.asked),
        _row(2, 'NotAvailable'),
      ], cars: 2);
      expect(i.bookedRows, 1);
      expect(i.openRows, 1);
      expect(i.hasBooked, isTrue);
    });

    test('confirmed booking wins for a car', () {
      final b = TripTravelRules.carBooking(1, [
        _row(1, TripEnquiryStatuses.bookedByTraveller),
        _row(1, TripEnquiryStatuses.confirmedByBoth),
      ]);
      expect(b?.status, TripEnquiryStatuses.confirmedByBoth);
      expect(TripTravelRules.carBooking(2, [_row(1, TripEnquiryStatuses.confirmedByBoth)]), isNull);
    });

    test('every state has a short label', () {
      for (final s in TripTravelState.values) {
        expect(TripStringsMcbA1.stateLabel(s), isNotEmpty);
      }
      expect(TripTravelState.parse('booked'), TripTravelState.booked);
      expect(TripTravelState.parse('nope'), isNull);
    });
  });
}
