import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bakhli/services/stay_ring_decline_bridge.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '5a5a5a5a-0001-4a00-8000-000000000001';

String _payload({String route = TaxiRingPush.stayRingRoute, String argKey = 'enquiryId'}) => jsonEncode({
      'notification_type': route == TaxiRingPush.stayRingRoute ? 'stay_enquiry_ring' : 'taxi_request_ring',
      'action_route': route,
      'action_args_json': jsonEncode({argKey: _id}),
      TaxiRingNotification.tagKey: route == TaxiRingPush.stayRingRoute ? 'stay_ring_$_id' : 'taxi_ring_$_id',
    });

String _read(String path) => File(path).readAsStringSync().replaceAll(String.fromCharCode(13), '');

void main() {
  test('Decline on a stay ring notification gives its enquiry id', () {
    expect(StayRingDeclineBridge.declinedEnquiry(TaxiRingNotification.declineAction, _payload()), _id);
  });

  test('Accept, a plain tap, a taxi ring and a broken payload are not a stay decline', () {
    expect(StayRingDeclineBridge.declinedEnquiry(TaxiRingNotification.acceptAction, _payload()), isNull);
    expect(StayRingDeclineBridge.declinedEnquiry(null, _payload()), isNull);
    expect(
      StayRingDeclineBridge.declinedEnquiry(TaxiRingNotification.declineAction, _payload(route: TaxiRingPush.ringRoute, argKey: 'offerId')),
      isNull,
    );
    expect(StayRingDeclineBridge.declinedEnquiry(TaxiRingNotification.declineAction, 'not json'), isNull);
    expect(StayRingDeclineBridge.declinedEnquiry(TaxiRingNotification.declineAction, null), isNull);
  });

  test('the background isolate tells the running app; nothing runs without it', () async {
    final port = ReceivePort();
    final got = Completer<Object?>();
    port.listen(got.complete);
    final names = <String>[];
    final told = StayRingDeclineBridge.forward(TaxiRingNotification.declineAction, _payload(), lookup: (n) {
      names.add(n);
      return port.sendPort;
    });
    expect(told, isTrue);
    expect(names, [StayRingDeclineBridge.portName]);
    expect(await got.future.timeout(const Duration(seconds: 2)), _id);
    port.close();
    expect(StayRingDeclineBridge.forward(TaxiRingNotification.declineAction, _payload(), lookup: (_) => null), isFalse);
    expect(StayRingDeclineBridge.forward(TaxiRingNotification.acceptAction, _payload(), lookup: (_) => fail('no lookup')), isFalse);
  });

  test('the notification Decline reaches the app side decline, which never calls the server', () {
    final src = _read('lib/services/notification_service.dart');
    expect(src, contains('StayRingDeclineBridge.forward(response.actionId, response.payload);'));
    expect(src, contains('StayRingDeclineBridge.listen((id) => _declineStayRing(id, TaxiRingNotification.stayTagFor(id)));'));
    final bridge = _read('lib/services/stay_ring_decline_bridge.dart');
    for (final word in ['ApiService', 'OwnerApi', 'StayRingApi', 'Dio']) {
      expect(bridge, isNot(contains(word)), reason: word);
    }
  });
}
