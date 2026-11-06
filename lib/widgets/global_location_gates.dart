import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
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
    AppRoutes.tripStep,
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
  static bool _locationExempt(String? top) =>
      _tripRoutes.contains(top) || (_tripChildRoutes.contains(top) && TopRouteObserver.hasAny(_tripRoutes));

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

  Widget _buildOfflineGate() {
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 32),
                const Text(
                  'No Internet',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please check your internet connection. App will resume automatically when you\'re back online.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.6,
                  ),
                ),
                if (Get.isRegistered<AuthController>() && Get.find<AuthController>().postLoginRoute == AppRoutes.main) ...[
                const SizedBox(height: 32),
                TextButton(
                  onPressed: _openTrips,
                  child: Text(
                    TopRouteObserver.hasAny(_offlineRoutes) ? 'Back to my trip' : 'Open my trips (offline copy)',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictGate(LocationController locationCtrl) {
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_searching_rounded, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Area Not Supported Yet',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bakhli hasn\'t reached your area yet. Contact admin to register your district.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () => locationCtrl.refreshOnResume(force: true),
                  child: const Text(
                    'Check Again',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGpsGate(LocationController locationCtrl) {
    final permissionIssue = locationCtrl.gpsEnabled.value && !locationCtrl.locationPermissionGranted.value;
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    permissionIssue ? Icons.location_disabled_rounded : Icons.location_off_rounded,
                    color: Colors.white, size: 46,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  permissionIssue ? 'Location Permission Required' : 'Location Required',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  permissionIssue
                      ? 'Bakhli needs permission to access your location to show stays and taxis near you. Please allow location access in Settings.'
                      : 'Bakhli uses your location to show stays and taxis near you. Please enable GPS to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                GradientButton(
                  label: permissionIssue ? 'Open Settings' : 'Enable Location',
                  onPressed: () => permissionIssue
                      ? Geolocator.openAppSettings()
                      : Geolocator.openLocationSettings(),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => permissionIssue
                      ? locationCtrl.recheckLocationPermission()
                      : locationCtrl.recheckGps(),
                  child: const Text(
                    'Check Again',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
