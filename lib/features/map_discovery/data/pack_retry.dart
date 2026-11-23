import 'dart:async';

import 'package:get/get.dart';

import '../../trip/map/discovery_api.dart';
import '../pack/map_pack_constants.dart';

// Asks a map screen to load its pack again after a failed first download: once when the phone comes back
// online, and by a one-shot timer after the service back-off (at most [maxAttempts] per screen). No polling.
class PackRetry {
  final DiscoveryDataSource source;
  final void Function() ensure;
  final void Function()? retryPhotos;
  final Duration delay;
  final int maxAttempts;
  final List<Worker> _workers = [];
  Timer? _timer;
  int _attempts = 0;
  DiscoveryDataState _last;

  static const Duration defaultDelay = Duration(seconds: 1);

  PackRetry({
    required this.source,
    required this.ensure,
    this.retryPhotos,
    RxBool? offline,
    Duration? delay,
    this.maxAttempts = 3,
  })  : delay = delay ?? MapPackConstants.retryAfter + defaultDelay,
        _last = source.state.value {
    _workers.add(ever<DiscoveryDataState>(source.state, _onState));
    if (offline != null) {
      _workers.add(ever<bool>(offline, (off) {
        if (off) return;
        ensure();
        retryPhotos?.call();
      }));
    }
  }

  int get attempts => _attempts;

  bool get scheduled => _timer?.isActive ?? false;

  void _onState(DiscoveryDataState s) {
    final from = _last;
    _last = s;
    if (s == DiscoveryDataState.ready) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (from != DiscoveryDataState.loading || s != DiscoveryDataState.none) return;
    if (_attempts >= maxAttempts || scheduled) return;
    _attempts++;
    _timer = Timer(delay, () {
      _timer = null;
      ensure();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final w in _workers) {
      w.dispose();
    }
    _workers.clear();
  }
}
