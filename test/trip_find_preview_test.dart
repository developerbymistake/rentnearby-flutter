import 'package:bakhli/features/trip/utils/trip_enquiry_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stay ask preview text', () {
    test('names city, dates and people, nothing about rooms or needs', () {
      final text = TripEnquiryRules.previewText(
        city: 'Nainital',
        checkIn: DateTime(2030, 11, 20),
        checkOut: DateTime(2030, 11, 22),
        allNights: true,
        adults: 2,
        kids: 1,
        days: const [TripPreviewDay(day: 1, spots: ['Naini Lake', 'Mall Road'])],
      );
      expect(text, contains('Nainital'));
      expect(text, contains('20 Nov to 22 Nov (2 nights)'));
      expect(text, contains('2 adults, 1 kid'));
      expect(text, contains('Day 1 spots: Naini Lake, Mall Road.'));
      expect(text, isNot(contains('rooms')));
      expect(text, isNot(contains('We need')));
    });

    test('one night has no night count and defaults to two people', () {
      final text = TripEnquiryRules.previewText(
        city: 'Almora',
        checkIn: DateTime(2030, 11, 22),
        checkOut: DateTime(2030, 11, 23),
        allNights: false,
      );
      expect(text, contains('22 Nov to 23 Nov, 2 people'));
      expect(text, isNot(contains('nights')));
    });
  });
}
