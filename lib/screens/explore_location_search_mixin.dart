import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../controllers/location_controller.dart';
import '../models/location_context.dart';
import '../models/place_result_model.dart';
import '../utils/app_toast.dart';
import '../widgets/location_search_sheet.dart';

/// Shared location-search behavior for the Explore Room and Plot screens.
///
/// Thin per-screen forwarder — all session state (the precise pin, its
/// label, the resolving flag, the pre-search snapshot, the generation
/// counter) lives on [LocationController] itself, fully shared between
/// Rooms and Plots, exactly like manual city-switch already is. This is
/// what makes searching a precise spot on one screen move the *other*
/// screen's camera/radius to that exact same spot too, not just the same
/// district. See `LocationController`'s "Location-search session API"
/// section for the actual logic.
mixin ExploreLocationSearchMixin<T extends StatefulWidget> on State<T> {
  LocationController get _locSearchCtrl => Get.find<LocationController>();

  LatLng get searchCenter => _locSearchCtrl.effectiveSearchCenter;
  bool get isSearchActive => _locSearchCtrl.searchPinOverride.value != null;
  String? get searchOverrideLabel => _locSearchCtrl.searchPinLabel.value;
  bool get searchResolving => _locSearchCtrl.searchResolving.value;

  /// Tap handler for the search toggle button.
  Future<void> onSearchToggleTap(BuildContext context) async {
    if (searchResolving) return; // guards double-tap during the async resolve
    if (isSearchActive) {
      _locSearchCtrl.endSearchOverride();
      return;
    }
    final picked = await LocationSearchSheet.show(context, bias: searchCenter);
    if (picked == null || !mounted) return;
    await _applyPickedPlace(picked);
  }

  Future<void> _applyPickedPlace(PlaceResult picked) async {
    final myGeneration = _locSearchCtrl.beginSearchResolve();
    try {
      final ctx = await _locSearchCtrl.resolveDistrictAt(
          picked.latLng.latitude, picked.latLng.longitude);
      if (!mounted || !_locSearchCtrl.isCurrentSearchGeneration(myGeneration)) return;
      final nearestCity = ctx.nearestCity;
      if (nearestCity == null) {
        _locSearchCtrl.searchResolving.value = false;
        AppToast.error('Could not determine a city for that location.');
        return;
      }
      _locSearchCtrl.beginSearchOverride(
          ctx.district, nearestCity, picked.latLng, picked.name);
    } on DistrictNotFoundException {
      if (!mounted || !_locSearchCtrl.isCurrentSearchGeneration(myGeneration)) return;
      _locSearchCtrl.searchResolving.value = false;
      AppToast.error("This area isn't in a serviceable location yet.");
    } catch (_) {
      if (!mounted || !_locSearchCtrl.isCurrentSearchGeneration(myGeneration)) return;
      _locSearchCtrl.searchResolving.value = false;
      AppToast.error('Could not search that location. Please try again.');
    }
  }
}
