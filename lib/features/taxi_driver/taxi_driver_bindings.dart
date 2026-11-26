import 'package:get/get.dart';

import '../owner_core/plan/plan_card_state.dart';
import 'plan/taxi_home_plan_card.dart';
import 'plan/taxi_plan_copy.dart';
import 'home/taxi_driver_home_controller.dart';
import 'taxi_driver_session.dart';
import 'availability/taxi_availability_store.dart';
import '../taxi/requests/widgets/driver_bookings_section.dart';
import 'taxi_driver_deps.dart';

abstract final class TaxiDriverBindings {
  static void ensure() {
    TaxiDriverSession.register();
    if (!Get.isRegistered<TaxiDriverHomeController>()) Get.put(TaxiDriverHomeController());
    if (!Get.isRegistered<TaxiAvailabilityStore>()) Get.put(TaxiAvailabilityStore());
    // A5 bindings
    // end A5
    // A6 bindings
    TaxiDriverDeps.appBookings = () => const DriverBookingsSection();
    // end A6
    // A7 bindings
    // end A7
    // A8 bindings
    PlanCopies.taxi = const TaxiPlanCopy();
    TaxiDriverDeps.planCard = () => const TaxiHomePlanCard();
    // end A8
  }
}
