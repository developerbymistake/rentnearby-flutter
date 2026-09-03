import 'dart:async';
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
/// *live* (paid via credits) is a separate, later question — see
/// ListingController.goLive.
class ListingPermissionService {
  final ListingController _ctrl;
  final LocationController _location;

  ListingPermissionService(this._ctrl, this._location);

  Future<ListingPermissionResult> check() async {
    // A cold app-open resolves GPS/district over 1-2s — selectedDistrict is
    // briefly null then, same as a genuinely unsupported area. Only
    // districtUnavailable means "confirmed unsupported"; wait it out instead
    // of misreporting a still-loading district as unsupported.
    if (_location.selectedDistrict.value == null && !_location.districtUnavailable.value) {
      await _waitForDistrictResolution();
    }
    if (_location.selectedDistrict.value == null) return ListingNeedsDistrict();

    final config = Get.find<ConfigController>();
    await config.ensureLoaded();
    final cap = config.roomLimit.value;

    if (_ctrl.myListings.length >= cap) {
      return ListingLimitReached(cap: cap);
    }
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
