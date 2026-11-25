import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../config/tab_slot.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/tab_config_controller.dart';
import '../owner_core/look/owner_look.dart';
import 'enquiries_tab/stay_enquiries_tab.dart';
import 'home/stay_owner_home_controller.dart';
import 'home/stay_owner_home_screen.dart';
import 'hub/stay_hub_screen.dart';
import 'jobs_tab/stay_jobs_tab.dart';
import 'strings/stay_shell_strings.dart';

abstract final class StayOwnerTabs {
  static const String art = TabSlots.art;
  static const Set<String> listingStatuses = {'PendingReview', 'Approved', 'Rejected'};

  static bool get stayExists {
    if (!Get.isRegistered<AuthController>()) return false;
    final auth = Get.find<AuthController>();
    return listingStatuses.contains(auth.user.value?.stayStatus);
  }

  static bool get jobsSlotActive {
    final tabs = TabConfigController.to;
    return tabs.isActive(AppTabKeys.jobs) && tabs.isActive(AppTabKeys.stays) && stayExists;
  }

  static List<TabSlot> slots() {
    final look = OwnerLook.stay;
    return [
      TabSlot(
        index: AppTabs.home,
        label: StayShellStrings.tabHome,
        image: '${art}compass.png',
        activeColor: look.active,
        rootTag: 'stay-home',
        root: () => const StayOwnerHomeScreen(),
        active: () => true,
      ),
      TabSlot(
        index: AppTabs.hub,
        label: StayShellStrings.tabMyStay,
        image: '${art}camping.png',
        activeColor: look.active,
        rootTag: 'stay-hub',
        root: () => const StayHubScreen(root: true),
        active: () => true,
      ),
      TabSlot(
        index: AppTabs.centre,
        label: StayShellStrings.tabEnquiries,
        image: '${art}clipboard.png',
        center: true,
        activeColor: look.active,
        rootTag: 'stay-enquiries-tab',
        root: () => const StayEnquiriesTab(),
        active: () => true,
        badge: () => StayOwnerHomeController.maybe?.centreBadge.value ?? 0,
        badgeColor: look.badge,
      ),
      TabSlot(
        index: AppTabs.fourth,
        label: StayShellStrings.tabJobs,
        image: '${art}briefcase.png',
        activeColor: look.active,
        rootTag: 'stay-jobs-tab',
        root: () => const StayJobsTab(),
        active: () => jobsSlotActive,
      ),
      TabSlots.profile(label: StayShellStrings.tabProfile),
    ];
  }

  static int? tabForRoute(String route, Map<String, dynamic>? args) {
    if (route == AppRoutes.myStays) return AppTabs.hub;
    if (route == AppRoutes.stayEnquiries) return AppTabs.centre;
    if (route == AppRoutes.myJobs) return jobsSlotActive ? AppTabs.fourth : null;
    return null;
  }
}
