import 'package:get/get.dart';

import '../../config/shell_kind.dart';
import '../owner_core/session/owner_push_sync.dart';
import '../owner_core/session/owner_session_hooks.dart';
import '../owner_core/session/shell_teardown.dart';
import 'taxi_driver_deps.dart';
import 'home/taxi_driver_home_controller.dart';

abstract final class TaxiDriverSession {
  static const String name = 'taxi_driver';

  static void register() {
    OwnerSessionHooks.register(name, (_, _) => TaxiDriverDeps.debugReset());
    OwnerSessionHooks.refreshHome = () => TaxiDriverDeps.refreshHome();
    OwnerPushSync.register(name, (type, args) {});
    ShellTeardown.register(ShellKind.taxiDriver, () {
      if (Get.isRegistered<TaxiDriverHomeController>()) Get.delete<TaxiDriverHomeController>(force: true);
    });
    // A5 session
    // end A5
    // A6 session
    // end A6
    // A7 session
    // end A7
    // A8 session
    // end A8
  }
}
