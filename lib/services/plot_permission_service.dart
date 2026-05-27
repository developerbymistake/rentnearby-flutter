import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';

sealed class PlotPermissionResult {}

class PlotAllowed extends PlotPermissionResult {}

class PlotNeedsDistrict extends PlotPermissionResult {}

class PlotNeedsName extends PlotPermissionResult {}

class PlotShowLimitDialog extends PlotPermissionResult {
  final int maxPlots;
  final bool hasPlan;
  PlotShowLimitDialog({required this.maxPlots, required this.hasPlan});
}

class PlotShowUpgradeSheet extends PlotPermissionResult {}

class PlotPermissionService {
  final PlotController _ctrl;
  final AuthController _auth;
  final LocationController _location;

  PlotPermissionService(this._ctrl, this._auth, this._location);

  Future<PlotPermissionResult> check() async {
    if (_location.selectedDistrict.value == null) return PlotNeedsDistrict();

    final name = _auth.user.value?.name?.trim() ?? '';
    if (name.isEmpty) return PlotNeedsName();

    final featureConfig = await _ctrl.getPlotPaymentFeatureConfig();
    final paymentEnabled = featureConfig['isEnabled'] as bool;
    final freeLimit = featureConfig['freeLimit'] as int;

    if (!paymentEnabled) {
      if (_ctrl.myPlots.length >= freeLimit) {
        return PlotShowLimitDialog(maxPlots: freeLimit, hasPlan: true);
      }
      return PlotAllowed();
    }

    final status = await _ctrl.getPlotMembershipStatus();
    final hasMembership = status != null && (status['hasMembership'] == true);

    if (hasMembership) {
      final maxPlots = (status['maxPlots'] as num?)?.toInt() ?? 0;
      if (_ctrl.myPlots.length >= maxPlots) {
        final planType = status['planType'] as String? ?? '';
        final plans = await _ctrl.getPlotPlans();
        final currentPlan =
            plans.firstWhereOrNull((p) => p['planType'] == planType);
        final isFree =
            currentPlan == null || (currentPlan['price'] as num? ?? 0) == 0;
        return isFree
            ? PlotShowUpgradeSheet()
            : PlotShowLimitDialog(maxPlots: maxPlots, hasPlan: true);
      }
    } else {
      final hasUsedFree = _auth.user.value?.hasUsedFreePlotPlan ?? false;
      final plans = await _ctrl.getPlotPlans();
      final freePlan =
          plans.firstWhereOrNull((p) => (p['price'] as num? ?? 0) == 0);
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
