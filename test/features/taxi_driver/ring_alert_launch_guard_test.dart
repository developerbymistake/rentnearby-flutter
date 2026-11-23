import 'dart:io';

import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kt = File('android/app/src/main/kotlin/com/rentnearby/rentnearby/MainActivity.kt').readAsStringSync().replaceAll(String.fromCharCode(13), '');

  String fn(String head) {
    final start = kt.indexOf(head);
    expect(start, greaterThan(0), reason: head);
    return kt.substring(start, kt.indexOf('\n    }\n', start));
  }

  test('native_ring_launch_check_matches_the_dart_ring_payload_check', () {
    final push = TaxiRingPush(
      kind: TaxiRingKind.ring,
      offerId: 'o1',
      requestId: 'r1',
      expiresAt: DateTime.utc(2026, 12, 10),
      ackToken: 't',
      title: 'x',
      lines: const [],
      reason: null,
    );
    final data = TaxiRingNotification.routeData(push);
    expect(TaxiRingNotification.isRingPayload(data), isTrue);
    expect(TaxiRingNotification.isRingPayload({...data, 'action_route': '/chat-conversation'}), isFalse);

    final tag = fn('private fun ringTag(');
    expect(tag, contains('payload.optString("notification_type") == RING_TYPE'));
    expect(tag, contains('payload.optString("action_route") == RING_ROUTE'));
    expect(kt, contains('private const val RING_TYPE = "${data['notification_type']}"'));
    expect(kt, contains('private const val RING_ROUTE = "${TaxiRingPush.ringRoute}"'));
    expect(kt, contains('private const val RING_TAG = "${TaxiRingNotification.tagKey}"'));
  });

  test('lock_flags_are_never_set_from_dart_or_the_manifest', () {
    expect(fn('private fun holdRingAlert('), isNot(contains('setRingAlert(true)')));
    expect(fn('private fun endRingAlert('), isNot(contains('setRingAlert(true)')));
    expect('setRingAlert(true)'.allMatches(kt).length, 1);
    expect(fn('private fun armRingAlert('), contains('setRingAlert(true)'));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final added = RegExp(r'android\.permission\.[A-Z_]+').allMatches(manifest).map((m) => m.group(0)).toSet();
    expect(added, {
      'android.permission.INTERNET',
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.CAMERA',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.VIBRATE',
      'android.permission.WAKE_LOCK',
      'android.permission.USE_FULL_SCREEN_INTENT',
    });
  });
}
