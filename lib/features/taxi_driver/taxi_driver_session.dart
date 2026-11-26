import 'dart:async';

import 'package:get/get.dart';

import '../../config/shell_kind.dart';
import '../../controllers/auth_controller.dart';
import '../owner_core/data/owner_cache.dart';
import '../owner_core/session/owner_plan_sync.dart';
import '../owner_core/session/owner_push_sync.dart';
import '../owner_core/session/owner_session_hooks.dart';
import '../owner_core/session/shell_teardown.dart';
import 'taxi_driver_deps.dart';
import 'home/taxi_driver_home_controller.dart';
import 'hub/taxi_hub_controller.dart';
import '../../config/notification_types.dart';
import '../../services/taxi_ring_session.dart';
import '../taxi/requests/controllers/driver_app_bookings_controller.dart';
import 'notices/taxi_notice_copy.dart';
import 'calendar/taxi_calendar_controller.dart';
import 'calendar/taxi_upcoming_card.dart';
import 'availability/taxi_availability_api.dart';
import 'availability/taxi_availability_store.dart';

abstract final class TaxiDriverSession {
  static const String name = 'taxi_driver';

  static void register() {
    OwnerSessionHooks.register(name, (_, _) => TaxiDriverDeps.debugReset());
    OwnerSessionHooks.refreshHome = () => TaxiDriverDeps.refreshHome();
    OwnerPushSync.register(name, (type, args) {
      if (reloadsHome(type)) _homeDebounce.run(() => TaxiDriverHomeController.maybe?.reload());
    });
    OwnerPlanSync.register(name, onPlanChanged);
    ShellTeardown.register(ShellKind.taxiDriver, () {
      if (Get.isRegistered<TaxiDriverHomeController>()) Get.delete<TaxiDriverHomeController>(force: true);
    });
    // A5 session
    TaxiDriverDeps.refreshHome = () async => await TaxiDriverHomeController.maybe?.reload();
    // end A5
    // A6 session
    TaxiNoticeCopy.register();
    OwnerSessionHooks.register('${name}_work', (_, _) {
      TaxiRingSession.reset();
      TaxiNoticeCopy.debugPlan = null;
      TaxiNoticeCopy.debugCatalog = null;
    });
    OwnerPushSync.register('${name}_work', (type, args) {
      if (NotificationTypeKeys.isDriverTaxi(type)) DriverAppBookingsController.onPushIfRegistered();
    });
    // end A6
    // A7 session
    TaxiDriverDeps.upcomingCard = () => const TaxiUpcomingCard();
    TaxiDriverDeps.manualTripDays = (from, to) => TaxiCalendarController.maybe?.manualDays(from, to) ?? const [];
    OwnerSessionHooks.register('${name}_calendar', (_, _) {
      TaxiCalendarController.resetUsers();
      _homeDebounce.cancel();
    });
    OwnerPushSync.register('${name}_calendar', (type, args) {
      if (reloadsCalendar(type)) TaxiCalendarController.maybe?.refreshAll();
    });
    ShellTeardown.register(ShellKind.taxiDriver, () {
      ShellTeardown.deleteTagged<TaxiCalendarController>(TaxiCalendarController.tag);
      TaxiCalendarController.resetUsers();
    });
    // end A7
    // A8 session
    // end A8
    TaxiDriverDeps.isDayOff = (day) => TaxiAvailabilityStore.maybe?.isOff(day) ?? false;
    OwnerSessionHooks.register('${name}_availability', (_, _) => TaxiHourlyLimit.reset());
    OwnerPushSync.register('${name}_availability', (type, args) {
      if (reloadsCalendar(type)) TaxiAvailabilityStore.maybe?.refresh(force: true);
    });
    ShellTeardown.register(ShellKind.taxiDriver, () {
      if (Get.isRegistered<TaxiAvailabilityStore>()) Get.delete<TaxiAvailabilityStore>(force: true);
      TaxiHourlyLimit.reset();
    });
  }

  static final TaxiDebouncer _homeDebounce = TaxiDebouncer(const Duration(milliseconds: 500));

  static const Set<String> _calendarTypes = {
    NotificationTypeKeys.taxiBookingCancelled,
    NotificationTypeKeys.taxiBookingCancelledWire,
    NotificationTypeKeys.taxiTripEnded,
    NotificationTypeKeys.taxiTripEndedWire,
    NotificationTypeKeys.taxiBooked,
    NotificationTypeKeys.taxiBookedWire,
  };

  // Plan push types reach the screens through OwnerPlanSync only (D-01).
  static bool reloadsHome(String type) =>
      NotificationTypeKeys.ownerTaxi.contains(type) && !NotificationTypeKeys.invalidatesPlan.contains(type);

  static bool reloadsCalendar(String type) => _calendarTypes.contains(type);

  static void onPlanChanged() {
    final uid = Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;
    OwnerCache.remove(uid, OwnerCacheKeys.planCard);
    OwnerCache.remove(uid, OwnerCacheKeys.calUpcoming);
    OwnerCache.remove(uid, OwnerCacheKeys.daysOff);
    TaxiDriverHomeController.maybe?.reload(force: true);
    TaxiHubController.maybe?.reload(force: true);
    TaxiCalendarController.maybe?.refreshAll(force: true);
    TaxiAvailabilityStore.maybe?.refresh(force: true);
  }
}

class TaxiDebouncer {
  TaxiDebouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
