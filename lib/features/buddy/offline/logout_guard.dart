import 'package:flutter/widgets.dart';

import '../../../controllers/auth_controller.dart';

abstract final class LogoutGuard {
  static Future<bool> check(BuildContext context) async => true;
}

abstract final class SessionEndedNotice {
  static Future<void> onLogout(LogoutReason reason, String? userId) async {}
}
