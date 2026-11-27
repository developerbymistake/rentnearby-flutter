import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/widgets/ring/ring_countdown.dart';

void main() {
  final expiresAt = DateTime.utc(2026, 12, 10, 9, 46, 7);

  test('countdown_uses_the_server_clock', () {
    final deviceNow = DateTime.utc(2026, 12, 10, 9, 40);
    const offset = Duration(minutes: 3);
    expect(RingCountdown.remaining(expiresAt, offset: offset, now: deviceNow), const Duration(minutes: 3, seconds: 7));
    expect(RingCountdown.label(expiresAt, offset: offset, now: deviceNow), '3:07');
    expect(RingCountdown.label(expiresAt, offset: Duration.zero, now: deviceNow), '6:07');
    expect(RingCountdown.label(expiresAt, offset: const Duration(minutes: -2), now: deviceNow.toLocal()), '8:07');
    expect(
      RingCountdown.label(expiresAt, offset: Duration.zero, now: DateTime.utc(2026, 12, 10, 9, 41, 22, 500)),
      '4:45',
    );
    expect(RingCountdown.label(DateTime.utc(2026, 12, 10, 10, 1), offset: offset, now: DateTime.utc(2026, 12, 10, 9, 43)),
        '15:00');
  });

  test('countdown_stops_at_zero', () {
    final after = DateTime.utc(2026, 12, 10, 9, 50);
    expect(RingCountdown.remaining(expiresAt, offset: Duration.zero, now: after), Duration.zero);
    expect(RingCountdown.label(expiresAt, offset: Duration.zero, now: after), '0:00');
    expect(RingCountdown.isOver(expiresAt, offset: Duration.zero, now: after), isTrue);
    expect(RingCountdown.isOver(expiresAt, offset: const Duration(minutes: -10), now: after), isFalse);
    expect(RingCountdown.remaining(null, offset: Duration.zero, now: after), Duration.zero);
    expect(RingCountdown.text(const Duration(seconds: -5)), '0:00');
  });
}
