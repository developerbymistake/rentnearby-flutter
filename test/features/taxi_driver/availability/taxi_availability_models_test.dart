import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import 'taxi_avail_fixtures.dart';

void main() {
  tearDown(() => PlanGate.debugPlan = null);

  group('TaxiAvailability.fromJson', () {
    test('reads the contract body', () {
      final a = TaxiAvailability.fromJson(availJson());
      expect(a.today, DateTime(2026, 11, 26));
      expect(a.window.monthFrom, DateTime(2026, 11, 1));
      expect(a.window.monthTo, DateTime(2026, 11, 30));
      expect(a.window.locked, isTrue);
      expect(a.monthsAhead, 0);
      expect(a.switchOn, isTrue);
      expect(a.daysOff.keys, ['2026-11-27', '2026-11-30']);
      expect(a.daysOff['2026-11-27']?.reason, 'Family function in Almora');
      expect(a.daysOff['2026-11-30']?.reason, isNull);
      expect(a.bookedDays, {'2026-11-28'});
      expect(a.counts?.bookings, 3);
      expect(a.counts?.daysOff, 2);
      expect(a.counts?.month, DateTime(2026, 11));
      expect(a.isBooked(DateTime(2026, 11, 28)), isTrue);
      expect(a.hasOff(DateTime(2026, 11, 27)), isTrue);
    });

    test('drops bad and duplicate dates, keeps the first row, sorts by date', () {
      final a = TaxiAvailability.fromJson(availJson(daysOff: [
        dayRow('2026-11-30', 'b'),
        dayRow('2026-11-29', 'a'),
        dayRow('2026-11-29', 'second'),
        dayRow('2026-13-01'),
        dayRow('nope'),
        {'reason': 'no date'},
      ], booked: ['2026-11-28', 'bad', '2026-11-28']));
      expect(a.daysOff.keys, ['2026-11-29', '2026-11-30']);
      expect(a.daysOff['2026-11-29']?.reason, 'a');
      expect(a.bookedDays, {'2026-11-28'});
    });

    test('a reason longer than 200 code points is cut, empty becomes null', () {
      final long = 'अ' * 260;
      final a = TaxiAvailability.fromJson(availJson(daysOff: [dayRow('2026-11-27', long), dayRow('2026-11-29', '   ')]));
      expect(a.daysOff['2026-11-27']?.reason?.runes.length, 200);
      expect(a.daysOff['2026-11-29']?.reason, isNull);
    });

    test('missing window falls back to the plan: Free one month, locked', () {
      PlanGate.debugPlan = OwnerPlans.free;
      final j = availJson()..remove('window');
      final a = TaxiAvailability.fromJson(j);
      expect(a.window.monthFrom, DateTime(2026, 11, 1));
      expect(a.window.months(DateTime(2026, 11, 26)).length, 1);
      expect(a.window.locked, isTrue);
    });

    test('missing window on Plus allows six months ahead', () {
      PlanGate.debugPlan = OwnerPlans.plus;
      final a = TaxiAvailability.fromJson(availJson()..remove('window'));
      expect(a.window.months(DateTime(2026, 11, 26)).length, 7);
      expect(a.window.locked, isFalse);
    });

    test('every variant of the body parses without throwing', () {
      for (final v in jsonVariants(availJson())) {
        expect(() => TaxiAvailability.fromJson(v), returnsNormally);
      }
    });

    test('unknown fields are ignored', () {
      final a = TaxiAvailability.fromJson({...availJson(), 'extra': {'x': 1}});
      expect(a.daysOff.length, 2);
    });
  });

  group('TaxiReasonText', () {
    test('counts code points: 200 Hindi letters fit, surrogate pairs count once', () {
      expect(TaxiReasonText.length('अ' * 200), 200);
      expect(TaxiReasonText.length('😀' * 150), 150);
      expect(TaxiReasonText.cut('😀' * 210).runes.length, 200);
      expect(TaxiReasonText.clean('  hi  '), 'hi');
      expect(TaxiReasonText.clean(''), isNull);
      expect(TaxiReasonText.clean(null), isNull);
    });

    test('day off to json sends the date and the reason', () {
      expect(TaxiDayOff(date: DateTime(2026, 11, 27), reason: 'x').toJson(), {'date': '2026-11-27', 'reason': 'x'});
      expect(TaxiDayOff(date: DateTime(2026, 11, 30)).toJson(), {'date': '2026-11-30', 'reason': null});
    });
  });

  group('home feed counts', () {
    test('numbers.taxi.availability is read', () {
      final dto = OwnerHomeDto.fromJson({
        'numbers': {
          'taxi': {
            'newRequests': 1,
            'availability': {'month': '2026-11', 'bookings': 3, 'daysOff': 2},
          },
        },
      });
      expect(dto.availability?.month, DateTime(2026, 11));
      expect(dto.availability?.bookings, 3);
      expect(dto.availability?.daysOff, 2);
    });

    test('old JSON without the object parses to null', () {
      expect(OwnerHomeDto.fromJson({'numbers': {'taxi': {'newRequests': 1}}}).availability, isNull);
      expect(OwnerHomeDto.fromJson(const {}).availability, isNull);
      expect(OwnerHomeDto.fromJson({'numbers': {'taxi': {'availability': 'x'}}}).availability, isNull);
      final partial = OwnerHomeDto.fromJson({'numbers': {'taxi': {'availability': {'bookings': 'x'}}}}).availability;
      expect(partial?.bookings, isNull);
      expect(partial?.daysOff, isNull);
    });
  });
}
