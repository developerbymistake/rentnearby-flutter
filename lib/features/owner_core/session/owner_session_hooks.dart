import '../../../controllers/auth_controller.dart';
import '../data/owner_cache.dart';
import 'owner_push_sync.dart';
import 'shell_teardown.dart';

typedef OwnerLogoutHook = void Function(LogoutReason reason, String? userId);

abstract final class OwnerSessionHooks {
  static final Map<String, OwnerLogoutHook> _hooks = {};

  static Future<void> _noRefresh() async {}

  static Future<void> Function() refreshHome = _noRefresh;

  static void register(String name, OwnerLogoutHook hook) => _hooks[name] = hook;

  static void unregister(String name) => _hooks.remove(name);

  static Iterable<String> get names => _hooks.keys;

  static Future<void> onLogout(LogoutReason reason, String? userId) async {
    OwnerCache.clearAll();
    refreshHome = _noRefresh;
    for (final h in List.of(_hooks.values)) {
      try {
        h(reason, userId);
      } catch (_) {}
    }
    ShellTeardown.reset();
    OwnerPushSync.reset();
  }
}
