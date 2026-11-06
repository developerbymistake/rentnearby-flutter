import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_stay_base.dart';
import 'package:bakhli/features/trip/utils/trip_wizard_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripStayChoice _stay(String id, double lat, double lng) => TripStayChoice(stayId: id, name: id, latitude: lat, longitude: lng);

const _spot = TripSpotRef(id: 'a', name: 'Naini Lake', latitude: 29.39, longitude: 79.45, category: 'lake', visitMinutes: 60);

TripPlan _nainital(List<TripStayChoice?> nights) => TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      centreLatitude: 29.3919,
      centreLongitude: 79.4542,
      days: [for (var i = 0; i < nights.length; i++) TripDay(day: i + 1, spots: const [_spot], stay: nights[i])],
    );

void main() {
  group('per-day planner points', () {
    test('a day runs from last night\'s stay to tonight\'s', () {
      final p = _nainital([_stay('lake', 29.39, 79.45), _stay('mall', 29.40, 79.46), null]);
      expect(TripStayBase.dayEnds(p, 1), (start: null, end: (lat: 29.39, lng: 79.45)));
      expect(TripStayBase.dayEnds(p, 2), (start: (lat: 29.39, lng: 79.45), end: (lat: 29.40, lng: 79.46)));
      expect(TripStayBase.dayEnds(p, 3), (start: (lat: 29.40, lng: 79.46), end: null));
    });

    test('one stay for every night keeps the leg base on both ends', () {
      final s = _stay('lake', 29.39, 79.45);
      final p = _nainital([s, s]);
      expect(TripStayBase.dayEnds(p, 1), (start: (lat: 29.39, lng: 79.45), end: (lat: 29.39, lng: 79.45)));
    });

    test('a skipped night or a stay far from the city gives no point', () {
      final p = _nainital([const TripStayChoice.skippedNight(), _stay('delhi', 28.61, 77.21), null]);
      expect(TripStayBase.dayEnds(p, 2), (start: null, end: null));
      expect(TripStayBase.dayBodyOf(p, 2), isEmpty);
    });

    test('the recalculate request carries each day\'s points', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final c = TripPlanController();
      final p = _nainital([_stay('lake', 29.39, 79.45), _stay('mall', 29.40, 79.46)]);
      final days = c.planBodyForTest(p, 1, 'recalculate')['days'] as List;
      expect((days[1] as Map)['startLatitude'], 29.39);
      expect((days[1] as Map)['endLongitude'], 79.46);
      expect((days[0] as Map).containsKey('startLatitude'), isFalse);
      final auto = c.planBodyForTest(p, 1, 'auto');
      expect(auto.containsKey('days'), isFalse);
    });
  });

  group('per-day taxi pickup', () {
    test('day d picks up at last night\'s stay of the same city', () {
      final p = _nainital([_stay('Deodar Homestay', 29.39, 79.45), null, null]);
      expect(TripWizardRules.pickupPlaceOf(p, 1), isNull);
      expect(TripWizardRules.pickupPlaceOf(p, 2), 'Deodar Homestay');
      expect(TripWizardRules.pickupPlaceOf(p, 3), isNull);
      final skipped = _nainital([const TripStayChoice.skippedNight(), null]);
      expect(TripWizardRules.pickupPlaceOf(skipped, 2), isNull);
    });
  });

  group('own travel on a journey step', () {
    test('how, name, phone and time round trip only while the step is own', () {
      const s = TripStep(
        status: TripStepStatus.own,
        how: TripTravelHow.bus,
        ownName: 'Volvo',
        ownPhone: '9876543210',
        leavesAt: '06:30',
        note: 'Seat 12',
      );
      final back = TripStep.fromJson(s.toJson());
      expect((back.how, back.ownName, back.ownPhone, back.leavesAt, back.note),
          (TripTravelHow.bus, 'Volvo', '9876543210', '06:30', 'Seat 12'));
      final moved = s.copyWith(status: TripStepStatus.chosen, journeyId: 'j1');
      expect((moved.how, moved.ownName, moved.ownPhone, moved.leavesAt), (null, null, null, null));
      expect(moved.toJson().containsKey('how'), isFalse);
    });

    test('the Day 1 start card says how the traveller arrives', () {
      final p = _nainital([null, null]);
      final i = TripWizardInput(
        plan: p,
        enquiries: const [],
        today: DateTime(2030),
        steps: const TripSteps(gettingThere: TripStep(status: TripStepStatus.own, how: TripTravelHow.train)),
      );
      expect(TripWizardRules.startOf(i, 1).line, TripWizardCopy.byHow('train'));
    });
  });
}
