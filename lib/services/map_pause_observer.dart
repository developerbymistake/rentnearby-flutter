import 'package:flutter/widgets.dart';
import '../config/app_map_state.dart';

const _pauseRoutes = {
  '/phone-verify',
  '/onboarding',
  '/chat-conversation',
  '/chats-list',
  '/listing-reports',
  '/report-detail',
  '/my-filed-reports',
  '/stay-setup',
  '/stay-basic-details',
  '/stay-rooms',
  '/stay-rules',
  '/stay-submit',
  '/stay-detail',
  '/my-stays',
  '/taxi-setup',
  '/taxi-vehicle',
  '/taxi-routes',
  '/taxi-submit',
  '/my-taxi',
  '/taxi-detail',
  '/taxi-list',
  '/trip-days',
  '/trip-spots',
  '/trip-plan',
  '/trip-taxi',
  '/trip-stay',
  '/trip-map',
  '/my-trips',
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
    // /stay-rooms -> /stay-setup) incorrectly resumes the map while the
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
