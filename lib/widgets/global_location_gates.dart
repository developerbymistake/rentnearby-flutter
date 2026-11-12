import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../design/design.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/app_version_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../services/top_route_observer.dart';
import '../utils/update_decision.dart';
import 'force_update_screen.dart';
import 'gradient_button.dart';

/// Wraps the whole app (via GetMaterialApp's `builder:`) so the Offline/
/// District/GPS gates block every route, not just MainScreen's own Stack —
/// mirrors the exact gate UI/logic MainScreen used to render inline
/// (see main_screen.dart git history), now reused from one place.
class GlobalLocationGates extends StatelessWidget {
  const GlobalLocationGates({super.key, required this.child});

  final Widget child;

  // GetMaterialApp's `builder:` sits above the Navigator, so it does not
  // rebuild on Get.toNamed/offAllNamed route changes (only on things like
  // MediaQuery changes) — meaning a plain, non-reactive
  // Get.isRegistered<LocationController>() read here would stay frozen on
  // whatever it saw at the very first build (pre-auth, before MainScreen's
  // initState ever runs Get.put(LocationController())). MainScreen calls
  // notifyReady() right after that Get.put so this widget re-evaluates the
  // registration check at least once, right when it becomes true.
  static final ValueNotifier<int> _readyTick = ValueNotifier<int>(0);
  static void notifyReady() => _readyTick.value++;

  // Trip pages work from the saved copy, so no connection never blocks them.
  static const Set<String> _offlineRoutes = {
    AppRoutes.myTrips,
    AppRoutes.tripPlan,
    AppRoutes.tripSummary,
    AppRoutes.tripMap,
  };

  static const Set<String> _tripRoutes = {
    ..._offlineRoutes,
    AppRoutes.tripSpots,
    AppRoutes.tripStay,
    AppRoutes.tripTaxi,
    AppRoutes.tripReplies,
    AppRoutes.tripTaxiReplies,
    AppRoutes.taxiWays,
    AppRoutes.journeyPlan,
    AppRoutes.journeyRoad,
    AppRoutes.savedJourney,
  };

  static const Set<String> _tripChildRoutes = {
    AppRoutes.stayDetail,
    AppRoutes.taxiDetail,
    AppRoutes.chatConversation,
  };

  // A trip is planned for another place, so district and GPS never block it.
  static bool _locationExempt(String? top) {
    if (top == AppRoutes.main && Get.isRegistered<AuthController>() && Get.find<AuthController>().tabIndex.value == AppTabs.trips) {
      return true;
    }
    return _tripRoutes.contains(top) || (_tripChildRoutes.contains(top) && TopRouteObserver.hasAny(_tripRoutes));
  }

  @visibleForTesting
  static bool locationExempt(String? top) => _locationExempt(top);

  @override
  Widget build(BuildContext context) {
    final locationLayer = _buildLocationLayer();
    if (!Get.isRegistered<AppVersionController>()) return locationLayer;
    final versionCtrl = AppVersionController.to;
    return Obx(() {
      final forced = versionCtrl.gate.value == UpdateGateState.force;
      // The shielded child must keep index 0 so its state survives force toggles.
      return Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              excluding: forced,
              child: ExcludeFocus(
                excluding: forced,
                child: IgnorePointer(ignoring: forced, child: locationLayer),
              ),
            ),
          ),
          if (forced) const Positioned.fill(child: ForceUpdateScreen()),
        ],
      );
    });
  }

  Widget _buildLocationLayer() {
    return ValueListenableBuilder<int>(
      valueListenable: _readyTick,
      builder: (context, _, _) {
        if (!Get.isRegistered<LocationController>()) {
          return child;
        }
        final locationCtrl = Get.find<LocationController>();
        return Stack(
          children: [
            Positioned.fill(child: child),
            Obx(() => locationCtrl.isOffline.value && !_offlineRoutes.contains(TopRouteObserver.top.value)
                ? _buildOfflineGate()
                : const SizedBox.shrink()),
            Obx(() => !locationCtrl.isOffline.value &&
                    locationCtrl.districtUnavailable.value &&
                    !_locationExempt(TopRouteObserver.top.value)
                ? _buildDistrictGate(locationCtrl)
                : const SizedBox.shrink()),
            Obx(() => !locationCtrl.isOffline.value &&
                    (!locationCtrl.gpsEnabled.value || !locationCtrl.locationPermissionGranted.value) &&
                    !_locationExempt(TopRouteObserver.top.value)
                ? _buildGpsGate(locationCtrl)
                : const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  static void _openTrips() {
    if (TopRouteObserver.hasAny(_offlineRoutes)) {
      Get.until((r) => _offlineRoutes.contains(r.settings.name) || r.isFirst);
    } else {
      Get.toNamed(AppRoutes.myTrips);
    }
  }

  Widget _gateButton(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: FitnessAppTheme.body2.copyWith(fontWeight: FontWeight.w600, color: FitnessAppTheme.nearlyDarkBlue),
        ),
      );

  Widget _buildOfflineGate() {
    final showTrips =
        Get.isRegistered<AuthController>() && Get.find<AuthController>().postLoginRoute == AppRoutes.main;
    return Positioned.fill(
      child: GateStatusPage(
        asset: TravelIcon.map,
        title: 'No Internet',
        body: "Please check your internet connection. App will resume automatically when you're back online.",
        secondary: showTrips
            ? _gateButton(
                TopRouteObserver.hasAny(_offlineRoutes) ? 'Back to my trip' : 'Open my trips (offline copy)',
                _openTrips,
              )
            : null,
      ),
    );
  }

  Widget _buildDistrictGate(LocationController locationCtrl) {
    return Positioned.fill(
      child: GateStatusPage(
        asset: TravelIcon.route,
        title: 'Area Not Supported Yet',
        body: "Bakhli hasn't reached your area yet. Contact admin to register your district.",
        secondary: _gateButton('Check Again', () => locationCtrl.refreshOnResume(force: true)),
      ),
    );
  }

  Widget _buildGpsGate(LocationController locationCtrl) {
    final permissionIssue = locationCtrl.gpsEnabled.value && !locationCtrl.locationPermissionGranted.value;
    return Positioned.fill(
      child: GateStatusPage(
        asset: permissionIssue ? TravelIcon.checkout : TravelIcon.place,
        title: permissionIssue ? 'Location Permission Required' : 'Location Required',
        body: permissionIssue
            ? 'Bakhli needs permission to access your location to show stays and taxis near you. Please allow location access in Settings.'
            : 'Bakhli uses your location to show stays and taxis near you. Please enable GPS to continue.',
        primary: GradientButton(
          label: permissionIssue ? 'Open Settings' : 'Enable Location',
          onPressed: () => permissionIssue ? Geolocator.openAppSettings() : Geolocator.openLocationSettings(),
        ),
        secondary: _gateButton(
          'Check Again',
          () => permissionIssue ? locationCtrl.recheckLocationPermission() : locationCtrl.recheckGps(),
        ),
      ),
    );
  }
}
