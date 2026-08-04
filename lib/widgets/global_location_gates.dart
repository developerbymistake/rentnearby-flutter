import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_colors.dart';
import '../controllers/location_controller.dart';
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

  @override
  Widget build(BuildContext context) {
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
            Obx(() => locationCtrl.isOffline.value
                ? _buildOfflineGate()
                : const SizedBox.shrink()),
            Obx(() => !locationCtrl.isOffline.value && locationCtrl.districtUnavailable.value
                ? _buildDistrictGate(locationCtrl)
                : const SizedBox.shrink()),
            Obx(() => !locationCtrl.isOffline.value &&
                    (!locationCtrl.gpsEnabled.value || !locationCtrl.locationPermissionGranted.value)
                ? _buildGpsGate(locationCtrl)
                : const SizedBox.shrink()),
          ],
        );
      },
    );
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
                      ? 'Bakhli needs permission to access your location to show rooms near you. Please allow location access in Settings.'
                      : 'Bakhli uses your location to show rooms near you. Please enable GPS to continue.',
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
