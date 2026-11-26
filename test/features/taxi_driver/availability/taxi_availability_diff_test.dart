import 'package:bakhli/features/taxi_driver/availability/taxi_availability_controller.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxi_avail_fixtures.dart';

void main() {
  final base = TaxiAvailability.fromJson(availJson());
  final today = DateTime(2026, 11, 26);

  group('TaxiAvailabilityDiff', () {
    test('mark a free day = one set entry', () {
      final d = TaxiAvailabilityDiff.of(base.daysOff, {'2026-11-29': (off: true, reason: 'Wedding')});
      expect(d.set.map((e) => e.toJson()), [
        {'date': '2026-11-29', 'reason': 'Wedding'},
      ]);
      expect(d.clear, isEmpty);
    });

    test('unmark a saved day = one clear entry', () {
      final d = TaxiAvailabilityDiff.of(base.daysOff, {'2026-11-30': (off: false, reason: null)});
      expect(d.set, isEmpty);
      expect(d.clear, ['2026-11-30']);
    });

    test('mark then unmark a free day = clean', () {
      final n = TaxiAvailabilityDiff.normalise(base.daysOff, {'2026-11-29': (off: false, reason: null)});
      expect(n, isEmpty);
    });

    test('reason only change = set with the new reason', () {
      final d = TaxiAvailabilityDiff.of(base.daysOff, {'2026-11-30': (off: true, reason: 'Car service')});
      expect(d.set.single.reason, 'Car service');
      expect(d.set.single.key, '2026-11-30');
    });

    test('same reason as saved = clean', () {
      final n = TaxiAvailabilityDiff.normalise(base.daysOff, {'2026-11-27': (off: true, reason: 'Family function in Almora')});
      expect(n, isEmpty);
    });

    test('output is sorted by date', () {
      final d = TaxiAvailabilityDiff.of(base.daysOff, {
        '2026-11-29': (off: true, reason: null),
        '2026-11-26': (off: true, reason: null),
        '2026-11-30': (off: false, reason: null),
        '2026-11-27': (off: false, reason: null),
      });
      expect(d.set.map((e) => e.key), ['2026-11-26', '2026-11-29']);
      expect(d.clear, ['2026-11-27', '2026-11-30']);
    });

    test('rebase drops days that became booked or past, keeps the rest', () {
      final fresh = TaxiAvailability.fromJson(availJson(booked: ['2026-11-28', '2026-11-29'], today: '2026-11-27'));
      final kept = TaxiAvailabilityDiff.rebase(
        fresh,
        {
          '2026-11-26': (off: true, reason: null),
          '2026-11-29': (off: true, reason: 'x'),
          '2026-11-30': (off: true, reason: 'new reason'),
        },
        today: DateTime(2026, 11, 27),
      );
      expect(kept.keys, ['2026-11-30']);
    });

    test('rebase drops new days beyond the plan window but keeps a reason edit of a saved day there', () {
      final fresh = TaxiAvailability.fromJson(availJson(daysOff: [dayRow('2026-12-05', 'old')]));
      final kept = TaxiAvailabilityDiff.rebase(
        fresh,
        {
          '2026-12-04': (off: true, reason: null),
          '2026-12-05': (off: true, reason: 'new'),
        },
        today: today,
      );
      expect(kept.keys, ['2026-12-05']);
    });
  });
}
