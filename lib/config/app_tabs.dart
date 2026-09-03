/// Bottom-nav tab indices — single source of truth. See main_screen.dart's
/// _screens list and tab_router.dart's switch for how these map to screens.
class AppTabs {
  static const int home = 0;
  static const int rooms = 1;
  static const int plots = 2;
  static const int services = 3; // local services marketplace — was `chats`, then `explore`, same index
  static const int profile = 4;
  static const int count = 5;

  // String keys matching the backend's master table (RentNearBy.Core.Models.AppTabKeys) —
  // TabConfigController reads active/rename state keyed by these, not by int index.
  static const Map<int, String> tabKeys = {
    home: 'HOME',
    rooms: 'ROOMS',
    plots: 'PLOTS',
    services: 'SERVICES',
    profile: 'PROFILE',
  };
}
