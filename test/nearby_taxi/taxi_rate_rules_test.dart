import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_rate_strings.dart';
import 'package:bakhli/features/taxi/setup/taxi_rate_rules.dart';

void main() {
  test('rate is required and in range', () {
    expect(TaxiRateRules.rateError(''), TaxiRateStrings.addDayRate);
    expect(TaxiRateRules.rateError(null), TaxiRateStrings.addDayRate);
    expect(TaxiRateRules.rateError('99'), TaxiRateStrings.rateRange);
    expect(TaxiRateRules.rateError('9900001'), TaxiRateStrings.rateRange);
    expect(TaxiRateRules.rateError('100'), isNull);
    expect(TaxiRateRules.rateError('9900000'), isNull);
  });

  test('km is required and 1 to 1000', () {
    expect(TaxiRateRules.kmError(''), TaxiRateStrings.addKm);
    expect(TaxiRateRules.kmError('0'), TaxiRateStrings.kmRange);
    expect(TaxiRateRules.kmError('1001'), TaxiRateStrings.kmRange);
    expect(TaxiRateRules.kmError('1'), isNull);
    expect(TaxiRateRules.kmError('1000'), isNull);
  });

  test('validate reports the rate first, then the km', () {
    expect(TaxiRateRules.validate('', ''), TaxiRateStrings.addDayRate);
    expect(TaxiRateRules.validate('2500', ''), TaxiRateStrings.addKm);
    expect(TaxiRateRules.validate('2500', '120'), isNull);
  });

  test('done needs both values in range', () {
    expect(TaxiRateRules.done(rate: 2500, km: 120), isTrue);
    expect(TaxiRateRules.done(rate: 2500), isFalse);
    expect(TaxiRateRules.done(km: 120), isFalse);
    expect(TaxiRateRules.done(rate: 50, km: 120), isFalse);
    expect(TaxiRateRules.done(rate: 2500, km: 0), isFalse);
  });

  test('driver form uses the rules and has no optional or clear path', () {
    final src = File('lib/features/taxi/setup/taxi_routes_screen.dart').readAsStringSync();
    expect(src.contains('TaxiRateRules.validate'), isTrue);
    expect(src.contains('(optional)'), isFalse);
    expect(src.contains('Clear your day rate'), isFalse);
    expect(src.contains('TaxiRateStrings.kmLabel'), isTrue);
    final hub = File('lib/features/taxi/setup/taxi_setup_hub_screen.dart').readAsStringSync();
    expect(hub.contains('hasLocalRate'), isTrue);
  });

  test('new taxi v2 files carry no banned text or hardcoded colours', () {
    final files = Directory('lib/features/taxi/guest/v2').listSync().whereType<File>();
    for (final f in files) {
      final s = f.readAsStringSync();
      expect(s.contains('Ask for a price'), isFalse, reason: f.path);
      expect(s.contains('Color(0x'), isFalse, reason: f.path);
    }
  });
}
