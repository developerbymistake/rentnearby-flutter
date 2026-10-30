import 'dart:async';
import 'package:get/get.dart';
import '../controllers/location_controller.dart';
import '../controllers/plan_controller.dart';
import '../controllers/plot_controller.dart';

sealed class PlotPermissionResult {}

class PlotAllowed extends PlotPermissionResult {}

class PlotNeedsDistrict extends PlotPermissionResult {}

class PlotPlanUnavailable extends PlotPermissionResult {}

class PlotLimitReached extends PlotPermissionResult {
  final int cap;
  PlotLimitReached({required this.cap});
}

class PlotPermissionService {
  final LocationController _location;

  PlotPermissionService(PlotController _, this._location);

  Future<PlotPermissionResult> check() async {
    // See ListingPermissionService.check()'s comment — same GPS/district
    // resolution race on a cold app-open.
    if (_location.selectedDistrict.value == null && !_location.districtUnavailable.value) {
      await _waitForDistrictResolution();
    }
    if (_location.selectedDistrict.value == null) return PlotNeedsDistrict();

    final plans = Get.find<PlanController>();
    await plans.refreshPlan(force: true);
    if (!plans.isLoaded) return PlotPlanUnavailable();
    final cap = plans.limits.listingLimit;
    if (plans.limits.used >= cap) return PlotLimitReached(cap: cap);
    return PlotAllowed();
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
