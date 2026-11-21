import 'package:get/get.dart';

import '../../config/shell_kind.dart';
import '../owner_core/session/owner_push_sync.dart';
import '../owner_core/session/owner_session_hooks.dart';
import '../owner_core/session/shell_teardown.dart';
import 'taxi_driver_deps.dart';
import 'home/taxi_driver_home_controller.dart';
import '../../config/notification_types.dart';
import '../../services/taxi_ring_session.dart';
import '../taxi/requests/controllers/driver_app_bookings_controller.dart';
import 'notices/taxi_notice_copy.dart';

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
    TaxiDriverDeps.refreshHome = () async => await TaxiDriverHomeController.maybe?.reload();
    // end A5
    // A6 session
    TaxiNoticeCopy.register();
    OwnerSessionHooks.register('${name}_work', (_, _) {
      TaxiRingSession.reset();
      TaxiNoticeCopy.debugPlan = null;
    });
    OwnerPushSync.register('${name}_work', (type, args) {
      if (NotificationTypeKeys.isDriverTaxi(type)) DriverAppBookingsController.onPushIfRegistered();
    });
    // end A6
    // A7 session
    // end A7
    // A8 session
    // end A8
  }
}
