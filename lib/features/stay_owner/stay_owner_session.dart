import 'package:get/get.dart';

import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';

import '../../config/notification_types.dart';
import '../../config/shell_kind.dart';
import '../owner_core/data/owner_cache.dart';
import '../owner_core/session/owner_plan_sync.dart';
import '../owner_core/session/owner_push_sync.dart';
import '../owner_core/session/owner_session_hooks.dart';
import '../owner_core/session/shell_teardown.dart';
import 'stay_owner_deps.dart';
import 'home/stay_owner_home_controller.dart';
import '../jobs/controllers/my_jobs_controller.dart';
import '../stay/enquiries/stay_enquiries_controller.dart';
import 'enquiries_tab/stay_quiet_week_banner.dart';
import 'jobs_tab/stay_jobs_tab.dart';
import 'notices/stay_notice_copy.dart';
import 'reminder/stay_reminder_row.dart';
import 'hub/stay_hub_controller.dart';
import 'calendar/stay_calendar_controller.dart';
import 'calendar/stay_upcoming_card.dart';
import 'plan_visible/stay_plan_visible_screen.dart';
import 'special_prices/stay_special_prices_controller.dart';

abstract final class StayOwnerSession {
  static const String name = 'stay_owner';

  static const Set<String> hubPushTypes = {
    NotificationTypeKeys.stayEditApprovedWire,
    NotificationTypeKeys.stayEditRejectedWire,
    NotificationTypeKeys.stayApprovedWire,
    NotificationTypeKeys.stayRejectedWire,
    NotificationTypeKeys.planLimitsChangedWire,
  };

  static String? _uid() => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;

  static void onStayDeleted() {
    ShellTeardown.deleteTagged<StayCalendarController>(StayCalendarController.tag);
    ShellTeardown.deleteTagged<StaySpecialPricesController>(StaySpecialPricesController.tag);
    ShellTeardown.deleteTagged<StayPlanVisibleController>(StayPlanVisibleController.tag);
    StayReminderState.reset();
    OwnerSessionHooks.refreshHome();
  }

  // Plan-scoped reads (limits, hidden rows, calendar window, summary) follow the new plan at once.
  static void onPlanChanged() {
    OwnerCache.removeListingScoped(_uid());
    StayOwnerHomeController.maybe?.reload();
    StayHubController.maybe?.reload();
    final cal = StayCalendarController.maybe;
    if (cal != null) {
      cal.clearCache();
      cal.reload();
    }
    if (Get.isRegistered<StaySpecialPricesController>(tag: StaySpecialPricesController.tag)) {
      Get.find<StaySpecialPricesController>(tag: StaySpecialPricesController.tag).fetch();
    }
    if (Get.isRegistered<StayPlanVisibleController>(tag: StayPlanVisibleController.tag)) {
      Get.find<StayPlanVisibleController>(tag: StayPlanVisibleController.tag).fetch();
    }
    if (Get.isRegistered<MyJobsController>(tag: StayJobsTab.tag)) Get.find<MyJobsController>(tag: StayJobsTab.tag).load();
  }

  static void register() {
    OwnerSessionHooks.register(name, (_, _) => StayOwnerDeps.debugReset());
    OwnerSessionHooks.refreshHome = () => StayOwnerDeps.refreshHome();
    OwnerPushSync.register(name, (type, args) {});
    ShellTeardown.register(ShellKind.stayOwner, () {
      if (Get.isRegistered<StayOwnerHomeController>()) Get.delete<StayOwnerHomeController>(force: true);
    });
    // A2 session
    ShellTeardown.register(ShellKind.stayOwner, () => ShellTeardown.deleteTagged<StayHubController>(StayHubController.tag));
    OwnerPushSync.register('${name}_hub', (type, args) {
      if (hubPushTypes.contains(type)) StayHubController.maybe?.reload();
    });
    StayOwnerDeps.refreshHome = () async => StayOwnerHomeController.maybe?.reload();
    StayOwnerDeps.refreshCalendar = () async => StayCalendarController.maybe?.reload();
    OwnerPlanSync.register(name, onPlanChanged);
    StayOwnerDeps.afterStayDeleted = onStayDeleted;
    StayOwnerDeps.openEditPrices = () {
      if (Get.isRegistered<AuthController>()) Get.find<AuthController>().openTab(AppTabs.hub, intent: const {'section': 'rooms'});
    };
    OwnerPushSync.register('${name}_home', (type, args) => StayOwnerHomeController.maybe?.reload());
    // end A2
    // A3 session
    StayOwnerDeps.reminderRow = () => const StayReminderRow();
    StayOwnerDeps.quietWeekBanner = () => const StayQuietWeekBanner();
    StayNoticeCopy.register();
    OwnerSessionHooks.register('${name}_work', (_, _) => StayReminderState.reset());
    ShellTeardown.register(ShellKind.stayOwner, () {
      ShellTeardown.deleteTagged<MyJobsController>(StayJobsTab.tag);
      if (Get.isRegistered<StayEnquiriesController>()) Get.delete<StayEnquiriesController>(force: true);
    });
    // end A3
    // A4 session
    StayOwnerDeps.upcomingCard = StayUpcomingCard.fromHome;
    OwnerSessionHooks.register('${name}_calendar', (_, _) => StaySpecialPriceMemory.reset());
    OwnerPushSync.register('${name}_calendar', (type, args) {
      StayCalendarController.maybe?.reload();
      if (Get.isRegistered<StaySpecialPricesController>(tag: StaySpecialPricesController.tag)) {
        Get.find<StaySpecialPricesController>(tag: StaySpecialPricesController.tag).fetch();
      }
    });
    ShellTeardown.register(ShellKind.stayOwner, () {
      ShellTeardown.deleteTagged<StayCalendarController>(StayCalendarController.tag);
      ShellTeardown.deleteTagged<StaySpecialPricesController>(StaySpecialPricesController.tag);
      ShellTeardown.deleteTagged<StayPlanVisibleController>(StayPlanVisibleController.tag);
    });
    // end A4
    // A8 session
    // end A8
  }
}
