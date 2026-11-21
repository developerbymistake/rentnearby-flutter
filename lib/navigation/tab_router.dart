import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/tab_shell.dart';
import '../controllers/auth_controller.dart';
import '../controllers/tab_config_controller.dart';
import 'tab_keys.dart';

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
        pageBuilder: (_, _, _) => Obx(() {
          TabConfigController.to.version.value;
          final kind = Get.find<AuthController>().shellKind.value;
          final slot = TabShell.slots(kind)[tabId];
          return KeyedSubtree(
            key: ValueKey('${kind.name}-$tabId'),
            child: slot.active() ? slot.root() : const SizedBox.shrink(),
          );
        }),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
