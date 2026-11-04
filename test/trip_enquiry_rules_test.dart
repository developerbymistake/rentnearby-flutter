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
      expect(TripEnquiryRules.nightDate(start, 1), DateTime.utc(2026, 11, 1));
      expect(TripEnquiryRules.nightDate(start, 3), DateTime.utc(2026, 11, 3));
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
      expect(TripEnquiryRules.nightsFor(4, 1, true), 3);
      expect(TripEnquiryRules.nightsFor(4, 2, true), 2);
      expect(TripEnquiryRules.nightsFor(4, 3, true), 1);
    });
  });
}
