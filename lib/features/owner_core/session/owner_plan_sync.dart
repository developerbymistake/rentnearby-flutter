import 'dart:async';

import 'package:get/get.dart';

typedef OwnerPlanHandler = void Function();

// One plan-changed signal (D-01): PlanController bumps planVersion when a /plans/me answer differs.
abstract final class OwnerPlanSync {
  static const debounce = Duration(milliseconds: 300);

  static final Map<String, OwnerPlanHandler> _handlers = {};
  static Worker? _worker;
  static RxInt? _source;
  static Timer? _timer;

  static void register(String name, OwnerPlanHandler handler) => _handlers[name] = handler;

  static void unregister(String name) => _handlers.remove(name);

  static Iterable<String> get names => _handlers.keys;

  static void bind(RxInt version) {
    if (identical(_source, version) && _worker != null) return;
    _worker?.dispose();
    _source = version;
    _worker = ever<int>(version, (_) => _schedule());
  }

  static void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, fire);
  }

  static void fire() {
    _timer?.cancel();
    _timer = null;
    for (final h in List.of(_handlers.values)) {
      try {
        h();
      } catch (_) {}
    }
  }

  static void reset() {
    _timer?.cancel();
    _timer = null;
    _worker?.dispose();
    _worker = null;
    _source = null;
    _handlers.clear();
  }
}
