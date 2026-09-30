import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/tour_controller.dart';
import '../config/app_tabs.dart';
import '../navigation/tab_keys.dart';
import '../screens/explore_plots_screen.dart';
import '../screens/explore_screen.dart';

class ExploreNavigation {
  static const _mapRouteName = '/explore-map';

  static Future<void> openMap(int tabIndex, {bool startNearest = false}) async {
    if (tabIndex != AppTabs.rooms && tabIndex != AppTabs.plots) return;
    final nav = tabKeys[tabIndex].currentState;
    if (nav == null) return;
    if (Get.isRegistered<TourController>()) Get.find<TourController>().forceDismissForNavigation();
    Route<dynamic>? top;
    nav.popUntil((route) {
      top = route;
      return route.settings.name == _mapRouteName || route.isFirst;
    });
    if (top?.settings.name == _mapRouteName) return;
    await nav.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: _mapRouteName),
      builder: (_) => tabIndex == AppTabs.plots
          ? ExplorePlotsScreen(startNearest: startNearest)
          : ExploreScreen(startNearest: startNearest),
    ));
  }
}
