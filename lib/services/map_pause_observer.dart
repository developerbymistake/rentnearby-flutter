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
  '/my-listings',
  '/my-plots',
  '/listing-reports',
  '/report-detail',
  '/my-filed-reports',
};

class MapPauseObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pauseRoutes.contains(route.settings.name)) mapShouldPause.value = true;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pauseRoutes.contains(route.settings.name)) mapShouldPause.value = false;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pauseRoutes.contains(route.settings.name)) mapShouldPause.value = false;
  }
}
