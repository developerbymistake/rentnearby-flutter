import 'package:get/get.dart';

import '../../config/shell_kind.dart';
import '../owner_core/session/owner_push_sync.dart';
import '../owner_core/session/owner_session_hooks.dart';
import '../owner_core/session/shell_teardown.dart';
import 'stay_owner_deps.dart';
import 'home/stay_owner_home_controller.dart';

abstract final class StayOwnerSession {
  static const String name = 'stay_owner';

  static void register() {
    OwnerSessionHooks.register(name, (_, _) => StayOwnerDeps.debugReset());
    OwnerSessionHooks.refreshHome = () => StayOwnerDeps.refreshHome();
    OwnerPushSync.register(name, (type, args) {});
    ShellTeardown.register(ShellKind.stayOwner, () {
      if (Get.isRegistered<StayOwnerHomeController>()) Get.delete<StayOwnerHomeController>(force: true);
    });
    // A2 session
    // end A2
    // A3 session
    // end A3
    // A4 session
    // end A4
    // A8 session
    // end A8
  }
}
