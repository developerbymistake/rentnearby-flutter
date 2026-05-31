import 'package:get/get.dart';
import '../controllers/app_feature_controller.dart';
import '../controllers/auth_controller.dart';
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

class PlotNeedsPhoneVerification extends PlotPermissionResult {}

class PlotPermissionService {
  final PlotController _ctrl;
  final AuthController _auth;
  final LocationController _location;

  PlotPermissionService(this._ctrl, this._auth, this._location);

  Future<PlotPermissionResult> check() async {
    if (_location.selectedDistrict.value == null) return PlotNeedsDistrict();

    if (_auth.user.value?.isPhoneVerified != true) return PlotNeedsPhoneVerification();

    final _features      = Get.find<AppFeatureController>();
    final paymentEnabled = _features.isPlotPaymentEnabled.value;
    final freeLimit      = _features.plotPaymentFreeLimit.value;

    if (!paymentEnabled) {
      if (_ctrl.myPlots.length >= freeLimit) {
        return PlotShowLimitDialog(maxPlots: freeLimit, hasPlan: true);
      }
      return PlotAllowed();
    }

    final status = await _ctrl.getPlotMembershipStatus();
    final hasMembership = status != null && (status['hasMembership'] == true);

    if (hasMembership) {
      final maxPlots = (status!['maxPlotListings'] as num?)?.toInt() ?? 0;
      if (_ctrl.myPlots.length >= maxPlots) {
        final planType = status['planType'] as String? ?? '';
        final plans = await _ctrl.getPlotPlans();
        final currentPlan =
            plans.firstWhereOrNull((p) => p['planType'] == planType);
        final isFree =
            currentPlan == null || (currentPlan['originalPrice'] as num? ?? 0) == 0;
        return isFree
            ? PlotShowUpgradeSheet()
            : PlotShowLimitDialog(maxPlots: maxPlots, hasPlan: true);
      }
    } else {
      final hasUsedFree = _auth.user.value?.hasUsedFreePlotPlan ?? false;
      final plans = await _ctrl.getPlotPlans();
      final freePlan =
          plans.firstWhereOrNull((p) => (p['originalPrice'] as num? ?? 0) == 0);
      final limit = (freePlan?['plotLimit'] as num?)?.toInt() ?? 1;
      if (_ctrl.myPlots.length >= limit) {
        return hasUsedFree
            ? PlotShowUpgradeSheet()
            : PlotShowLimitDialog(maxPlots: limit, hasPlan: false);
      }
    }
    return PlotAllowed();
  }
}
