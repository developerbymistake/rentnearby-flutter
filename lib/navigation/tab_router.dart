import 'package:flutter/material.dart';
import '../config/app_tabs.dart';
import '../screens/home_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/explore_plots_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/chats_list_screen.dart';
import 'tab_keys.dart';

Widget _rootScreen(int tabId) {
  switch (tabId) {
    case AppTabs.home: return const HomeScreen();
    case AppTabs.rooms: return const ExploreScreen();
    case AppTabs.plots: return const ExplorePlotsScreen();
    case AppTabs.chats: return const ChatsListScreen();
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
        pageBuilder: (_, __, ___) => _rootScreen(tabId),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
