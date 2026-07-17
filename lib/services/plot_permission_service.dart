import 'package:get/get.dart';
import '../controllers/config_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';

sealed class PlotPermissionResult {}

class PlotAllowed extends PlotPermissionResult {}

class PlotNeedsDistrict extends PlotPermissionResult {}

class PlotLimitReached extends PlotPermissionResult {
  final int cap;
  PlotLimitReached({required this.cap});
}

/// Mirror of ListingPermissionService for plots — see its doc comment.
class PlotPermissionService {
  final PlotController _ctrl;
  final LocationController _location;

  PlotPermissionService(this._ctrl, this._location);

  Future<PlotPermissionResult> check() async {
    if (_location.selectedDistrict.value == null) return PlotNeedsDistrict();

    final config = Get.find<ConfigController>();
    await config.ensureLoaded();
    final cap = config.plotLimit.value;

    if (_ctrl.myPlots.length >= cap) {
      return PlotLimitReached(cap: cap);
    }
    return PlotAllowed();
  }
}
