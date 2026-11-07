import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_days_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripSpotRef _spot(String id) => TripSpotRef(id: id, name: id, latitude: 29, longitude: 79, category: 'lake', visitMinutes: 60);

TripPlan _plan(List<int> perDay) {
  final city = TripCityModel(cityKey: 1, name: 'A', latitude: 29, longitude: 79);
  return TripPlan(
    legs: [TripCityLeg.fromCity(1, city)],
    days: [
      for (var i = 0; i < perDay.length; i++)
        TripDay(day: i + 1, leg: 1, spots: [for (var j = 0; j < perDay[i]; j++) _spot('d${i}s$j')]),
    ],
  );
}

void main() {
  group('minDays', () {
    test('never below the city count', () {
      expect(TripDaysRules.minDays(2, const [0, 0]), 2);
      expect(TripDaysRules.minDays(3, const []), 3);
    });

    test('places raise the minimum', () {
      expect(TripDaysRules.minDays(1, const [7]), 2);
      expect(TripDaysRules.minDays(2, const [7, 0]), 3);
      expect(TripDaysRules.minDays(2, const [6, 13]), 4);
    });
  });

  group('limitFor', () {
    test('single city gets days times six', () {
      expect(TripDaysRules.limitFor(3, const [0], 0), 18);
    });

    test('other cities keep at least one day each', () {
      expect(TripDaysRules.limitFor(3, const [0, 0], 0), 12);
      expect(TripDaysRules.limitFor(3, const [0, 7], 0), 6);
      expect(TripDaysRules.limitFor(3, const [4, 0], 1), 12);
    });

    test('never negative', () {
      expect(TripDaysRules.limitFor(1, const [0, 0, 0], 0), 0);
    });
  });

  group('allocate', () {
    test('sums to the days and respects need', () {
      for (final days in [2, 3, 5, 8, 14]) {
        for (final places in [
          [3, 3],
          [7, 1],
          [13, 2],
          [0, 0],
          [6, 6, 6],
        ]) {
          if (days < TripDaysRules.minDays(places.length, places)) continue;
          final a = TripDaysRules.allocate(days, places);
          expect(a.fold<int>(0, (x, y) => x + y), days, reason: '$days $places');
          for (var i = 0; i < places.length; i++) {
            expect(a[i] * 6 >= places[i], isTrue, reason: '$days $places $a');
            expect(a[i] >= 1, isTrue);
          }
        }
      }
    });

    test('extra days follow the larger city', () {
      expect(TripDaysRules.allocate(5, const [12, 3]), [4, 1]);
    });

    test('ties go to the earlier city', () {
      expect(TripDaysRules.allocate(3, const [2, 2]), [2, 1]);
    });

    test('empty list stays empty', () {
      expect(TripDaysRules.allocate(3, const []), isEmpty);
    });
  });

  test('suggestedDays is clamped to 1..3', () {
    expect(TripDaysRules.suggestedDays(0), 1);
    expect(TripDaysRules.suggestedDays(7), 2);
    expect(TripDaysRules.suggestedDays(60), 3);
  });

  test('canAddOnDay stops at six places', () {
    final p = _plan([5, 6]);
    expect(TripDaysRules.canAddOnDay(p, 1), isTrue);
    expect(TripDaysRules.canAddOnDay(p, 2), isFalse);
  });

  test('canRemoveDay needs the remaining places to fit', () {
    expect(TripDaysRules.canRemoveDay(_plan([6, 6]), 2), isFalse);
    expect(TripDaysRules.canRemoveDay(_plan([3, 3]), 2), isTrue);
    expect(TripDaysRules.canRemoveDay(_plan([2]), 1), isFalse);
  });
}
