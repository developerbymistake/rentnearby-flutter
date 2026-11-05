import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_enquiry_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 1);

  void expectInstant(DateTime actual, DateTime expectedUtc) {
    expect(actual.toUtc().isAtSameMomentAs(expectedUtc), isTrue, reason: 'got ${actual.toUtc()} want $expectedUtc');
  }

  group('enquiryExpiry', () {
    test('well before the trip: 48 h', () {
      final r = TripEnquiryRules.enquiryExpiry(start, start, DateTime.utc(2026, 10, 20, 6, 30));
      expectInstant(r.expiresAt, DateTime.utc(2026, 10, 22, 6, 30));
      expect(r.veryShortNotice, isFalse);
    });

    test('close to the trip: 12 h before start midnight IST', () {
      final r = TripEnquiryRules.enquiryExpiry(start, start, DateTime.utc(2026, 10, 31));
      expectInstant(r.expiresAt, DateTime.utc(2026, 10, 31, 6, 30));
      expect(r.veryShortNotice, isFalse);
    });

    test('floor of 2 h applies when the limit is already past', () {
      final r = TripEnquiryRules.enquiryExpiry(start, start, DateTime.utc(2026, 10, 31, 12));
      expectInstant(r.expiresAt, DateTime.utc(2026, 10, 31, 14));
      expect(r.veryShortNotice, isTrue);
    });

    test('on the first IST day the check-in is the reference', () {
      final r = TripEnquiryRules.enquiryExpiry(start, start, DateTime.utc(2026, 10, 31, 19));
      expectInstant(r.expiresAt, DateTime.utc(2026, 10, 31, 21));
      expect(r.veryShortNotice, isTrue);
    });

    test('during the trip the check-in night is the reference', () {
      final r = TripEnquiryRules.enquiryExpiry(start, DateTime.utc(2026, 11, 3), DateTime.utc(2026, 11, 2));
      expectInstant(r.expiresAt, DateTime.utc(2026, 11, 2, 6, 30));
      expect(r.veryShortNotice, isFalse);
    });
  });

  group('isUrgent', () {
    test('exactly 72 h before start midnight IST is not urgent', () {
      expect(TripEnquiryRules.isUrgent(start, DateTime.utc(2026, 10, 28, 18, 30)), isFalse);
    });

    test('one minute later is urgent', () {
      expect(TripEnquiryRules.isUrgent(start, DateTime.utc(2026, 10, 28, 18, 31)), isTrue);
    });

    test('far away is not urgent', () {
      expect(TripEnquiryRules.isUrgent(start, DateTime.utc(2026, 10, 1)), isFalse);
    });
  });

  group('nights', () {
    test('nightDate is start plus day minus one', () {
      expect(TripEnquiryRules.nightDate(start, 1), DateTime(2026, 11, 1));
      expect(TripEnquiryRules.nightDate(start, 3), DateTime(2026, 11, 3));
    });

    test('overlap is half open', () {
      final d = (int n) => DateTime.utc(2026, 11, n);
      expect(TripEnquiryRules.nightsOverlap(d(1), d(3), d(2), d(4)), isTrue);
      expect(TripEnquiryRules.nightsOverlap(d(1), d(2), d(2), d(3)), isFalse);
      expect(TripEnquiryRules.nightsOverlap(d(1), d(5), d(2), d(3)), isTrue);
      expect(TripEnquiryRules.nightsOverlap(d(3), d(4), d(1), d(2)), isFalse);
    });

    test('nightsFor: one night, or every remaining night', () {
      expect(TripEnquiryRules.nightsFor(4, 1, false), 1);
      expect(TripEnquiryRules.nightsFor(4, 1, true), 4);
      expect(TripEnquiryRules.nightsFor(4, 2, true), 3);
      expect(TripEnquiryRules.nightsFor(4, 3, true), 2);
      expect(TripEnquiryRules.nightsFor(4, 4, true), 1);
      expect(TripEnquiryRules.nightsFor(1, 1, true), 1);
    });
  });

  group('wrong city and outside trip (MC-C)', () {
    TripPlan legs({bool started = true}) => TripPlan.fromJson({
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
            {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49},
          ],
          'settings': {'startDate': ?(started ? '2030-11-01' : null)},
          'days': [
            {'day': 1, 'leg': 1},
            {'day': 2, 'leg': 2},
            {'day': 3, 'leg': 2},
          ],
        });

    TripEnquiryModel stay(int from, int nights, {String city = 'Haridwar', double? lat, double? lon}) => TripEnquiryModel(
          id: 's$from',
          status: TripEnquiryStatuses.confirmedByBoth,
          checkIn: DateTime(2030, 11, from),
          checkOut: DateTime(2030, 11, from + nights),
          listingLatitude: lat,
          listingLongitude: lon,
          context: TripEnquiryContext(city: city),
        );

    TripEnquiryModel range(DateTime a, DateTime b, String city) => TripEnquiryModel(
          id: 'r',
          status: TripEnquiryStatuses.confirmedByBoth,
          checkIn: a,
          checkOut: b,
          context: TripEnquiryContext(city: city),
        );

    test('a Haridwar room on a Badrinath night is wrong, by context city fold', () {
      final p = legs();
      final w = TripEnquiryRules.wrongCity(stay(2, 1, city: 'haridwar'), p, p.settings)!;
      expect(w.wrong, 1);
      expect(w.total, 1);
      expect(w.firstWrongDay, 2);
      expect(w.dayCity, 'Badrinath');
      expect(w.homeLegIndex, 1);
      expect(w.dayLegIndex, 2);
      expect(w.partial, isFalse);
    });

    test('nearest leg by coordinates when the city is unknown', () {
      final p = legs();
      final e = stay(2, 1, city: '', lat: 29.94, lon: 78.15);
      expect(TripEnquiryRules.homeLegIndex(e, p), 1);
      expect(TripEnquiryRules.wrongCity(e, p, p.settings)?.wrong, 1);
      expect(TripEnquiryRules.homeLegIndex(stay(2, 1, city: ''), p), isNull);
      expect(TripEnquiryRules.wrongCity(stay(2, 1, city: ''), p, p.settings), isNull);
    });

    test('partial: 1 of 3 nights in the other city', () {
      final p = legs();
      final w = TripEnquiryRules.wrongCity(range(DateTime(2030, 11, 1), DateTime(2030, 11, 4), 'Badrinath'), p, p.settings)!;
      expect(w.wrong, 1);
      expect(w.total, 3);
      expect(w.firstWrongDay, 1);
      expect(w.dayCity, 'Haridwar');
      expect(w.partial, isTrue);
    });

    test('same city, one leg, segment rows and no dates are never wrong', () {
      final p = legs();
      expect(TripEnquiryRules.wrongCity(stay(2, 2, city: 'Badrinath'), p, p.settings), isNull);
      final one = TripPlan.singleCity(
        cityKey: 1,
        cityName: 'Haridwar',
        settings: TripSettings(startDate: DateTime(2030, 11, 1)),
        days: const [TripDay(day: 1), TripDay(day: 2)],
      );
      expect(TripEnquiryRules.wrongCity(stay(2, 1, city: 'Badrinath'), one, one.settings), isNull);
      final seg = TripEnquiryModel(
        id: 'c1',
        tripId: 't1',
        kind: TripEnquiryKinds.taxi,
        day: 2,
        checkIn: DateTime(2030, 11, 2),
        days: const [2],
        status: TripEnquiryStatuses.bookedByTraveller,
        context: const TripEnquiryContext(city: 'Haridwar', journeyId: 'j1', journeyLegIndex: 1),
      );
      expect(TripEnquiryRules.wrongCity(seg, p, p.settings), isNull);
      expect(TripEnquiryRules.isOutsideTrip(seg, p.settings, 3), isFalse);
      final noDates = legs(started: false);
      expect(TripEnquiryRules.wrongCity(stay(2, 1), noDates, noDates.settings), isNull);
      expect(TripEnquiryRules.isOutsideTrip(stay(9, 1), noDates.settings, 3), isFalse);
    });

    test('taxi dates follow the day gaps', () {
      final p = legs();
      final taxi = TripEnquiryModel(
        id: 't1',
        kind: TripEnquiryKinds.taxi,
        checkIn: DateTime(2030, 11, 1),
        days: const [1, 3],
        status: TripEnquiryStatuses.bookedByTraveller,
        context: const TripEnquiryContext(city: 'Haridwar'),
      );
      expect(TripEnquiryRules.datesOf(taxi), [DateTime(2030, 11, 1), DateTime(2030, 11, 3)]);
      final w = TripEnquiryRules.wrongCity(taxi, p, p.settings)!;
      expect(w.wrong, 1);
      expect(w.total, 2);
      expect(w.firstWrongDay, 3);
    });

    test('outside trip: the last night is inside, the night after is outside', () {
      final p = legs();
      expect(TripEnquiryRules.isOutsideTrip(stay(3, 1), p.settings, 3), isFalse);
      expect(TripEnquiryRules.isOutsideTrip(stay(3, 2), p.settings, 3), isTrue);
      expect(TripEnquiryRules.isOutsideTrip(range(DateTime(2030, 10, 31), DateTime(2030, 11, 1), 'Haridwar'), p.settings, 3), isTrue);
    });
  });
}
