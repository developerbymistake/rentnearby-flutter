import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/taxi/requests/utils/taxi_countdown.dart';

void main() {
  final expiresAt = DateTime.utc(2026, 12, 10, 9, 46, 7);

  test('countdown_uses_the_server_clock', () {
    final deviceNow = DateTime.utc(2026, 12, 10, 9, 40);
    const offset = Duration(minutes: 3);
    expect(TaxiCountdown.remaining(expiresAt, offset: offset, now: deviceNow), const Duration(minutes: 3, seconds: 7));
    expect(TaxiCountdown.label(expiresAt, offset: offset, now: deviceNow), '3:07');
    expect(TaxiCountdown.label(expiresAt, offset: Duration.zero, now: deviceNow), '6:07');
    expect(TaxiCountdown.label(expiresAt, offset: const Duration(minutes: -2), now: deviceNow.toLocal()), '8:07');
    expect(
      TaxiCountdown.label(expiresAt, offset: Duration.zero, now: DateTime.utc(2026, 12, 10, 9, 41, 22, 500)),
      '4:45',
    );
    expect(TaxiCountdown.label(DateTime.utc(2026, 12, 10, 10, 1), offset: offset, now: DateTime.utc(2026, 12, 10, 9, 43)),
        '15:00');
  });

  test('countdown_stops_at_zero', () {
    final after = DateTime.utc(2026, 12, 10, 9, 50);
    expect(TaxiCountdown.remaining(expiresAt, offset: Duration.zero, now: after), Duration.zero);
    expect(TaxiCountdown.label(expiresAt, offset: Duration.zero, now: after), '0:00');
    expect(TaxiCountdown.isOver(expiresAt, offset: Duration.zero, now: after), isTrue);
    expect(TaxiCountdown.isOver(expiresAt, offset: const Duration(minutes: -10), now: after), isFalse);
    expect(TaxiCountdown.remaining(null, offset: Duration.zero, now: after), Duration.zero);
    expect(TaxiCountdown.text(const Duration(seconds: -5)), '0:00');
  });
}
