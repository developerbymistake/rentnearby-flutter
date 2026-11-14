import 'dart:async';

import 'package:bakhli/features/stay/guest/stay_map_load_logic.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  double radius = 12;
  NearbyCentre centre = (30.0, 79.0);
  bool paused = false;
  bool mounted = true;
  bool nearest = false;
  bool hasStays = true;
  int starts = 0;
  final calls = <double>[];
  final settled = <NearbySettled>[];
  final pending = <Completer<bool>>[];

  late final loader = StayNearbyLoader(
    centre: () => centre,
    radius: () => radius,
    isPaused: () => paused,
    isMounted: () => mounted,
    fetch: (lat, lng, r) {
      calls.add(r);
      final c = Completer<bool>();
      pending.add(c);
      return c.future;
    },
    nearestActive: () => nearest,
    hasStays: () => hasStays,
    onStart: () => starts++,
    onSettled: settled.add,
  );
}

void main() {
  test('chip tap during an in-flight load ends on the last radius', () async {
    final h = _Harness();
    final first = h.loader.run();
    h.radius = 20;
    await h.loader.run();
    h.pending[0].complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(h.calls, [12, 20]);
    h.pending[1].complete(true);
    await first;
    expect(h.settled.length, 1);
    expect(h.loader.loading, false);
    expect(h.loader.reloadPending, false);
  });

  test('stale response is ignored when the radius changed', () async {
    final h = _Harness();
    final f = h.loader.run();
    h.radius = 6;
    h.pending[0].complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(h.settled, isEmpty);
    expect(h.calls, [12, 6]);
    h.pending[1].complete(true);
    await f;
    expect(h.settled.length, 1);
  });

  test('stale response is ignored when the centre changed', () async {
    final h = _Harness();
    final f = h.loader.run();
    h.centre = (31.0, 78.0);
    h.pending[0].complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(h.settled, isEmpty);
    h.pending[1].complete(true);
    await f;
    expect(h.settled.length, 1);
  });

  test('empty result is not a failure and plays no sound', () async {
    final h = _Harness()..hasStays = false;
    final f = h.loader.run();
    h.pending[0].complete(true);
    await f;
    expect(h.loader.loadFailed, false);
    expect(h.loader.hasLoadedOnce, true);
    expect(h.settled.single.playSound, false);
    expect(h.settled.single.rebuildMarkers, true);
  });

  test('failed load reports an error and does not mark loaded', () async {
    final h = _Harness();
    final f = h.loader.run();
    h.pending[0].complete(false);
    await f;
    expect(h.loader.loadFailed, true);
    expect(h.loader.hasLoadedOnce, false);
    expect(h.settled.single.rebuildMarkers, false);
    expect(h.settled.single.playSound, false);
  });

  test('sound plays after a non-empty load only', () async {
    final h = _Harness();
    final f = h.loader.run();
    h.pending[0].complete(true);
    await f;
    expect(h.settled.single.playSound, true);
  });

  test('no markers or sound while nearest is active', () {
    final r = NearbySettled.of(ok: true, nearestActive: true, hasStays: true);
    expect(r.rebuildMarkers, false);
    expect(r.playSound, false);
    expect(r.markLoaded, true);
  });

  test('paused map defers the load and marks it stale', () async {
    final h = _Harness()..paused = true;
    h.loader.reloadPending = true;
    await h.loader.run();
    expect(h.calls, isEmpty);
    expect(h.loader.stale, true);
    expect(h.loader.reloadPending, false);
  });

  test('stale flag clears when a load starts', () async {
    final h = _Harness();
    h.loader.stale = true;
    final f = h.loader.run();
    expect(h.loader.stale, false);
    h.pending[0].complete(true);
    await f;
  });

  test('unmounted screen stops without replay or callbacks', () async {
    final h = _Harness();
    final f = h.loader.run();
    h.mounted = false;
    h.radius = 6;
    h.pending[0].complete(true);
    await f;
    expect(h.calls, [12]);
    expect(h.settled, isEmpty);
    expect(h.loader.loading, false);
  });

  test('marker rebuild rule: dirty flag or zoom drift of 0.4', () {
    bool r(bool d, double last, double idle) => StayMapRules.shouldRebuildMarkers(markersDirty: d, lastBuildZoom: last, idleZoom: idle);
    expect(r(false, 13, 13.39), false);
    expect(r(false, 13, 13.4), true);
    expect(r(false, 13, 12.5), true);
    expect(r(true, 13, 13), true);
  });

  test('radius to zoom: larger radius zooms out, clamped, width fallback', () {
    final z1 = StayMapRules.zoomForRadius(1, 30, 400);
    final z12 = StayMapRules.zoomForRadius(12, 30, 400);
    final z20 = StayMapRules.zoomForRadius(20, 30, 400);
    expect(z1, greaterThan(z12));
    expect(z12, greaterThan(z20));
    expect(StayMapRules.zoomForRadius(0.001, 30, 400), 17.0);
    expect(StayMapRules.zoomForRadius(100000, 30, 400), 9.0);
    expect(StayMapRules.zoomForRadius(12, 30, 0), StayMapRules.zoomForRadius(12, 30, 480));
  });
}
