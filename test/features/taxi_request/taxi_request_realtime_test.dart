import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/services/notification_hub_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'taxi_request_controller_fakes.dart';

const _id = '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101';

class _Hub {
  final List<String> sent = [];
  late final TaxiRequestSubscriptions subs = TaxiRequestSubscriptions((method, id) async => sent.add('$method:$id'));
}

({TripTaxiRequestController c, FakeTaxiRepo repo, _Hub hub}) _setUp() {
  final repo = FakeTaxiRepo();
  var server = sampleRequest('taxi_request_collecting.json');
  final hub = _Hub();
  final c = TripTaxiRequestController(
    repo: repo,
    enquiries: FakeEnquiries(),
    realtime: hub.subs,
    refreshPlan: (_) async => true,
    onLegacyClosed: () {},
  );
  repo.getAnswer = (id) => TaxiOk(server);
  _serverVersion = (int v) => server = sampleRequest('taxi_request_collecting.json', change: {'version': v});
  return (c: c, repo: repo, hub: hub);
}

late void Function(int v) _serverVersion;

Map<String, dynamic> _event(int version, {int v = 1, String id = _id}) =>
    {...sampleJson('signalr_taxi_request_changed.json'), 'version': version, 'v': v, 'requestId': id};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('event_triggers_one_get', () async {
    final s = _setUp();
    s.c.attach(_id);
    await pumpEventQueue();
    expect(s.repo.getIds, [_id]);
    expect(s.c.request.value!.version, 6);

    _serverVersion(7);
    s.hub.subs.onEvent(sampleJson('signalr_taxi_request_changed.json'));
    await pumpEventQueue();
    expect(s.repo.getIds.length, 2);
    expect(s.c.request.value!.version, 7);

    s.hub.subs.onEvent(_event(7));
    s.hub.subs.onEvent(_event(5));
    s.hub.subs.onEvent(_event(9, v: 2));
    s.hub.subs.onEvent(_event(9, id: 'other'));
    await pumpEventQueue();
    expect(s.repo.getIds.length, 2);
    s.c.detach();
  });

  test('reconnect_resubscribes_and_gets', () async {
    final s = _setUp();
    s.c.attach(_id);
    await pumpEventQueue();
    expect(s.hub.sent, ['SubscribeTaxiRequest:$_id']);
    expect(s.repo.getIds.length, 1);

    s.hub.subs.onConnected();
    await pumpEventQueue();
    expect(s.hub.sent, ['SubscribeTaxiRequest:$_id', 'SubscribeTaxiRequest:$_id']);
    expect(s.repo.getIds.length, 2);
    s.c.detach();
  });

  test('resume_gets', () async {
    final s = _setUp();
    s.c.attach(_id);
    await pumpEventQueue();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(s.repo.getIds.length, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(s.repo.getIds.length, 2);

    s.c.detach();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(s.repo.getIds.length, 2);
  });

  test('detach_unsubscribes', () async {
    final s = _setUp();
    s.c.attach(_id);
    await pumpEventQueue();
    expect(s.hub.subs.isSubscribed(_id), isTrue);

    s.c.detach();
    expect(s.hub.sent.last, 'UnsubscribeTaxiRequest:$_id');
    expect(s.hub.subs.isSubscribed(_id), isFalse);
    s.hub.subs.onEvent(_event(20));
    s.hub.subs.onConnected();
    await pumpEventQueue();
    expect(s.repo.getIds.length, 1);
  });

  test('end_state_unsubscribes_but_keeps_the_object', () async {
    final s = _setUp();
    s.c.attach(_id);
    await pumpEventQueue();
    s.c.apply(sampleRequest('taxi_request_rate.json'));
    expect(s.c.request.value!.view, RequestView.rate);
    expect(s.hub.sent.last, 'UnsubscribeTaxiRequest:$_id');
    expect(s.hub.subs.isSubscribed(_id), isFalse);
    s.c.detach();
  });

  test('taxi_push_gets_once', () async {
    final s = _setUp();
    s.c.attach(_id);
    await pumpEventQueue();
    s.c.onTaxiPush();
    await pumpEventQueue();
    expect(s.repo.getIds.length, 2);
    s.c.detach();
  });
}
