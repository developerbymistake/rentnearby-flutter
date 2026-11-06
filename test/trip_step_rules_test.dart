import 'package:bakhli/features/taxi/journeys/journey_models.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_step_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _delhi = TripStartFrom(name: 'Delhi', lat: 28.6139, lon: 77.2090);

TripJourney _journey({
  String id = 'j1',
  bool asked = false,
  double fromLat = 28.6139,
  double fromLng = 77.2090,
  double toLat = 29.3919,
  double toLng = 79.4542,
  DateTime? date,
}) =>
    TripJourney(
      id: id,
      fromName: 'Delhi',
      fromLat: fromLat,
      fromLng: fromLng,
      toName: 'Nainital',
      toLat: toLat,
      toLng: toLng,
      date: date ?? DateTime(2030, 11, 1),
      status: JourneyStatus.ready,
      legs: [
        TripJourneyLeg(legIndex: 1, fromName: 'Delhi', toName: 'Haridwar', lastEnquiryId: asked ? 'e1' : null),
        const TripJourneyLeg(legIndex: 2, fromName: 'Haridwar', toName: 'Nainital'),
      ],
    );

double _northOf(double lat, double metres) => lat + metres / 111195.0;

void main() {
  group('expected dates (night rule)', () {
    final settings = TripSettings(startDate: DateTime(2030, 11, 1));

    test('getting there defaults to the start date', () {
      expect(TripStepRules.expectedDate(TripStepRole.gettingThere, const TripStep(), settings, 2), DateTime(2030, 11, 1));
    });

    test('coming back defaults to check-out, the morning after the last day', () {
      expect(TripStepRules.expectedDate(TripStepRole.comingBack, const TripStep(), settings, 2), DateTime(2030, 11, 3));
    });

    test('a one-day trip comes back on day 2', () {
      expect(TripStepRules.expectedDate(TripStepRole.comingBack, const TripStep(), settings, 1), DateTime(2030, 11, 2));
    });

    test('a step date overrides the default', () {
      final step = TripStep(date: DateTime(2030, 10, 31));
      expect(TripStepRules.expectedDate(TripStepRole.gettingThere, step, settings, 2), DateTime(2030, 10, 31));
    });

    test('coming back on the last day evening when the traveller leaves then', () {
      const step = TripStep(leaveOn: TripLeaveOn.lastDayEvening);
      expect(TripStepRules.expectedDate(TripStepRole.comingBack, step, settings, 2), DateTime(2030, 11, 2));
      expect(TripStepRules.expectedDate(TripStepRole.comingBack, step, settings, 1), DateTime(2030, 11, 1));
    });

    test('a step date still wins over leave-on', () {
      final step = TripStep(date: DateTime(2030, 11, 5), leaveOn: TripLeaveOn.lastDayEvening);
      expect(TripStepRules.expectedDate(TripStepRole.comingBack, step, settings, 2), DateTime(2030, 11, 5));
    });

    test('leave-on never moves getting there', () {
      const step = TripStep(leaveOn: TripLeaveOn.lastDayEvening);
      expect(TripStepRules.expectedDate(TripStepRole.gettingThere, step, settings, 2), DateTime(2030, 11, 1));
    });

    test('no trip dates means no expected date', () {
      expect(TripStepRules.expectedDate(TripStepRole.comingBack, const TripStep(), const TripSettings(), 3), isNull);
    });

    test('date changed compares days only', () {
      expect(TripStepRules.dateChanged(DateTime(2030, 11, 1), DateTime(2030, 11, 1)), isFalse);
      expect(TripStepRules.dateChanged(DateTime(2030, 11, 1), DateTime(2030, 11, 2)), isTrue);
      expect(TripStepRules.dateChanged(null, DateTime(2030, 11, 2)), isFalse);
    });
  });

  group('5 km rules', () {
    test('inside city at 4.9 km, outside at 5.1 km', () {
      expect(TripStepRules.insideCity(_delhi, _northOf(_delhi.lat, 4900), _delhi.lon), isTrue);
      expect(TripStepRules.insideCity(_delhi, _northOf(_delhi.lat, 5100), _delhi.lon), isFalse);
      expect(TripStepRules.insideCity(null, _delhi.lat, _delhi.lon), isFalse);
    });

    test('start changed uses the journey from for getting there', () {
      final near = _journey(fromLat: _northOf(_delhi.lat, 4900));
      final far = _journey(fromLat: _northOf(_delhi.lat, 5100));
      expect(TripStepRules.startChanged(TripStepRole.gettingThere, _delhi, near), isFalse);
      expect(TripStepRules.startChanged(TripStepRole.gettingThere, _delhi, far), isTrue);
    });

    test('start changed uses the journey to for coming back', () {
      final back = _journey(toLat: _northOf(_delhi.lat, 4900), toLng: _delhi.lon, fromLat: 29.39, fromLng: 79.45);
      final wrong = _journey(toLat: _northOf(_delhi.lat, 5100), toLng: _delhi.lon, fromLat: 29.39, fromLng: 79.45);
      expect(TripStepRules.startChanged(TripStepRole.comingBack, _delhi, back), isFalse);
      expect(TripStepRules.startChanged(TripStepRole.comingBack, _delhi, wrong), isTrue);
      expect(TripStepRules.startChanged(TripStepRole.comingBack, null, wrong), isFalse);
    });

    test('city changed: getting there reads the journey to, coming back the journey from', () {
      const nainital = (lat: 29.3919, lon: 79.4542);
      final j = _journey();
      expect(TripStepRules.cityChanged(TripStepRole.gettingThere, j, nainital.lat, nainital.lon), isFalse);
      expect(TripStepRules.cityChanged(TripStepRole.gettingThere, j, 30.74, 79.49), isTrue);
      final back = _journey(fromLat: nainital.lat, fromLng: nainital.lon, toLat: _delhi.lat, toLng: _delhi.lon);
      expect(TripStepRules.cityChanged(TripStepRole.comingBack, back, _northOf(nainital.lat, 4900), nainital.lon), isFalse);
      expect(TripStepRules.cityChanged(TripStepRole.comingBack, back, _northOf(nainital.lat, 5100), nainital.lon), isTrue);
      expect(TripStepRules.cityChanged(TripStepRole.gettingThere, j, null, null), isFalse);
    });

    test('start changed also flags a journey to another trip city', () {
      final j = _journey();
      expect(TripStepRules.startChanged(TripStepRole.gettingThere, _delhi, j, cityLat: 29.3919, cityLon: 79.4542), isFalse);
      expect(TripStepRules.startChanged(TripStepRole.gettingThere, _delhi, j, cityLat: 30.74, cityLon: 79.49), isTrue);
      expect(TripStepRules.startChanged(TripStepRole.gettingThere, null, j, cityLat: 30.74, cityLon: 79.49), isTrue);
    });
  });

  group('nudge', () {
    final today = DateTime(2030, 11, 1);

    test('only not started, with a start city, within 7 days', () {
      expect(TripStepRules.needsNudge(const TripStep(), _delhi, DateTime(2030, 11, 8), today), isTrue);
      expect(TripStepRules.needsNudge(const TripStep(), _delhi, DateTime(2030, 11, 9), today), isFalse);
      expect(TripStepRules.needsNudge(const TripStep(), _delhi, DateTime(2030, 11, 1), today), isTrue);
      expect(TripStepRules.needsNudge(const TripStep(), _delhi, DateTime(2030, 10, 31), today), isFalse);
      expect(TripStepRules.needsNudge(const TripStep(), null, DateTime(2030, 11, 3), today), isFalse);
      expect(TripStepRules.needsNudge(const TripStep(), _delhi, null, today), isFalse);
    });

    test('own, skipped, not needed and chosen are silent', () {
      for (final s in [TripStepStatus.own, TripStepStatus.skipped, TripStepStatus.notNeeded, TripStepStatus.chosen]) {
        expect(TripStepRules.needsNudge(TripStep(status: s), _delhi, DateTime(2030, 11, 3), today), isFalse);
      }
    });
  });
}
