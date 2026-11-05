import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/utils/trip_travel_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _raw({bool legs = true}) => {
      'id': 't1',
      'title': 'Haridwar, Badrinath trip',
      'cityKey': 1,
      'cityName': 'Haridwar',
      'dayCount': 3,
      if (legs) 'legCount': 2,
      if (legs) 'legCities': ['Haridwar', 'Badrinath'],
      'plan': {
        'version': 4,
        'cityKey': 1,
        'cityName': 'Haridwar',
        'legs': [
          {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
          {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49},
        ],
        'days': [
          {'day': 1, 'leg': 1},
          {'day': 2, 'leg': 2},
          {'day': 3, 'leg': 2},
        ],
      },
    };

void main() {
  group('TripModel legs', () {
    test('two-leg JSON parses count, cities and route line', () {
      final t = TripModel.fromJson(_raw());
      expect(t.legCount, 2);
      expect(t.legCities, ['Haridwar', 'Badrinath']);
      expect(t.routeLine, 'Haridwar → Badrinath');
      expect(t.plan.legCount, 2);
    });

    test('a one-city JSON defaults to one leg and the city name', () {
      final t = TripModel.fromJson(_raw(legs: false));
      expect(t.legCount, 1);
      expect(t.legCities, ['Haridwar']);
      expect(t.routeLine, 'Haridwar');
    });

    test('copyWith keeps the leg fields', () {
      final t = TripModel.fromJson(_raw()).copyWith(title: 'x');
      expect(t.legCount, 2);
      expect(t.routeLine, 'Haridwar → Badrinath');
    });

    test('the raw map the offline cache stores parses back to the same legs', () {
      final t = TripModel.fromJson(_raw());
      final again = TripModel.fromJson(t.raw!);
      expect(again.plan.legs.length, 2);
      expect(again.plan.days.last.leg, 2);
      expect(again.legCities, t.legCities);
    });
  });

  group('TripSummaryModel legs', () {
    Map<String, dynamic> json({bool legs = true}) => {
          'id': 't1',
          'cityName': 'Haridwar',
          'dayCount': 3,
          if (legs) 'legCount': 2,
          if (legs) 'legCities': ['Haridwar', 'Badrinath'],
        };

    test('parses legs', () {
      final s = TripSummaryModel.fromJson(json());
      expect(s.legCount, 2);
      expect(s.routeLine, 'Haridwar → Badrinath');
      expect(s.asCompleted(null).legCount, 2);
    });

    test('old JSON defaults to one city', () {
      final s = TripSummaryModel.fromJson(json(legs: false));
      expect(s.legCount, 1);
      expect(s.legCities, ['Haridwar']);
      expect(s.routeLine, 'Haridwar');
    });

    test('summary record cities default to the city and give a route', () {
      expect(TripSummaryRecord.fromJson({'tripId': 'a', 'city': 'Nainital'}).routeLine, 'Nainital');
      final r = TripSummaryRecord.fromJson({
        'tripId': 'a',
        'city': 'Haridwar',
        'legCities': ['Haridwar', 'Badrinath'],
      });
      expect(r.cities.length, 2);
      expect(r.routeLine, 'Haridwar → Badrinath');
    });
  });

  group('MC-D list fields', () {
    test('travel counters and leg states parse', () {
      final s = TripSummaryModel.fromJson({
        'id': 't1',
        'cityName': 'Haridwar',
        'legCount': 2,
        'legCities': ['Haridwar', 'Badrinath'],
        'travelSegments': 1,
        'travelSettled': 1,
        'legs': [
          {'index': 1, 'cityName': 'Haridwar', 'startDay': 1, 'endDay': 1, 'state': 'ready'},
          {'index': 2, 'cityName': 'Badrinath', 'startDay': 2, 'endDay': 4, 'state': 'confirming'},
        ],
      });
      expect(s.travelSegments, 1);
      expect(s.travelSettled, 1);
      expect(s.showsTravel, isTrue);
      expect(s.travelAllSettled, isTrue);
      expect(s.legs.length, 2);
      expect(s.legs[1].cityName, 'Badrinath');
      expect(s.legs[1].endDay, 4);
      expect(s.legs[1].state, 'confirming');
      expect(s.withMuted(DateTime(2030)).travelSegments, 1);
    });

    test('an older server defaults to no travel and no legs', () {
      final s = TripSummaryModel.fromJson({'id': 't1', 'cityName': 'Nainital'});
      expect(s.travelSegments, 0);
      expect(s.travelSettled, 0);
      expect(s.legs, isEmpty);
      expect(s.showsTravel, isFalse);
    });

    test('a one-leg trip never shows travel even with a stray count', () {
      final s = TripSummaryModel.fromJson({'id': 't1', 'cityName': 'Nainital', 'legCount': 1, 'travelSegments': 1});
      expect(s.showsTravel, isFalse);
    });

    test('settled above total is clamped for the chip', () {
      final s = TripSummaryModel.fromJson({
        'id': 't1',
        'cityName': 'A',
        'legCount': 2,
        'legCities': ['A', 'B'],
        'travelSegments': 1,
        'travelSettled': 3,
      });
      expect(s.travelSettledShown, 1);
    });
  });

  group('offline cache shape (MC-D)', () {
    Map<String, dynamic> raw() => {
          'id': 't1',
          'title': 'Haridwar, Badrinath, Auli trip',
          'cityKey': 1,
          'cityName': 'Haridwar',
          'dayCount': 4,
          'legCount': 3,
          'legCities': ['Haridwar', 'Badrinath', 'Auli'],
          'plan': {
            'version': 4,
            'cityKey': 1,
            'cityName': 'Haridwar',
            'legs': [
              {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
              {
                'index': 2,
                'cityKey': 2,
                'cityName': 'Badrinath',
                'latitude': 30.74,
                'longitude': 79.49,
                'arrival': {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 2, 'listedTotal': 14000},
              },
              {
                'index': 3,
                'cityKey': 3,
                'cityName': 'Auli',
                'latitude': 30.53,
                'longitude': 79.57,
                'arrival': {
                  'mode': 'own',
                  'fromName': 'Badrinath',
                  'how': 'bus',
                  'leavesAt': '06:00',
                  'ownPhone': '9876543210',
                },
              },
            ],
            'days': [
              {'day': 1, 'leg': 1},
              {'day': 2, 'leg': 2},
              {'day': 3, 'leg': 2},
              {'day': 4, 'leg': 3},
            ],
          },
          'journeys': [
            {
              'id': 'j2',
              'role': 'segment',
              'legIndex': 2,
              'travelDay': 2,
              'fromName': 'Haridwar',
              'toName': 'Badrinath',
              'date': '2030-11-02',
              'cars': 2,
              'legs': [
                {'legIndex': 1, 'fromName': 'Haridwar', 'toName': 'Rishikesh', 'driverName': 'Sunil Kumar', 'phone': '9800000001'},
                {'legIndex': 2, 'fromName': 'Rishikesh', 'toName': 'Badrinath', 'driverName': 'Mohan Bisht', 'phone': '9800000002'},
              ],
            },
          ],
        };

    void expectSame(TripModel t) {
      final a2 = t.plan.legAt(2)!.arrival!;
      expect(a2.isJourney, isTrue);
      expect(a2.journeyId, 'j2');
      expect(a2.cars, 2);
      final a3 = t.plan.legAt(3)!.arrival!;
      expect(a3.isOwn, isTrue);
      expect(a3.how, TripTravelHow.bus);
      expect(a3.leavesAt, '06:00');
      expect(a3.ownPhone, '9876543210');
      final j = t.journeyById('j2')!;
      expect(j.isSegment, isTrue);
      expect(j.legs.map((l) => l.phone), ['9800000001', '9800000002']);
      expect(t.legCities, ['Haridwar', 'Badrinath', 'Auli']);
    }

    test('the raw GET json the cache stores keeps arrivals and driver phones', () {
      final t = TripModel.fromJson(raw());
      expectSame(t);
      expectSame(TripModel.fromJson(t.raw!));
    });

    test('the savePlan shape (plan + journeys re-serialised) parses back the same', () {
      final t = TripModel.fromJson(raw());
      final cached = {
        ...t.raw!,
        'plan': t.plan.toJson(),
        'legCount': t.plan.legs.length,
        'legCities': t.plan.legs.map((l) => l.cityName).toList(),
        'journeys': t.journeys.map((j) => j.toJson()).toList(),
      };
      expectSame(TripModel.fromJson(cached));
    });
  });

  group('TripSummaryRecord legs (MC-D)', () {
    test('an older server has no legs and stays one-city', () {
      final r = TripSummaryRecord.fromJson({'tripId': 'a', 'city': 'Nainital'});
      expect(r.legs, isEmpty);
      expect(r.isMultiCity, isFalse);
      expect(r.hasTravelCars, isFalse);
    });

    test('legs, travel and cars parse with safe defaults', () {
      final r = TripSummaryRecord.fromJson({
        'tripId': 'a',
        'city': 'Haridwar',
        'legs': [
          {
            'index': 2,
            'cityName': 'Badrinath',
            'startDay': 2,
            'endDay': 4,
            'startDate': '2030-11-02',
            'endDate': '2030-11-04',
            'travel': {
              'mode': 'journey',
              'fromName': 'Haridwar',
              'toName': 'Badrinath',
              'day': 2,
              'date': '2030-11-02',
              'state': 'partlyBooked',
              'carCount': 2,
              'listedTotal': 14000,
              'cars': [
                {
                  'car': 2,
                  'driverName': 'Mohan Bisht',
                  'fromName': 'Rishikesh',
                  'toName': 'Badrinath',
                  'listedFare': 9800,
                  'displayStatus': 'asked',
                },
                {
                  'car': 1,
                  'driverName': 'Sunil Kumar',
                  'fromName': 'Haridwar',
                  'toName': 'Rishikesh',
                  'agreedFare': 4200,
                  'listedFare': 4000,
                  'displayStatus': 'confirmedByBoth',
                  'confirmedBy': 'both',
                  'pickupTime': '06:00',
                },
              ],
            },
          },
          {
            'index': 1,
            'cityName': 'Haridwar',
            'startDay': 1,
            'endDay': 1,
            'nights': [
              {'night': 1, 'listingName': 'Ganga View Inn'},
            ],
          },
        ],
      });
      expect(r.isMultiCity, isTrue);
      expect(r.legs.first.index, 1);
      expect(r.legs.first.travel, isNull);
      expect(r.legs.first.nights.single.listingName, 'Ganga View Inn');
      final t = r.legs[1].travel!;
      expect(t.isJourney, isTrue);
      expect(t.state, TripTravelState.partlyBooked);
      expect(t.cars.map((c) => c.car), [1, 2]);
      expect(t.places, ['Haridwar', 'Rishikesh', 'Badrinath']);
      expect(t.cars.first.isBooked, isTrue);
      expect(t.cars.first.fare, 4200);
      expect(t.cars.last.isBooked, isFalse);
      expect(t.cars.last.fare, 9800);
      expect(r.hasTravel, isTrue);
      expect(r.hasTravelCars, isTrue);
    });

    test('own travel has no cars', () {
      final t = TripSummaryTravel.fromJson({
        'mode': 'own',
        'fromName': 'Delhi',
        'toName': 'Haridwar',
        'state': 'own',
        'how': 'bus',
        'cars': [
          {'car': 1},
        ],
      });
      expect(t.isOwn, isTrue);
      expect(t.cars, isEmpty);
      expect(t.howLabel, 'Bus');
      expect(t.places, ['Delhi', 'Haridwar']);
    });
  });
}
