/// Bottom-nav tab indices — single source of truth. See main_screen.dart's
/// _screens list and tab_router.dart's switch for how these map to screens.
class AppTabs {
  static const int home = 0;
  static const int stays = 1;
  static const int trips = 2;
  static const int taxi = 3;
  static const int profile = 4;
  static const int count = 5;

  // String keys matching the backend's master table (RentNearBy.Core.Models.AppTabKeys) —
  // TabConfigController reads active/rename state keyed by these, not by int index.
  // Trips is not in the master table, so it is always active (like Home).
  static const Map<int, String> tabKeys = {
    home: 'HOME',
    stays: 'STAYS',
    trips: 'TRIPS',
    taxi: 'TAXI',
    profile: 'PROFILE',
  };
}
