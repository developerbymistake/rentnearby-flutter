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
  // The shell MainScreen shows; null reads the session shell (tests).
  final Rx<ShellKind>? shell;
  const TabNavigator({required this.tabId, this.shell, super.key});

  @visibleForTesting
  static Widget Function(int tabId)? debugRoot;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: tabKeys[tabId],
      onGenerateRoute: (_) => PageRouteBuilder(
        // An inactive tab's root is never built, so it makes no API call and puts no controller.
        // A tab not visited yet is not built either (FX-06): no call until the user opens it.
        pageBuilder: (_, _, _) => Obx(() {
          TabConfigController.to.version.value;
          final auth = Get.find<AuthController>();
          final kind = (shell ?? auth.shellKind).value;
          final visited = auth.tabIndex.value == tabId || auth.visitedTabs.contains(tabId);
          final slot = TabShell.slots(kind)[tabId];
          return KeyedSubtree(
            key: ValueKey('${kind.name}-$tabId'),
            child: visited && slot.active() ? (debugRoot?.call(tabId) ?? slot.root()) : const SizedBox.shrink(),
          );
        }),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
