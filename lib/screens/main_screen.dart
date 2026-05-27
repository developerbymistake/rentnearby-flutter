import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';
import '../repositories/listing_repository.dart';
import '../repositories/plot_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/gradient_button.dart';
import 'explore_screen.dart';
import 'explore_plots_screen.dart';
import 'my_listings_screen.dart';
import 'my_plots_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _auth = Get.find<AuthController>();
  late final LocationController _locationCtrl;

  final _screens = const [ExploreScreen(), MyListingsScreen(), ExplorePlotsScreen(), MyPlotsScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    Get.put(ListingRepository());
    Get.put(PlotRepository());
    Get.put(UserRepository());
    Get.put(ListingController());
    Get.put(PlotController());
    _locationCtrl = Get.put(LocationController());
    _auth.refreshProfile();
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

  Widget _buildDistrictGate() {
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
                  onPressed: () => _locationCtrl.refreshOnResume(),
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

  Widget _buildGpsGate() {
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
                  child: const Icon(Icons.location_off_rounded, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Location Required',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bakhli uses your location to show rooms near you. Please enable GPS to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                GradientButton(
                  label: 'Enable Location',
                  onPressed: () => Geolocator.openLocationSettings(),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _locationCtrl.recheckGps(),
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

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, size: 28, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              const Text(
                'Exit App?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to exit?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => SystemNavigator.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Exit',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_auth.tabIndex.value != 0) {
          _auth.tabIndex.value = 0;
        } else {
          _showExitConfirmation();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            body: Obx(() => IndexedStack(
              index: _auth.tabIndex.value,
              children: _screens,
            )),
            bottomNavigationBar: Obx(() => _buildBottomNav()),
          ),
          Obx(() => _locationCtrl.isOffline.value
              ? _buildOfflineGate()
              : const SizedBox.shrink()),
          Obx(() => !_locationCtrl.isOffline.value && _locationCtrl.districtUnavailable.value
              ? _buildDistrictGate()
              : const SizedBox.shrink()),
          Obx(() => !_locationCtrl.gpsEnabled.value
              ? _buildGpsGate()
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
        child: Row(
          children: [
            _navItem(0, Iconsax.map, Iconsax.map5, 'Rooms'),
            _navItem(1, Iconsax.building, Iconsax.building5, 'My Rooms'),
            _navItem(2, Iconsax.location, Iconsax.location5, 'Plots'),
            _navItem(3, Iconsax.document, Iconsax.document5, 'My Plots'),
            _navItem(4, Iconsax.user, Iconsax.user5, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _auth.tabIndex.value == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 0 && _auth.tabIndex.value != 0) {
            Get.find<ListingController>().exploreRefreshTrigger.value++;
          }
          if (index == 2 && _auth.tabIndex.value != 2) {
            Get.find<PlotController>().exploreRefreshTrigger.value++;
          }
          if (index == 4 && _auth.tabIndex.value != 4) _auth.profileTabTrigger.value++;
          Get.find<ListingController>().filterResetTrigger.value++;
          Get.find<PlotController>().filterResetTrigger.value++;
          _auth.tabIndex.value = index;
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? AppColors.primary : AppColors.textHint,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.textHint,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
