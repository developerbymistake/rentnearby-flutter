import 'package:get/get.dart';
import 'banner_hub_service.dart';
import 'chat_hub_service.dart';
import 'inquiry_hub_service.dart';
import 'wallet_hub_service.dart';

bool _loggingOut = false;

/// True only while [disconnectAllHubs] is actually running — checked by every hub's connect
/// guard so a same-instant connect() (app-resume, MainScreen mount) can't slip a fresh
/// connection into the exact window a logout is tearing hubs down, which disconnectAllHubs()
/// would never then touch. Cleared the moment all 4 disconnects finish, not on a timer — once
/// hubs are actually torn down, a connect() a millisecond later is legitimate (e.g. a fast
/// re-login) and must not be blocked.
bool get isHubSessionLoggingOut => _loggingOut;

/// The one place every SignalR hub tied to the current session gets torn down — called both
/// from an explicit logout/account-deletion AND from a server-forced 401 (revoked session).
/// Before this existed, only the explicit-logout path disconnected hubs; a session revoked
/// out from under the app (admin action, forced logout elsewhere, a JWT edge case) left every
/// hub — chat in particular, whose retry policy deliberately never gives up — retrying forever
/// in the background with an empty token, even sitting on the login screen. A future 5th hub
/// only needs wiring here once instead of being added to every call site individually.
Future<void> disconnectAllHubs() async {
  _loggingOut = true;
  // Concurrent, not sequential — a `for` + `await` loop here would make the whole call take
  // the SUM of all 4 WebSocket-close latencies instead of the max, visibly delaying the
  // "session expired" redirect on a forced 401. Each disconnect is still independently
  // try-caught so one hub failing to close cleanly never blocks the others.
  await Future.wait([
    _safeDisconnect(() => Get.find<BannerHubService>().disconnect()),
    _safeDisconnect(() => Get.find<ChatHubService>().disconnect()),
    _safeDisconnect(() => Get.find<WalletHubService>().disconnect()),
    _safeDisconnect(() => Get.find<InquiryHubService>().disconnect()),
  ]);
  _loggingOut = false;
}

Future<void> _safeDisconnect(Future<void> Function() disconnect) async {
  try {
    await disconnect();
  } catch (_) {}
}
