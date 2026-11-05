import 'package:bakhli/features/taxi/leads/trip_lead_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('segment lead with several cars reads car i of n', () {
    expect(
      TripLeadFormat.journeyLineOfText(
          'Car 1 of 2: Haridwar to Badrinath, 02 Nov, 4 people. Part of a 4-day trip, 2 of 2 cities.',
          segment: true),
      'Journey car 1 of 2 · Haridwar → Badrinath · 02 Nov',
    );
  });

  test('segment lead with one car has no count', () {
    expect(
      TripLeadFormat.journeyLineOfText('Haridwar to Badrinath, 02 Nov, 4 people.', segment: true, car: 1),
      'Journey car · Haridwar → Badrinath · 02 Nov',
    );
  });

  test('trip-less journey lead keeps the car prefix rule', () {
    expect(
      TripLeadFormat.journeyLineOfText('Car 2 of 2: Delhi to Haridwar, 01 Nov, 4 people.', segment: false),
      'Journey car 2 of 2 · Delhi → Haridwar · 01 Nov',
    );
  });

  test('local lead and empty text give null', () {
    expect(TripLeadFormat.journeyLineOfText('Delhi to Badrinath, 01 Nov, 2 people.', segment: false), isNull);
    expect(TripLeadFormat.journeyLineOfText('', segment: true), isNull);
    expect(TripLeadFormat.journeyLineOfText('Need a taxi for day 2', segment: true), isNull);
  });
}
