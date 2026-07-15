import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/app_constants.dart';
import '../controllers/location_controller.dart';
import '../models/city_model.dart';
import '../models/location_context.dart';
import '../models/place_result_model.dart';
import '../utils/app_toast.dart';
import '../widgets/location_search_sheet.dart';

/// Shared location-search behavior for the Explore Room and Plot screens.
///
/// Resolves a picked [PlaceResult] to a real district/city (reusing the same
/// point-in-polygon backend lookup GPS-driven location already relies on,
/// via [LocationController.resolveDistrictAt]) and pushes it through
/// [LocationController.setBrowsing] — the exact same call manual city-switch
/// makes — so each screen's own pre-existing `_browsingWorker` (an
/// `ever(browsingCity, ...)` listener) is the sole trigger for reload/camera
/// fit. This mixin never calls `_loadNearby()`/`_fitToRadius()` itself.
///
/// The precise searched coordinate is kept screen-local (`searchOverride`)
/// and still takes priority for the camera/radius center — only the
/// *district scoping* is unified with city-switch.
mixin ExploreLocationSearchMixin<T extends StatefulWidget> on State<T> {
  LocationController get _locSearchCtrl => Get.find<LocationController>();

  // ── Public surface (used by both explore screens) ─────────────────────────
  LatLng? searchOverride;
  String? searchOverrideLabel;
  bool searchResolving = false;

  bool get isSearchActive => searchOverride != null;

  /// Identical precedence to the screens' original per-screen `_searchCenter`
  /// getter: precise search pin > browsed city's coordinate > live GPS >
  /// GPS-nearest city fallback > hardcoded last-resort fallback.
  LatLng get searchCenter {
    if (searchOverride != null) return searchOverride!;
    final browsingCity = _locSearchCtrl.browsingCity.value;
    if (browsingCity?.latitude != null && browsingCity?.longitude != null) {
      return LatLng(browsingCity!.latitude!, browsingCity.longitude!);
    }
    final loc = _locSearchCtrl.userLocation.value;
    if (loc != null) return loc;
    final city = _locSearchCtrl.autoCity.value;
    if (city?.latitude != null && city?.longitude != null) {
      return LatLng(city!.latitude!, city.longitude!);
    }
    return const LatLng(AppConstants.fallbackLat, AppConstants.fallbackLng);
  }

  // ── Internal bookkeeping ───────────────────────────────────────────────────
  int _searchGeneration = 0;
  bool _applyingOwnBrowsingChange = false;
  bool _hasPreSearchSnapshot = false;
  DistrictModel? _snapshotDistrict;
  CityModel? _snapshotCity;
  Worker? _searchStaleWorker;

  void initExploreLocationSearch() {
    // Clears this screen's search pin/label if `browsingCity` changes from a
    // source OTHER than this screen's own resolve/cancel below — e.g. the
    // other tab searching/switching city, or LocationController.refreshOnResume's
    // reset. See _applyingOwnBrowsingChange for why this is race-safe.
    _searchStaleWorker = ever(_locSearchCtrl.browsingCity, (_) {
      if (_applyingOwnBrowsingChange) return;
      if (searchOverride == null) return;
      if (!mounted) return;
      setState(() {
        searchOverride = null;
        searchOverrideLabel = null;
      });
      _clearSnapshot();
    });
  }

  void disposeExploreLocationSearch() => _searchStaleWorker?.dispose();

  /// Tap handler for the search toggle button.
  Future<void> onSearchToggleTap(BuildContext context) async {
    if (searchResolving) return; // guards double-tap during the async resolve
    if (isSearchActive) {
      _cancelSearch();
      return;
    }
    final picked = await LocationSearchSheet.show(context, bias: searchCenter);
    if (picked == null || !mounted) return;
    await _applyPickedPlace(picked);
  }

  Future<void> _applyPickedPlace(PlaceResult picked) async {
    final myGeneration = ++_searchGeneration;
    setState(() => searchResolving = true);
    try {
      final ctx = await _locSearchCtrl.resolveDistrictAt(
          picked.latLng.latitude, picked.latLng.longitude);
      if (!mounted || myGeneration != _searchGeneration) return;
      final nearestCity = ctx.nearestCity;
      if (nearestCity == null) {
        setState(() => searchResolving = false);
        AppToast.error('Could not determine a city for that location.');
        return;
      }

      // Snapshot taken synchronously, immediately before mutating shared
      // state — reflects the true current browsing state even if something
      // else changed it during the network await above.
      _snapshotDistrict = _locSearchCtrl.browsingDistrict.value;
      _snapshotCity = _locSearchCtrl.browsingCity.value;
      _hasPreSearchSnapshot = true;

      _applyingOwnBrowsingChange = true;
      _locSearchCtrl.setBrowsing(ctx.district, nearestCity);
      _applyingOwnBrowsingChange = false;

      setState(() {
        searchOverride = picked.latLng;
        searchOverrideLabel = picked.name;
        searchResolving = false;
      });
    } on DistrictNotFoundException {
      if (!mounted || myGeneration != _searchGeneration) return;
      setState(() => searchResolving = false);
      AppToast.error("This area isn't in a serviceable location yet.");
    } catch (_) {
      if (!mounted || myGeneration != _searchGeneration) return;
      setState(() => searchResolving = false);
      AppToast.error('Could not search that location. Please try again.');
    }
  }

  void _cancelSearch() {
    _restoreSnapshot();
    setState(() {
      searchOverride = null;
      searchOverrideLabel = null;
    });
  }

  void _restoreSnapshot() {
    if (!_hasPreSearchSnapshot) return;
    _applyingOwnBrowsingChange = true;
    if (_snapshotDistrict == null || _snapshotCity == null) {
      _locSearchCtrl.resetBrowsing();
    } else {
      _locSearchCtrl.setBrowsing(_snapshotDistrict!, _snapshotCity!);
    }
    _applyingOwnBrowsingChange = false;
    _clearSnapshot();
  }

  void _clearSnapshot() {
    _hasPreSearchSnapshot = false;
    _snapshotDistrict = null;
    _snapshotCity = null;
  }

  /// "My location" FAB — unconditional exit back to the real location, no
  /// snapshot restore (recentering always means "show me my real location").
  void discardSearchForRecenter() {
    setState(() {
      searchOverride = null;
      searchOverrideLabel = null;
      searchResolving = false;
    });
    _clearSnapshot();
    _searchGeneration++;
  }

  /// Called from didChangeAppLifecycleState on resume, alongside
  /// LocationController.refreshOnResume() (which unconditionally resets
  /// browsing). Deliberately does NOT restore any snapshot — resume always
  /// means "back to my real location", same as recenter above. Safe/idempotent
  /// even if the stale-search worker above already cleared things, since that
  /// worker fires synchronously as part of refreshOnResume()'s own
  /// resetBrowsing() call.
  void discardSearchOnResume() {
    _searchGeneration++; // invalidate any resolve started before backgrounding
    if (searchResolving || searchOverride != null) {
      setState(() {
        searchResolving = false;
        searchOverride = null;
        searchOverrideLabel = null;
      });
    }
    _clearSnapshot();
  }
}
