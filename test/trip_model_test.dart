import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
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
}
