import 'dart:math';

typedef NearbyCentre = (double, double);

class NearbySettled {
  const NearbySettled({required this.loadFailed, required this.markLoaded, required this.rebuildMarkers, required this.playSound});
  final bool loadFailed;
  final bool markLoaded;
  final bool rebuildMarkers;
  final bool playSound;

  factory NearbySettled.of({required bool ok, required bool nearestActive, required bool hasStays}) {
    final rebuild = ok && !nearestActive;
    return NearbySettled(loadFailed: !ok, markLoaded: ok, rebuildMarkers: rebuild, playSound: rebuild && hasStays);
  }
}

class StayNearbyLoader {
  StayNearbyLoader({
    required this.centre,
    required this.radius,
    required this.isPaused,
    required this.isMounted,
    required this.fetch,
    required this.nearestActive,
    required this.hasStays,
    required this.onStart,
    required this.onSettled,
  });

  final NearbyCentre Function() centre;
  final double Function() radius;
  final bool Function() isPaused;
  final bool Function() isMounted;
  final Future<bool> Function(double lat, double lng, double radius) fetch;
  final bool Function() nearestActive;
  final bool Function() hasStays;
  final void Function() onStart;
  final void Function(NearbySettled result) onSettled;

  bool stale = false;
  bool loading = false;
  bool reloadPending = false;
  bool loadFailed = false;
  bool hasLoadedOnce = false;
  bool _rerunAfter = false;

  Future<void> run() async {
    if (loading) {
      _rerunAfter = true;
      return;
    }
    if (isPaused()) {
      stale = true;
      reloadPending = false;
      return;
    }
    stale = false;
    loading = true;
    var rerun = false;
    try {
      onStart();
      final c = centre();
      final r = radius();
      final ok = await fetch(c.$1, c.$2, r);
      if (!isMounted()) return;
      if (c == centre() && r == radius()) {
        final result = NearbySettled.of(ok: ok, nearestActive: nearestActive(), hasStays: hasStays());
        loadFailed = result.loadFailed;
        if (result.markLoaded) hasLoadedOnce = true;
        onSettled(result);
      } else {
        rerun = true;
      }
    } finally {
      loading = false;
      if (_rerunAfter) {
        _rerunAfter = false;
        rerun = true;
      }
      if (!rerun) reloadPending = false;
    }
    if (rerun && isMounted()) await run();
  }
}

class StayMapRules {
  static bool shouldRebuildMarkers({required bool markersDirty, required double lastBuildZoom, required double idleZoom}) =>
      markersDirty || (idleZoom - lastBuildZoom).abs() >= 0.4;

  static double zoomForRadius(double radiusKm, double lat, double screenWidth) {
    const earthCircumference = 2 * pi * 6378137.0;
    const tileSize = 512.0;
    final usablePx = screenWidth > 0 ? screenWidth : 480.0;
    final metersPerPxAtZ0 = earthCircumference * cos(lat * pi / 180) / tileSize;
    final targetMetersPerPx = (radiusKm * 1000 * 2) / (usablePx * 0.93);
    final zoom = log(metersPerPxAtZ0 / targetMetersPerPx) / log(2);
    return zoom.clamp(9.0, 17.0);
  }
}
