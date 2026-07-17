import 'package:get/get.dart';
import '../controllers/config_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';

sealed class ListingPermissionResult {}

class ListingAllowed extends ListingPermissionResult {}

class ListingNeedsDistrict extends ListingPermissionResult {}

class ListingLimitReached extends ListingPermissionResult {
  final int cap;
  ListingLimitReached({required this.cap});
}

/// The only question left at Add-Room time: has this user hit the flat,
/// admin-configured listing-creation cap from GET /config/listing-limits.
/// There is no more per-user free-vs-paid tier — everyone shares the same
/// cap — and no "upgrade plan to raise your cap" concept, so this collapses
/// to a 3-case result instead of the old 5-case one. Whether a listing is
/// *live* (paid via coins) is a separate, later question — see
/// ListingController.goLive.
class ListingPermissionService {
  final ListingController _ctrl;
  final LocationController _location;

  ListingPermissionService(this._ctrl, this._location);

  Future<ListingPermissionResult> check() async {
    if (_location.selectedDistrict.value == null) return ListingNeedsDistrict();

    final config = Get.find<ConfigController>();
    await config.ensureLoaded();
    final cap = config.roomLimit.value;

    if (_ctrl.myListings.length >= cap) {
      return ListingLimitReached(cap: cap);
    }
    return ListingAllowed();
  }
}
