import 'package:get/get.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_stay_base.dart';
import 'package:flutter_test/flutter_test.dart';

const _spot = TripSpotRef(id: 'a', name: 'Naini Lake', latitude: 29.39, longitude: 79.45, category: 'lake', visitMinutes: 60);

TripPlan _nainital(int days) => TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      centreLatitude: 29.3919,
      centreLongitude: 79.4542,
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      days: [for (var i = 1; i <= days; i++) TripDay(day: i, spots: const [_spot])],
    );

TripEnquiryModel _confirmed(double lat, double lng) => TripEnquiryModel(
      id: 'e1',
      tripId: 't1',
      listingId: 's1',
      listingName: 'Lake Inn',
      listingLatitude: lat,
      listingLongitude: lng,
      status: TripEnquiryStatuses.confirmedByBoth,
      checkIn: DateTime(2030, 11, 1),
      checkOut: DateTime(2030, 11, 3),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('per-day planner points from the confirmed stay', () {
    test('every day of the city runs from and to the confirmed stay', () {
      final p = _nainital(3);
      final rows = [_confirmed(29.39, 79.45)];
      expect(TripStayBase.dayEnds(p, 1, rows), (start: (lat: 29.39, lng: 79.45), end: (lat: 29.39, lng: 79.45)));
      expect(TripStayBase.dayEnds(p, 2, rows), (start: (lat: 29.39, lng: 79.45), end: (lat: 29.39, lng: 79.45)));
    });

    test('a stay far from the city gives no point', () {
      final p = _nainital(2);
      final rows = [_confirmed(28.61, 77.21)];
      expect(TripStayBase.dayEnds(p, 1, rows), (start: null, end: null));
      expect(TripStayBase.dayBodyOf(p, 1, rows), isEmpty);
    });

    test('the recalculate request carries each day\'s points and auto carries the anchor', () {
      final c = TripPlanController();
      addTearDown(c.onClose);
      c.enquiryList.assignAll([_confirmed(29.39, 79.45)]);
      final p = _nainital(2);
      final days = c.planBodyForTest(p, 1, 'recalculate')['days'] as List;
      expect((days[0] as Map)['startLatitude'], 29.39);
      expect((days[1] as Map)['endLongitude'], 79.45);
      final auto = c.planBodyForTest(p, 1, 'auto');
      expect(auto.containsKey('days'), isFalse);
      expect(auto['anchorLatitude'], 29.39);
    });

    test('without a confirmed stay the request has no points', () {
      final c = TripPlanController();
      addTearDown(c.onClose);
      final days = c.planBodyForTest(_nainital(2), 1, 'recalculate')['days'] as List;
      expect((days[0] as Map).containsKey('startLatitude'), isFalse);
      expect(c.planBodyForTest(_nainital(2), 1, 'auto').containsKey('anchorLatitude'), isFalse);
    });
  });

  group('plan request without dates or people', () {
    test('a plan with no start date sends no date and still plans', () {
      final c = TripPlanController();
      addTearDown(c.onClose);
      final p = TripPlan.singleCity(
        cityKey: 1,
        cityName: 'Nainital',
        centreLatitude: 29.3919,
        centreLongitude: 79.4542,
        days: const [TripDay(day: 1, spots: [_spot])],
      );
      final body = c.planBodyForTest(p, 1, 'recalculate');
      expect(body.containsKey('startDate'), isFalse);
      expect(body['dayLimitMinutes'], 300);
    });
  });
}
