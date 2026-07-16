import 'package:get/get.dart';
import '../controllers/app_feature_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';

sealed class PlotPermissionResult {}

class PlotAllowed extends PlotPermissionResult {}

class PlotNeedsDistrict extends PlotPermissionResult {}

class PlotShowLimitDialog extends PlotPermissionResult {
  final int maxPlots;
  final bool hasPlan;
  PlotShowLimitDialog({required this.maxPlots, required this.hasPlan});
}

class PlotShowUpgradeSheet extends PlotPermissionResult {}

class PlotPermissionService {
  final PlotController _ctrl;
  final LocationController _location;

  PlotPermissionService(this._ctrl, this._location);

  Future<PlotPermissionResult> check() async {
    if (_location.selectedDistrict.value == null) return PlotNeedsDistrict();

    final features       = Get.find<AppFeatureController>();
    final paymentEnabled = features.isPlotPaymentEnabled.value;
    final freeLimit      = features.plotPaymentFreeLimit.value;

    if (!paymentEnabled) {
      if (_ctrl.myPlots.length >= freeLimit) {
        return PlotShowLimitDialog(maxPlots: freeLimit, hasPlan: true);
      }
      return PlotAllowed();
    }

    final membership    = _ctrl.plotMembership.value;
    final plans         = _ctrl.plotPlans.value;
    final hasMembership = membership != null && (membership['hasMembership'] == true);

    if (hasMembership) {
      final maxPlots = (membership['maxPlotListings'] as num?)?.toInt() ?? 0;
      if (_ctrl.myPlots.length >= maxPlots) {
        final planType    = membership['planType'] as String? ?? '';
        final currentPlan = plans.firstWhereOrNull((p) => p['planType'] == planType);
        final isFree      = currentPlan == null || (currentPlan['originalPrice'] as num? ?? 0) == 0;
        final hasHigherPlan = plans.any((p) =>
            (p['originalPrice'] as num? ?? 0) > 0 &&
            (p['plotLimit'] as num? ?? 0) > maxPlots);
        return hasHigherPlan
            ? PlotShowUpgradeSheet()
            : PlotShowLimitDialog(maxPlots: maxPlots, hasPlan: true);
      }
    } else {
      final freePlan    = plans.firstWhereOrNull((p) => (p['originalPrice'] as num? ?? 0) == 0);
      final limit       = (freePlan?['plotLimit'] as num?)?.toInt() ?? 1;
      if (_ctrl.myPlots.length >= limit) {
        final hasHigherPlan = plans.any((p) =>
            (p['originalPrice'] as num? ?? 0) > 0 &&
            (p['plotLimit'] as num? ?? 0) > _ctrl.myPlots.length);
        return hasHigherPlan
            ? PlotShowUpgradeSheet()
            : PlotShowLimitDialog(maxPlots: _ctrl.myPlots.length, hasPlan: true);
      }
    }
    return PlotAllowed();
  }
}
