import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class TopRouteObserver extends NavigatorObserver {
  static final RxnString top = RxnString();
  static final List<Route<dynamic>> _pages = [];

  static bool hasAny(Set<String> names) => _pages.any((r) => names.contains(r.settings.name));

  static void _set(Route<dynamic>? route) {
    if (route is PageRoute) top.value = route.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _pages.add(route);
    _set(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _pages.remove(route);
      _set(previousRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _pages.remove(route);
    if (route.settings.name == top.value) _set(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
    if (newRoute is PageRoute) {
      if (i >= 0) {
        _pages[i] = newRoute;
      } else {
        _pages.add(newRoute);
      }
    } else if (i >= 0) {
      _pages.removeAt(i);
    }
    _set(newRoute);
  }
}
