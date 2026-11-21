import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../config/tab_slot.dart';
import '../owner_core/look/owner_look.dart';
import 'calendar/taxi_bookings_tab.dart';
import 'home/taxi_driver_home_controller.dart';
import 'home/taxi_driver_home_screen.dart';
import 'hub/taxi_hub_screen.dart';
import 'requests_tab/taxi_requests_tab.dart';
import 'strings/taxi_shell_strings.dart';

abstract final class TaxiDriverTabs {
  static const String art = TabSlots.art;

  static List<TabSlot> slots() {
    final look = OwnerLook.taxi;
    return [
      TabSlot(
        index: AppTabs.home,
        label: TaxiShellStrings.tabHome,
        image: '${art}compass.png',
        activeColor: look.active,
        rootTag: 'taxi-home',
        root: () => const TaxiDriverHomeScreen(),
        active: () => true,
      ),
      TabSlot(
        index: AppTabs.hub,
        label: TaxiShellStrings.tabMyTaxi,
        image: '${art}taxi.png',
        activeColor: look.active,
        rootTag: 'taxi-hub',
        root: () => const TaxiHubScreen(root: true),
        active: () => true,
      ),
      TabSlot(
        index: AppTabs.centre,
        label: TaxiShellStrings.tabRequests,
        image: '${art}bell.png',
        center: true,
        activeColor: look.active,
        rootTag: 'taxi-requests-tab',
        root: () => const TaxiRequestsTab(),
        active: () => true,
        badge: () => TaxiDriverHomeController.maybe?.centreBadge.value ?? 0,
        badgeColor: look.badge,
      ),
      TabSlot(
        index: AppTabs.fourth,
        label: TaxiShellStrings.tabBookings,
        image: '${art}calendar.png',
        activeColor: look.active,
        rootTag: 'taxi-bookings-tab',
        root: () => const TaxiBookingsTab(root: true),
        active: () => true,
      ),
      TabSlots.profile(label: TaxiShellStrings.tabProfile),
    ];
  }

  static int? tabForRoute(String route, Map<String, dynamic>? args) {
    if (route == AppRoutes.myTaxi) return AppTabs.hub;
    if (route == AppRoutes.taxiRequests || route == AppRoutes.tripLeads) return AppTabs.centre;
    if (route == AppRoutes.taxiBookings) return AppTabs.fourth;
    return null;
  }

  static String segmentFor(String route) => route == AppRoutes.tripLeads ? 'leads' : 'requests';
}
