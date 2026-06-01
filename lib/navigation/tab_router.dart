import 'package:flutter/material.dart';
import '../screens/explore_screen.dart';
import '../screens/my_listings_screen.dart';
import '../screens/explore_plots_screen.dart';
import '../screens/my_plots_screen.dart';
import '../screens/profile_screen.dart';
import 'tab_keys.dart';

Widget _rootScreen(int tabId) {
  switch (tabId) {
    case 0: return const ExploreScreen();
    case 1: return const MyListingsScreen();
    case 2: return const ExplorePlotsScreen();
    case 3: return const MyPlotsScreen();
    case 4: return const ProfileScreen();
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
        pageBuilder: (_, __, ___) => _rootScreen(tabId),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
