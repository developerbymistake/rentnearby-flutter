import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_days_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'lake', visitMinutes: 60);

TripDay _day(int day, int spots, {int leg = 1}) =>
    TripDay(day: day, leg: leg, spots: [for (var i = 0; i < spots; i++) _spot('d$day-$i')]);

TripPlan _plan(List<TripDay> days, {int legs = 1}) => TripPlan(
      legs: [
        for (var k = 1; k <= legs; k++)
          TripCityLeg(index: k, cityKey: k, cityName: 'City $k', latitude: 29, longitude: 79),
      ],
      days: days,
    );

void main() {
  group('minDays', () {
    test('never below the city count or one day', () {
      expect(TripDaysRules.minDays(1, const []), 1);
      expect(TripDaysRules.minDays(2, const [0, 0]), 2);
      expect(TripDaysRules.minDays(3, const []), 3);
    });

    test('adds a day for every started six places', () {
      expect(TripDaysRules.minDays(1, const [6]), 1);
      expect(TripDaysRules.minDays(1, const [7]), 2);
      expect(TripDaysRules.minDays(2, const [7, 0]), 3);
      expect(TripDaysRules.minDays(3, const [6, 6, 6]), 3);
      expect(TripDaysRules.minDays(2, const [13, 6]), 4);
    });
  });

  group('limitFor', () {
    test('is six a day minus the days the other cities need', () {
      expect(TripDaysRules.limitFor(3, const [5, 5], 0), 12);
      expect(TripDaysRules.limitFor(2, const [5, 5], 0), 6);
      expect(TripDaysRules.limitFor(3, const [5, 5], 1), 12);
      expect(TripDaysRules.limitFor(4, const [7, 3], 1), 12);
      expect(TripDaysRules.limitFor(3, const [7, 3], 0), 12);
    });

    test('a city with no places still keeps one day for the others', () {
      expect(TripDaysRules.limitFor(2, const [0, 0], 0), 6);
      expect(TripDaysRules.limitFor(1, const [0], 0), 6);
    });

    test('never negative', () {
      expect(TripDaysRules.limitFor(1, const [0, 0], 0), 0);
      expect(TripDaysRules.limitFor(3, const [13, 5], 1), 0);
    });

    test('total is days times six', () {
      expect(TripDaysRules.total(3), 18);
      expect(TripDaysRules.perDay, 6);
    });

    test('total and limit never pass the trip cap', () {
      expect(TripDaysRules.total(10), 60);
      expect(TripDaysRules.total(14), 60);
      expect(TripDaysRules.limitFor(14, const [0], 0), 60);
      expect(TripDaysRules.limitFor(14, const [20, 0], 1), 40);
    });
  });

  group('allocate', () {
    int sum(List<int> l) => l.fold(0, (a, b) => a + b);

    test('every city keeps what it needs, the rest goes by share, ties to the earlier city', () {
      expect(TripDaysRules.allocate(3, const [5, 5]), [2, 1]);
      expect(TripDaysRules.allocate(4, const [10, 2]), [3, 1]);
      expect(TripDaysRules.allocate(2, const [0, 0]), [1, 1]);
      expect(TripDaysRules.allocate(5, const [0, 0]), [3, 2]);
      expect(TripDaysRules.allocate(2, const [6]), [2]);
    });

    test('no cities gives no days', () {
      expect(TripDaysRules.allocate(2, const []), isEmpty);
    });

    test('too many places shrinks the biggest city first and keeps one day each', () {
      expect(TripDaysRules.allocate(3, const [12, 6, 6]), [1, 1, 1]);
      expect(TripDaysRules.allocate(2, const [13, 13]), [1, 1]);
    });

    test('the allocation always sums to the days and gives each city a day', () {
      for (var days = 3; days <= 8; days++) {
        for (final places in [
          [0, 0, 0],
          [4, 9, 2],
          [18, 1, 1],
          [6, 6, 6],
          [3, 0, 12],
        ]) {
          final a = TripDaysRules.allocate(days, places);
          expect(a.length, 3);
          expect(sum(a), days, reason: '$days $places $a');
          expect(a.every((d) => d >= 1), isTrue, reason: '$days $places $a');
        }
      }
    });

    test('a city never gets fewer days than its places need when the days allow', () {
      final a = TripDaysRules.allocate(6, const [13, 5, 6]);
      expect(a[0], greaterThanOrEqualTo(3));
      expect(a[1], greaterThanOrEqualTo(1));
      expect(a[2], greaterThanOrEqualTo(1));
      expect(sum(a), 6);
    });
  });

  group('suggestedDays', () {
    test('one day per six places, between one and three', () {
      expect(TripDaysRules.suggestedDays(0), 1);
      expect(TripDaysRules.suggestedDays(1), 1);
      expect(TripDaysRules.suggestedDays(6), 1);
      expect(TripDaysRules.suggestedDays(7), 2);
      expect(TripDaysRules.suggestedDays(13), 3);
      expect(TripDaysRules.suggestedDays(60), 3);
    });
  });

  group('canAddOnDay', () {
    test('open below six places, closed at six and for a missing day', () {
      final p = _plan([_day(1, 5), _day(2, 6), _day(3, 0)]);
      expect(TripDaysRules.canAddOnDay(p, 1), isTrue);
      expect(TripDaysRules.canAddOnDay(p, 2), isFalse);
      expect(TripDaysRules.canAddOnDay(p, 3), isTrue);
      expect(TripDaysRules.canAddOnDay(p, 9), isFalse);
    });
  });

  group('canRemoveDay', () {
    test('the only day of a city can never go', () {
      final p = _plan([_day(1, 2)]);
      expect(TripDaysRules.canRemoveDay(p, 1), isFalse);
      expect(TripDaysRules.canRemoveDay(p, 7), isFalse);
    });

    test('allowed when the remaining places still fit', () {
      final p = _plan([_day(1, 4), _day(2, 2)]);
      expect(TripDaysRules.canRemoveDay(p, 1), isTrue);
      expect(TripDaysRules.canRemoveDay(p, 2), isTrue);
    });

    test('blocked when the places would not fit in fewer days', () {
      final p = _plan([_day(1, 6), _day(2, 1)]);
      expect(TripDaysRules.canRemoveDay(p, 2), isFalse);
      final q = _plan([_day(1, 6), _day(2, 6), _day(3, 0)]);
      expect(TripDaysRules.canRemoveDay(q, 3), isTrue);
    });

    test('counts only the places of that city', () {
      final p = _plan([_day(1, 6, leg: 1), _day(2, 1, leg: 1), _day(3, 3, leg: 2), _day(4, 0, leg: 2)], legs: 2);
      expect(TripDaysRules.canRemoveDay(p, 4), isTrue);
      expect(TripDaysRules.canRemoveDay(p, 2), isFalse);
    });
  });
}
