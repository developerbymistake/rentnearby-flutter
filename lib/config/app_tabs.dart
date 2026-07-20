/// Bottom-nav tab indices — single source of truth. See main_screen.dart's
/// _screens list and tab_router.dart's switch for how these map to screens.
class AppTabs {
  static const int home = 0;
  static const int rooms = 1;
  static const int plots = 2;
  static const int explore = 3; // local services marketplace — was `chats`, same index
  static const int profile = 4;
  static const int count = 5;
}
