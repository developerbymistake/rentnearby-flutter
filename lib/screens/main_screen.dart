import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/plot_controller.dart';
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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navController;
  final _auth = Get.find<AuthController>();
  bool _isOffline = false;
  bool _gpsEnabled = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<ServiceStatus>? _gpsStatusSub;

  final _screens = const [ExploreScreen(), MyListingsScreen(), ExplorePlotsScreen(), MyPlotsScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    Get.put(ListingController());
    Get.put(PlotController());
    ever(_auth.tabIndex, (i) => setState(() => _currentIndex = i));
    _initConnectivity();
    _initGpsGate();
    _auth.refreshProfile();
  }

  Future<void> _initGpsGate() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _gpsEnabled = enabled);

    _gpsStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) return;
      setState(() => _gpsEnabled = status == ServiceStatus.enabled);
    });
  }

  Future<void> _recheckGps() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _gpsEnabled = enabled);
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      setState(() => _isOffline = results.every((r) => r == ConnectivityResult.none));
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() => _isOffline = results.every((r) => r == ConnectivityResult.none));
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _gpsStatusSub?.cancel();
    _navController.dispose();
    super.dispose();
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
                  onPressed: _recheckGps,
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Exit Bakhli?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
        content: const Text(
          'Are you sure you want to exit?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => SystemNavigator.pop(),
            child: const Text(
              'Exit',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          _showExitConfirmation();
        }
      },
      child: Stack(
        children: [
      Scaffold(
        body: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              height: _isOffline ? MediaQuery.of(context).padding.top + 36 : 0,
              color: const Color(0xFFC62828),
              child: Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 8),
                    Text('No internet connection',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
      if (!_gpsEnabled) _buildGpsGate(),
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
            _navItem(0, Iconsax.map, Iconsax.map5, 'Explore'),
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
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 0 && _currentIndex != 0) {
            Get.find<ListingController>().exploreRefreshTrigger.value++;
          }
          if (index == 2 && _currentIndex != 2) {
            Get.find<PlotController>().exploreRefreshTrigger.value++;
          }
          setState(() => _currentIndex = index);
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
