import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';

sealed class ListingPermissionResult {}

class ListingAllowed extends ListingPermissionResult {}

class ListingNeedsDistrict extends ListingPermissionResult {}

class ListingNeedsName extends ListingPermissionResult {}

class ListingShowLimitDialog extends ListingPermissionResult {
  final int maxRooms;
  final bool hasPlan;
  ListingShowLimitDialog({required this.maxRooms, required this.hasPlan});
}

class ListingShowUpgradeSheet extends ListingPermissionResult {}

class ListingNeedsPhoneVerification extends ListingPermissionResult {}

class ListingPermissionService {
  final ListingController _ctrl;
  final AuthController _auth;
  final LocationController _location;

  ListingPermissionService(this._ctrl, this._auth, this._location);

  Future<ListingPermissionResult> check() async {
    if (_location.selectedDistrict.value == null) return ListingNeedsDistrict();

    final name = _auth.user.value?.name?.trim() ?? '';
    if (name.isEmpty) return ListingNeedsName();

    if (_auth.user.value?.isPhoneVerified != true) return ListingNeedsPhoneVerification();

    final featureConfig = await _ctrl.getPaymentFeatureConfig();
    final paymentEnabled = featureConfig['isEnabled'] as bool;
    final freeLimit = featureConfig['freeLimit'] as int;

    if (!paymentEnabled) {
      if (_ctrl.myListings.length >= freeLimit) {
        return ListingShowLimitDialog(maxRooms: freeLimit, hasPlan: true);
      }
      return ListingAllowed();
    }

    final membership = await _ctrl.getMembershipStatus();
    if (membership != null && membership['hasMembership'] == true) {
      final maxRooms = (membership['maxRooms'] as num?)?.toInt() ?? 0;
      if (_ctrl.myListings.length >= maxRooms) {
        final planType = membership['planType'] as String? ?? '';
        final plans = await _ctrl.getPlans();
        final isFree = (plans[planType]?['price'] as num? ?? 0) == 0;
        return isFree
            ? ListingShowUpgradeSheet()
            : ListingShowLimitDialog(maxRooms: maxRooms, hasPlan: true);
      }
    } else {
      final hasUsedFree = _auth.user.value?.hasUsedFreePlan ?? false;
      final plans = await _ctrl.getPlans();
      final freePlan = plans.values
          .toList()
          .firstWhereOrNull((p) => (p['price'] as num? ?? 0) == 0);
      final limit = (freePlan?['roomLimit'] as num?)?.toInt() ?? 1;
      if (_ctrl.myListings.length >= limit) {
        return hasUsedFree
            ? ListingShowUpgradeSheet()
            : ListingShowLimitDialog(maxRooms: limit, hasPlan: false);
      }
    }
    return ListingAllowed();
  }
}
