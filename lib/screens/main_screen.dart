import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import 'explore_screen.dart';
import 'my_listings_screen.dart';
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final _screens = const [ExploreScreen(), MyListingsScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    Get.put(ListingController());
    ever(_auth.tabIndex, (i) => setState(() => _currentIndex = i));
    _initConnectivity();
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
    _navController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          // Go back to Explore tab instead of closing app
          setState(() => _currentIndex = 0);
        } else {
          // On Explore tab — exit app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
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
            _navItem(2, Iconsax.user, Iconsax.user5, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
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
