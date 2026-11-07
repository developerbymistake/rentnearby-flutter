import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/trip/utils/trip_day_timeline.dart';

void main() {
  group('TripDayTimeline', () {
    test('starts add visit and road minutes from 9:00', () {
      final s = TripDayTimeline.starts(visits: [60, 90, 30], roads: [20, 15, null]);
      expect(s, [540, 620, 725]);
    });

    test('reserved travel time pushes the first place', () {
      final s = TripDayTimeline.starts(visits: [60], roads: [null], reserved: 120);
      expect(s, [660]);
    });

    test('missing road minutes count as zero', () {
      final s = TripDayTimeline.starts(visits: [30, 30], roads: [null, null]);
      expect(s, [540, 570]);
    });

    test('clock formats am and pm', () {
      expect(TripDayTimeline.clock(540), '9:00 am');
      expect(TripDayTimeline.clock(12 * 60), '12:00 pm');
      expect(TripDayTimeline.clock(0), '12:00 am');
      expect(TripDayTimeline.clock(13 * 60 + 5), '1:05 pm');
    });
  });
}
