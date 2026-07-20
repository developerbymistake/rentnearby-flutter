import 'package:flutter/widgets.dart';
import '../config/app_map_state.dart';

const _pauseRoutes = {
  '/add-listing',
  '/add-plot',
  '/phone-verify',
  '/onboarding',
  '/listing-detail',
  '/plot-detail',
  '/chat-conversation',
  '/chats-list',
  '/my-listings',
  '/my-plots',
  '/listing-reports',
  '/report-detail',
  '/my-filed-reports',
  '/view-all-rooms',
  '/view-all-plots',
};

class MapPauseObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pauseRoutes.contains(route.settings.name)) mapShouldPause.value = true;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Only un-pause if the route now revealed ISN'T also a pause-route —
    // otherwise popping one paused screen back onto another (e.g.
    // /add-listing -> /my-listings) incorrectly resumes the map while the
    // user is still on a screen that should keep it paused.
    if (_pauseRoutes.contains(route.settings.name) &&
        !_pauseRoutes.contains(previousRoute?.settings.name)) {
      mapShouldPause.value = false;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pauseRoutes.contains(route.settings.name) &&
        !_pauseRoutes.contains(previousRoute?.settings.name)) {
      mapShouldPause.value = false;
    }
  }
}
