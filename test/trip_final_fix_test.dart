import 'package:get/get.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_enquiry_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlan _twoLegs({int firstDays = 1}) => TripPlan.fromJson({
      'version': 6,
      'cityKey': 1,
      'cityName': 'Haridwar',
      'legs': [
        {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
        {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49},
      ],
      'settings': {'startDate': '2030-11-01'},
      'days': [
        for (var i = 1; i <= firstDays; i++) {'day': i, 'leg': 1, 'spots': [_spot('a$i').toJson()]},
        {'day': firstDays + 1, 'leg': 2, 'spots': [_spot('b').toJson()]},
        {'day': firstDays + 2, 'leg': 2, 'spots': []},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a city cannot grow while a later city has bookings (#63)', () {
    final c = TripPlanController();
    addTearDown(c.onClose);
    c.plan.value = _twoLegs();
    expect(c.canSetLegDays(1, 2), TripLegEditBlock.none);
    c.enquiryList.assignAll([
      TripEnquiryModel(
        id: 'e1',
        listingId: 's1',
        status: TripEnquiryStatuses.confirmedByBoth,
        checkIn: DateTime(2030, 11, 2),
        checkOut: DateTime(2030, 11, 3),
      ),
    ]);
    expect(c.canSetLegDays(1, 2), TripLegEditBlock.bookings);
    expect(c.canSetLegDays(1, 2, keepBookings: true), TripLegEditBlock.bookings);
    expect(c.maxDaysForLeg(1), 1);
  });

  test('a no-driver gap follows its city pair and drops with a removed city (#65)', () {
    final c = TripPlanController();
    final three = TripPlan.fromJson({
      'version': 6,
      'cityKey': 1,
      'cityName': 'A',
      'legs': [
        {'index': 1, 'cityKey': 1, 'cityName': 'A', 'latitude': 1, 'longitude': 1},
        {'index': 2, 'cityKey': 2, 'cityName': 'B', 'latitude': 2, 'longitude': 2},
        {'index': 3, 'cityKey': 3, 'cityName': 'C', 'latitude': 3, 'longitude': 3},
      ],
      'days': [
        {'day': 1, 'leg': 1, 'spots': []},
        {'day': 2, 'leg': 2, 'spots': []},
        {'day': 3, 'leg': 3, 'spots': []},
      ],
    });
    final twoAC = TripPlan.fromJson({
      'version': 6,
      'cityKey': 1,
      'cityName': 'A',
      'legs': [
        {'index': 1, 'cityKey': 1, 'cityName': 'A', 'latitude': 1, 'longitude': 1},
        {'index': 2, 'cityKey': 3, 'cityName': 'C', 'latitude': 3, 'longitude': 3},
      ],
      'days': [
        {'day': 1, 'leg': 1, 'spots': []},
        {'day': 2, 'leg': 2, 'spots': []},
      ],
    });
    c.travelGaps[2] = 'Rishikesh';
    c.remapTravelGapsForTest(three, twoAC);
    expect(c.travelGaps, isEmpty);
    c.travelGaps[3] = null;
    c.remapTravelGapsForTest(three, three);
    expect(c.travelGaps.containsKey(3), isTrue);
  });

  test('the check-out day keeps the trip live but every day read-only (#50)', () {
    final c = TripPlanController();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 2);
    c.plan.value = TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      settings: TripSettings(startDate: start),
      days: [
        TripDay(day: 1, spots: [_spot('a')]),
        TripDay(day: 2, spots: [_spot('b')]),
      ],
    );
    expect(c.isCheckOutDay, isTrue);
    expect(c.isPastTrip, isFalse);
    expect(c.isReadOnly, isFalse);
    expect(c.todayDay, isNull);
    expect(c.canEditDay(2), isFalse);
    expect(c.canAddPlaces(1), isFalse);
  });


  test('a host that had no room is not asked again (#53)', () {
    final failed = TripEnquiryModel(
      id: 'e1',
      listingId: 's1',
      status: TripEnquiryStatuses.closed,
      failReason: 'ProblemHostNoRoom',
      checkIn: DateTime(2030, 11, 2),
      checkOut: DateTime(2030, 11, 4),
    );
    expect(TripEnquiryRules.hostRefused(failed), isTrue);
  });
}
