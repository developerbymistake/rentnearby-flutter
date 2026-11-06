import 'package:bakhli/features/taxi/ways/journey_plan_controller.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:flutter_test/flutter_test.dart';

WayDriver driver(String id, int fare, {int seats = 7, String? phone}) => WayDriver(
      taxiId: id,
      driverName: 'Driver $id',
      vehicleTypeName: 'Innova',
      seats: seats,
      fromName: 'A',
      toName: 'B',
      listedFare: fare,
      phone: phone,
    );

const a = WayPlace(key: 'a', name: 'Delhi', lat: 28.6, lng: 77.2);
const b = WayPlace(key: 'b', name: 'Haridwar', lat: 29.9, lng: 78.1);
const c = WayPlace(key: 'c', name: 'Badrinath', lat: 30.7, lng: 79.5);

WayPlan twoCars() => WayPlan(planKey: 'p1~a~b~c', cars: 2, total: 9000, legs: [
      WayLeg(legKey: 'l1~a~b', index: 1, from: a, to: b, listedFare: 4000, topDrivers: [driver('d1', 4000), driver('d2', 4500)]),
      WayLeg(legKey: 'l1~b~c', index: 2, from: b, to: c, listedFare: 5000, topDrivers: [driver('d3', 5000)]),
    ]);

JourneyOpenArgs args({WayPlan? plan, String? key, int people = 2, String? tripId, String? role, int? leg, String? fromStep}) {
  final p = plan ?? twoCars();
  return JourneyOpenArgs(
    plan: p,
    planKey: key ?? p.planKey,
    from: a,
    to: c,
    date: DateTime(2026, 11, 13),
    people: people,
    tripId: tripId,
    tripRole: role,
    tripLegIndex: leg,
    fromStep: fromStep,
  );
}

void main() {
  group('JourneyOpenArgs', () {
    test('valid args parse back from route arguments', () {
      final x = args();
      expect(JourneyOpenArgs.of(x), same(x));
      expect(JourneyOpenArgs.invalidReason(x), isNull);
    });

    test('a corrupt deep link is rejected with a named reason', () {
      expect(JourneyOpenArgs.of(null), isNull);
      expect(JourneyOpenArgs.invalidReason(null), 'no arguments');
      expect(JourneyOpenArgs.of({'planKey': 'p1', 'tag': 'ways-1'}), isNull);
      expect(JourneyOpenArgs.invalidReason({'planKey': 'p1'}), contains('not JourneyOpenArgs'));
      expect(JourneyOpenArgs.invalidReason(args(key: 'other')), contains('does not match'));
      expect(JourneyOpenArgs.invalidReason(args(key: '')), 'empty planKey');
      expect(JourneyOpenArgs.invalidReason(args(people: 0)), 'people 0');
    });

    test('feed recovery keeps from, to, date and people', () {
      final f = JourneyOpenArgs.feedOf(args());
      expect(f?.from.name, 'Delhi');
      expect(f?.to.name, 'Badrinath');
      expect(f?.date, DateTime(2026, 11, 13));
      expect(f?.people, 2);
      final m = JourneyOpenArgs.feedOf({
        'from': {'key': 'a', 'name': 'Delhi', 'lat': 28.6, 'lng': 77.2},
        'to': {'key': 'c', 'name': 'Badrinath', 'lat': 30.7, 'lng': 79.5},
        'date': '2026-11-13',
        'people': 3,
      });
      expect(m?.to.name, 'Badrinath');
      expect(m?.date, DateTime(2026, 11, 13));
      expect(m?.people, 3);
      expect(JourneyOpenArgs.feedOf({'planKey': 'p1'}), isNull);
      expect(JourneyOpenArgs.feedOf(null), isNull);
    });

    test('trip mode flags follow the role and the leg', () {
      expect(args().inTrip, isFalse);
      expect(args(tripId: 't1', role: 'gettingThere').forTrip, isTrue);
      expect(args(tripId: 't1', role: 'comingBack').forTrip, isTrue);
      expect(args(tripId: 't1', role: 'segment').forTrip, isFalse);
      expect(args(tripId: 't1', role: 'segment', leg: 2).forSegment, isTrue);
      expect(args(role: 'gettingThere').forTrip, isFalse);
    });

    test('withChosen keeps every other field', () {
      final x = args(tripId: 't1', role: 'comingBack', fromStep: 'comingBack');
      final y = x.withChosen({2: driver('d9', 6000)});
      expect(y.chosen[2]?.taxiId, 'd9');
      expect(y.fromStep, 'comingBack');
      expect(y.tripRole, 'comingBack');
      expect(y.planKey, x.planKey);
      expect(x.chosen, isEmpty);
    });
  });

  group('JourneyPlanController pure parts', () {
    test('filledChosen picks the first driver per leg and keeps a pick', () {
      final p = twoCars();
      final out = JourneyPlanController.filledChosen(p, {1: driver('d2', 4500)});
      expect(out[1]?.taxiId, 'd2');
      expect(out[2]?.taxiId, 'd3');
    });

    test('filledChosen swaps a pick for the same driver with contact details', () {
      final p = WayPlan(planKey: 'p', cars: 1, total: 4000, legs: [
        WayLeg(legKey: 'l', index: 1, from: a, to: b, listedFare: 4000, drivers: [driver('d1', 4000, phone: '9876543210')]),
      ]);
      final out = JourneyPlanController.filledChosen(p, {1: driver('d1', 4000)});
      expect(out[1]?.phone, '9876543210');
    });

    test('carsChip counts cars per leg for the group', () {
      final p = twoCars();
      final chosen = JourneyPlanController.filledChosen(p, const {});
      expect(JourneyPlanController.carsChip(p, chosen, 2), startsWith('2 cars'));
      expect(JourneyPlanController.carsChip(p, chosen, 9), startsWith('4 cars'));
    });
  });
}
