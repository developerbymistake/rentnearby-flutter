import 'dart:async';
import 'package:get/get.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plan_controller.dart';

sealed class ListingPermissionResult {}

class ListingAllowed extends ListingPermissionResult {}

class ListingNeedsDistrict extends ListingPermissionResult {}

class ListingLimitReached extends ListingPermissionResult {
  final int cap;
  ListingLimitReached({required this.cap});
}

class ListingPermissionService {
  final LocationController _location;

  ListingPermissionService(ListingController _, this._location);

  Future<ListingPermissionResult> check() async {
    // A cold app-open resolves GPS/district over 1-2s — selectedDistrict is
    // briefly null then, same as a genuinely unsupported area. Only
    // districtUnavailable means "confirmed unsupported"; wait it out instead
    // of misreporting a still-loading district as unsupported.
    if (_location.selectedDistrict.value == null && !_location.districtUnavailable.value) {
      await _waitForDistrictResolution();
    }
    if (_location.selectedDistrict.value == null) return ListingNeedsDistrict();

    final plans = Get.find<PlanController>();
    await plans.refreshPlan(force: true);
    final cap = plans.limits.listingLimit;
    if (plans.limits.used >= cap) return ListingLimitReached(cap: cap);
    return ListingAllowed();
  }

  Future<void> _waitForDistrictResolution() async {
    final completer = Completer<void>();
    late final Worker worker;
    worker = everAll([_location.selectedDistrict, _location.districtUnavailable], (_) {
      if (_location.selectedDistrict.value != null || _location.districtUnavailable.value) {
        if (!completer.isCompleted) completer.complete();
      }
    });
    await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    worker.dispose();
  }
}
