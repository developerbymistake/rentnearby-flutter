import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/tour_controller.dart';
import '../../../navigation/tab_keys.dart';
import 'stay_map_screen.dart';

class StayNavigation {
  static const _mapRouteName = '/stay-map';

  static Future<void> openMap() async {
    final nav = tabKeys[AppTabs.stays].currentState;
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
      builder: (_) => const StayMapScreen(),
    ));
  }
}
