import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_tabs.dart';
import '../controllers/tab_config_controller.dart';
import '../screens/home_screen.dart';
import '../models/explore_kind.dart';
import '../screens/explore_landing_screen.dart';
import '../screens/profile_screen.dart';
import '../features/stay/guest/stay_landing_screen.dart';
import '../features/jobs/screens/jobs_landing_screen.dart';
import '../features/taxi/guest/taxi_list_screen.dart';
import 'tab_keys.dart';

Widget _rootScreen(int tabId) {
  switch (tabId) {
    case AppTabs.home: return const HomeScreen();
    case AppTabs.rooms: return const ExploreLandingScreen(kind: ExploreKind.rooms);
    case AppTabs.plots: return const ExploreLandingScreen(kind: ExploreKind.plots);
    case AppTabs.stays: return const StayLandingScreen();
    case AppTabs.jobs: return const JobsLandingScreen();
    case AppTabs.taxi: return const TaxiListScreen(root: true);
    case AppTabs.profile: return const ProfileScreen();
    default: return const SizedBox.shrink();
  }
}

/// Wraps each bottom tab in its own Navigator.
/// Each tab gets a separate widget subtree — keyboard events, layout changes
/// and MediaQuery insets from one tab cannot affect any other tab.
/// All deep-screen navigation (Get.toNamed, Get.back etc.) is unchanged and
/// still goes through the global GetX navigator as before.
class TabNavigator extends StatelessWidget {
  final int tabId;
  const TabNavigator({required this.tabId, super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: tabKeys[tabId],
      onGenerateRoute: (_) => PageRouteBuilder(
        // An inactive tab's root is never built, so it makes no API call and puts no controller.
        pageBuilder: (_, __, ___) => Obx(
          () => TabConfigController.to.isActiveForIndex(tabId) ? _rootScreen(tabId) : const SizedBox.shrink(),
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
