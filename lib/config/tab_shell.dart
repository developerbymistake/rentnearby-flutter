import 'package:get/get.dart';

import '../controllers/location_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../design/tokens/listing_palette.dart';
import '../features/stay/guest/stay_landing_controller.dart';
import '../features/stay/guest/v2/stay_landing_screen_v2.dart';
import '../features/seeker_home/seeker_home_bindings.dart';
import '../features/stay_owner/stay_owner_bindings.dart';
import '../features/stay_owner/stay_owner_tabs.dart';
import '../features/taxi/guest/v2/taxi_list_screen_v2.dart';
import '../features/taxi/taxi_status_sync.dart';
import '../features/taxi_driver/taxi_driver_bindings.dart';
import '../features/taxi_driver/taxi_driver_tabs.dart';
import '../features/trip/screens/trips_discovery_screen.dart';
import '../navigation/tour_keys.dart';
import '../screens/home_screen.dart';
import 'app_tabs.dart';
import 'shell_kind.dart';
import 'tab_slot.dart';
import 'user_roles.dart';

export 'shell_kind.dart';
export 'tab_slot.dart';

abstract final class TabShell {
  static const Set<String> shellStatuses = {'PendingReview', 'Approved', 'Rejected'};

  static const String _t3d = 'assets/images/design/travel3d/';

  static ShellKind kindFor({required String roleKey, String? stayStatus, String? taxiStatus, required bool emptyShell}) {
    final caps = RoleCapabilities.of(roleKey);
    if (caps.canListStays && (shellStatuses.contains(stayStatus) || emptyShell)) return ShellKind.stayOwner;
    if (caps.canListTaxis && (shellStatuses.contains(taxiStatus) || emptyShell)) return ShellKind.taxiDriver;
    return ShellKind.seeker;
  }

  static List<TabSlot> slots(ShellKind kind) => switch (kind) {
        ShellKind.seeker => seekerSlots(),
        ShellKind.stayOwner => StayOwnerTabs.slots(),
        ShellKind.taxiDriver => TaxiDriverTabs.slots(),
      };

  static bool isActive(ShellKind kind, int index) {
    if (index < 0 || index >= AppTabs.count) return false;
    return slots(kind)[index].active();
  }

  static int? tabForRoute(ShellKind kind, String route, Map<String, dynamic>? args) => switch (kind) {
        ShellKind.seeker => null,
        ShellKind.stayOwner => StayOwnerTabs.tabForRoute(route, args),
        ShellKind.taxiDriver => TaxiDriverTabs.tabForRoute(route, args),
      };

  static TabConfigController get _tabs => TabConfigController.to;

  static StayLandingController? get _stays =>
      Get.isRegistered<StayLandingController>(tag: 'stays') ? Get.find<StayLandingController>(tag: 'stays') : null;

  static void _seekerCommonTap() => _stays?.filterResetTrigger.value++;

  static List<TabSlot> seekerSlots() => [
        TabSlot(
          index: AppTabs.home,
          label: _tabs.displayNameForIndex(AppTabs.home, 'Home'),
          image: '${_t3d}compass.png',
          rootTag: 'home',
          root: () => const HomeScreen(),
          active: () => _tabs.isActiveForIndex(AppTabs.home),
          onTap: (_) => _seekerCommonTap(),
        ),
        TabSlot(
          index: AppTabs.stays,
          label: _tabs.displayNameForIndex(AppTabs.stays, 'Stays'),
          image: '${_t3d}camping.png',
          activeColor: ListingPalette.forest.text,
          itemKey: TourKeys.homeStaysNavIcon,
          rootTag: 'stays',
          root: () => const StayLandingScreenV2(),
          active: () => _tabs.isActiveForIndex(AppTabs.stays),
          onTap: (wasSelected) {
            if (!wasSelected) _stays?.exploreRefreshTrigger.value++;
            _seekerCommonTap();
          },
          onLeave: () {
            if (Get.isRegistered<LocationController>()) Get.find<LocationController>().resetBrowsing();
          },
        ),
        TabSlot(
          index: AppTabs.trips,
          label: _tabs.displayNameForIndex(AppTabs.trips, 'Trips'),
          image: '${_t3d}luggage.png',
          center: true,
          rootTag: 'trips',
          root: () => const TripsDiscoveryScreen(),
          active: () => _tabs.isActiveForIndex(AppTabs.trips),
          onTap: (_) => _seekerCommonTap(),
        ),
        TabSlot(
          index: AppTabs.taxi,
          label: _tabs.displayNameForIndex(AppTabs.taxi, 'Taxi'),
          image: '${_t3d}taxi.png',
          activeColor: ListingPalette.coral.text,
          itemKey: TourKeys.homeTaxiNavIcon,
          rootTag: 'taxi',
          root: () => const TaxiListScreenV2(root: true),
          active: () => _tabs.isActiveForIndex(AppTabs.taxi),
          onTap: (_) {
            TaxiStatusSync.onTaxiTabTap();
            _seekerCommonTap();
          },
        ),
        TabSlots.profile(
          label: _tabs.displayNameForIndex(AppTabs.profile, 'Profile'),
          active: () => _tabs.isActiveForIndex(AppTabs.profile),
          onTapExtra: _seekerCommonTap,
        ),
      ];
}

abstract final class OwnerShellBindings {
  static void ensure(ShellKind kind) {
    switch (kind) {
      case ShellKind.seeker:
        SeekerHomeBindings.ensure();
      case ShellKind.stayOwner:
        StayOwnerBindings.ensure();
      case ShellKind.taxiDriver:
        TaxiDriverBindings.ensure();
    }
  }
}
