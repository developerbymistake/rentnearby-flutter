import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_stay_base.dart';
import 'package:flutter_test/flutter_test.dart';

const _nainital = TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.3919, longitude: 79.4542);
const _almora = TripCityLeg(index: 2, cityKey: 2, cityName: 'Almora', latitude: 29.5971, longitude: 79.6591);

TripPlan _plan(List<TripDay> days, {List<TripCityLeg>? legs}) => TripPlan(
      legs: legs ?? const [_nainital],
      days: days,
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
    );

TripEnquiryModel _stay(
  String id, {
  String status = TripEnquiryStatuses.confirmedByBoth,
  double? lat = 29.39,
  double? lng = 79.45,
  int night = 1,
  int nights = 2,
  String name = 'Pine Lodge',
  String kind = TripEnquiryKinds.stay,
  String? journeyId,
}) =>
    TripEnquiryModel(
      id: id,
      tripId: 't1',
      kind: kind,
      listingId: 'l-$id',
      listingName: name,
      listingLatitude: lat,
      listingLongitude: lng,
      status: status,
      day: kind == TripEnquiryKinds.taxi ? night : null,
      checkIn: DateTime(2030, 11, night),
      checkOut: DateTime(2030, 11, night + nights),
      context: TripEnquiryContext(journeyId: journeyId),
    );

TripPlan _threeDays() => _plan(const [TripDay(day: 1), TripDay(day: 2), TripDay(day: 3)]);

void main() {
  group('base of a city', () {
    test('the confirmed stay of the city is the base', () {
      expect(TripStayBase.of(_threeDays(), 1, [_stay('e1')]), (lat: 29.39, lng: 79.45));
    });

    test('a traveller-confirmed or booked stay counts, an open ask does not', () {
      expect(TripStayBase.of(_threeDays(), 1, [_stay('e1', status: TripEnquiryStatuses.confirmedByTraveller)]), isNotNull);
      expect(TripStayBase.of(_threeDays(), 1, [_stay('e1', status: TripEnquiryStatuses.asked)]), isNull);
      expect(TripStayBase.of(_threeDays(), 1, [_stay('e1', status: TripEnquiryStatuses.offered)]), isNull);
      expect(TripStayBase.of(_threeDays(), 1, const []), isNull);
    });

    test('two stays at the same place keep the base, two different places give none', () {
      final same = [_stay('e1', nights: 1), _stay('e2', night: 2, nights: 1)];
      expect(TripStayBase.of(_threeDays(), 1, same), (lat: 29.39, lng: 79.45));
      final apart = [_stay('e1', nights: 1), _stay('e2', night: 2, nights: 1, lat: 29.40, lng: 79.46)];
      expect(TripStayBase.of(_threeDays(), 1, apart), isNull);
    });

    test('a stay without a pin gives no base', () {
      expect(TripStayBase.of(_threeDays(), 1, [_stay('e1', lat: null, lng: null)]), isNull);
      expect(TripStayBase.of(_threeDays(), 1, [_stay('e1', lat: double.nan, lng: 79.45)]), isNull);
    });

    test('a stay far from the city gives no base', () {
      expect(TripStayBase.of(_threeDays(), 1, [_stay('e1', lat: 28.61, lng: 77.21)]), isNull);
    });

    test('taxi and journey rows never make a base', () {
      expect(TripStayBase.of(_threeDays(), 1, [_stay('t1', kind: TripEnquiryKinds.taxi)]), isNull);
      expect(TripStayBase.of(_threeDays(), 1, [_stay('s1', kind: TripEnquiryKinds.taxi, journeyId: 'j1')]), isNull);
    });

    test('a stay whose nights fall in another city is ignored', () {
      final p = _plan(
        const [TripDay(day: 1, leg: 1), TripDay(day: 2, leg: 2), TripDay(day: 3, leg: 2)],
        legs: const [_nainital, _almora],
      );
      final inAlmora = _stay('e1', night: 2, nights: 2, lat: 29.60, lng: 79.66);
      expect(TripStayBase.of(p, 1, [inAlmora]), isNull);
      expect(TripStayBase.of(p, 2, [inAlmora]), (lat: 29.60, lng: 79.66));
    });

    test('a leg without a point has no base', () {
      final p = _plan(
        const [TripDay(day: 1)],
        legs: const [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 0, longitude: 0)],
      );
      expect(TripStayBase.of(p, 1, [_stay('e1')]), isNull);
      expect(TripStayBase.of(p, 4, [_stay('e1')]), isNull);
    });
  });

  group('days of a city', () {
    test('every day starts and ends at the base', () {
      final e = _stay('e1');
      expect(TripStayBase.dayEnds(_threeDays(), 2, [e]), (start: (lat: 29.39, lng: 79.45), end: (lat: 29.39, lng: 79.45)));
      expect(TripStayBase.dayEnds(_threeDays(), 9, [e]), (start: null, end: null));
      expect(TripStayBase.dayEnds(_threeDays(), 1, const []), (start: null, end: null));
    });

    test('the first day of a city has no start point, later days do', () {
      final e = _stay('e1');
      expect(TripStayBase.startOf(_threeDays(), 1, [e]), isNull);
      expect(TripStayBase.startOf(_threeDays(), 2, [e]), (lat: 29.39, lng: 79.45));
    });

    test('request bodies carry the anchor only when there is one', () {
      final e = _stay('e1');
      expect(TripStayBase.bodyOf(_threeDays(), 1, [e]), {'anchorLatitude': 29.39, 'anchorLongitude': 79.45});
      expect(TripStayBase.bodyOf(_threeDays(), 1, const []), isEmpty);
      final day = TripStayBase.dayBodyOf(_threeDays(), 2, [e]);
      expect(day['startLatitude'], 29.39);
      expect(day['endLongitude'], 79.45);
      expect(TripStayBase.dayBodyOf(_threeDays(), 2, const []), isEmpty);
    });

    test('the name of the base is the listing name', () {
      expect(TripStayBase.nameOf(_threeDays(), 1, [_stay('e1')]), 'Pine Lodge');
      expect(TripStayBase.nameOf(_threeDays(), 1, [_stay('e1', name: '  ')]), isNull);
      expect(TripStayBase.nameOf(_threeDays(), 1, const []), isNull);
    });
  });
}
