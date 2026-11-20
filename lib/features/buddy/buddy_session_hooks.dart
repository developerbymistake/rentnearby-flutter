import '../../controllers/auth_controller.dart';
import 'buddies/data/buddies_api.dart';
import 'buddy_live.dart';
import 'offline/logout_guard.dart';

abstract final class BuddySessionHooks {
  static Future<void> onLogout(LogoutReason reason, String? userId) async {
    BuddiesApi.clearSessionCache();
    BuddyLive.reset();
    await SessionEndedNotice.onLogout(reason, userId);
  }
}
