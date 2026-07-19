import 'package:get/get.dart';
import 'banner_hub_service.dart';
import 'chat_hub_service.dart';
import 'inquiry_hub_service.dart';
import 'wallet_hub_service.dart';

/// The one place every SignalR hub tied to the current session gets torn down — called both
/// from an explicit logout/account-deletion AND from a server-forced 401 (revoked session).
/// Before this existed, only the explicit-logout path disconnected hubs; a session revoked
/// out from under the app (admin action, forced logout elsewhere, a JWT edge case) left every
/// hub — chat in particular, whose retry policy deliberately never gives up — retrying forever
/// in the background with an empty token, even sitting on the login screen. A future 5th hub
/// only needs wiring here once instead of being added to every call site individually.
Future<void> disconnectAllHubs() async {
  for (final disconnect in [
    () => Get.find<BannerHubService>().disconnect(),
    () => Get.find<ChatHubService>().disconnect(),
    () => Get.find<WalletHubService>().disconnect(),
    () => Get.find<InquiryHubService>().disconnect(),
  ]) {
    try {
      await disconnect();
    } catch (_) {}
  }
}
