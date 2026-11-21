import 'package:get/get.dart';

import '../../config/shell_kind.dart';
import '../owner_core/session/owner_session_hooks.dart';
import '../owner_core/session/shell_teardown.dart';
import 'seeker_feed_controller.dart';

abstract final class SeekerSession {
  static const String name = 'seeker_home';

  static void register() {
    OwnerSessionHooks.register(name, (_, _) {});
    // A1 session
    OwnerSessionHooks.register(name, (_, _) => SeekerFeedController.maybe?.reset());
    ShellTeardown.register(ShellKind.seeker, () {
      if (Get.isRegistered<SeekerFeedController>()) Get.delete<SeekerFeedController>(force: true);
    });
    // end A1
  }
}
