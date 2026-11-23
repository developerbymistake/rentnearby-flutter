import 'dart:io';

import 'package:bakhli/features/map_discovery/data/pack_retry.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_constants.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Source implements DiscoveryDataSource {
  @override
  final Rx<DiscoveryDataState> state = DiscoveryDataState.none.obs;
  int ensures = 0;
  bool succeed = false;

  @override
  bool get enabled => true;
  @override
  int get version => 1;
  @override
  List<DiscoverySpot> all() => const [];
  @override
  DiscoverySpot? byId(String id) => null;
  @override
  List<DiscoverySpot> forCities(Iterable<int> cityKeys) => const [];
  @override
  List<DiscoverySpot> near(double lat, double lon, double km) => const [];
  @override
  Future<void> ensureForCities(Iterable<int> cityKeys) async => run();
  @override
  Future<void> ensureForPoint(double lat, double lon) async => run();

  // One download attempt: loading, then ready or back to none.
  void run() {
    ensures++;
    state.value = DiscoveryDataState.loading;
    state.value = succeed ? DiscoveryDataState.ready : DiscoveryDataState.none;
  }
}

void main() {
  test('the default delay is the service back-off plus one second', () {
    final r = PackRetry(source: _Source(), ensure: () {});
    expect(r.delay, MapPackConstants.retryAfter + const Duration(seconds: 1));
    r.dispose();
  });

  testWidgets('fail -> one-shot timer -> one more ensure; 3 fails -> no 4th; ready cancels', (t) async {
    final s = _Source();
    final r = PackRetry(source: s, ensure: () => s.ensureForCities(const [1]));
    s.run();
    expect(s.ensures, 1);
    expect(r.scheduled, isTrue);
    await t.pump(r.delay);
    expect(s.ensures, 2);
    await t.pump(r.delay);
    expect(s.ensures, 3);
    await t.pump(r.delay);
    expect(s.ensures, 4);
    expect(r.attempts, 3);
    expect(r.scheduled, isFalse);
    await t.pump(r.delay * 5);
    expect(s.ensures, 4, reason: 'at most 3 timer attempts per screen life');
    r.dispose();
  });

  testWidgets('ready cancels a pending timer; dispose cancels too', (t) async {
    final s = _Source();
    final r = PackRetry(source: s, ensure: () => s.ensureForCities(const [1]));
    s.run();
    expect(r.scheduled, isTrue);
    s.state.value = DiscoveryDataState.ready;
    expect(r.scheduled, isFalse);
    await t.pump(r.delay * 2);
    expect(s.ensures, 1);
    s.state.value = DiscoveryDataState.loading;
    s.state.value = DiscoveryDataState.none;
    expect(r.scheduled, isTrue);
    r.dispose();
    await t.pump(r.delay * 2);
    expect(s.ensures, 1);
  });

  testWidgets('journey: first download fails, phone comes back online -> exactly one more request, pack ready, photos retried', (t) async {
    final s = _Source();
    final offline = true.obs;
    var photoRetries = 0;
    final r = PackRetry(source: s, ensure: () => s.ensureForCities(const [1]), retryPhotos: () => photoRetries++, offline: offline);
    s.run();
    expect(s.ensures, 1);
    s.succeed = true;
    offline.value = false;
    await t.pump();
    expect(s.ensures, 2);
    expect(photoRetries, 1);
    expect(s.state.value, DiscoveryDataState.ready);
    expect(r.scheduled, isFalse);
    await t.pump(r.delay * 3);
    expect(s.ensures, 2);
    offline.value = true;
    await t.pump();
    expect(s.ensures, 2, reason: 'going offline asks nothing');
    r.dispose();
  });

  test('both map screens use the shared helper on the connectivity signal and dispose it', () {
    for (final f in ['lib/features/trip/screens/trip_map_screen.dart', 'lib/features/stay/guest/stay_map_screen.dart']) {
      final src = File(f).readAsStringSync();
      expect(src.contains('_packRetry = PackRetry('), isTrue, reason: f);
      expect(src.contains('retryPhotos: () => _disc?.retryPhotos()'), isTrue, reason: f);
      expect(src.contains('isOffline'), isTrue, reason: f);
      expect(src.contains('_packRetry?.dispose();'), isTrue, reason: f);
      expect(src.contains('DiscoveryDataState.none'), isTrue, reason: '$f: the signature short-cut is skipped while nothing is loaded');
    }
  });
}
