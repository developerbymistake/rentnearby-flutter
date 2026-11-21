import '../owner_core/session/owner_session_hooks.dart';

abstract final class SeekerSession {
  static const String name = 'seeker_home';

  static void register() {
    OwnerSessionHooks.register(name, (_, _) {});
    // A1 session
    // end A1
  }
}
