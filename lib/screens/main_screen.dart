import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_tabs.dart';
import '../controllers/agent_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/plot_controller.dart';
import '../controllers/report_controller.dart';
import '../repositories/agent_repository.dart';
import '../repositories/config_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/inquiry_repository.dart';
import '../repositories/listing_repository.dart';
import '../repositories/plot_repository.dart';
import '../repositories/service_catalog_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/wallet_repository.dart';
import '../controllers/config_controller.dart';
import '../controllers/inquiry_controller.dart';
import '../controllers/service_catalog_controller.dart';
import '../controllers/wallet_controller.dart';
import '../controllers/banner_controller.dart';
import '../controllers/chat_controller.dart';
import '../services/banner_hub_service.dart';
import '../services/chat_hub_service.dart';
import '../services/inquiry_hub_service.dart';
import '../services/notification_service.dart';
import '../services/wallet_hub_service.dart';
import '../widgets/district_banner_overlay.dart';
import '../widgets/gradient_button.dart';
import '../navigation/tab_router.dart';
import '../navigation/tab_keys.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final _auth = Get.find<AuthController>();
  late final LocationController _locationCtrl;
  late final BannerController _bannerCtrl;
  late final ChatController _chatCtrl;
  Worker? _bannerDistrictWorker;
  Worker? _digestTopicWorker;
  Worker? _tabLeaveWorker;
  int _previousTabIndex = AppTabs.home;

  final _screens = const [
    TabNavigator(tabId: AppTabs.home),
    TabNavigator(tabId: AppTabs.rooms),
    TabNavigator(tabId: AppTabs.plots),
    TabNavigator(tabId: AppTabs.services),
    TabNavigator(tabId: AppTabs.profile),
  ];

  @override
  void initState() {
    super.initState();
    Get.put(ConfigRepository());
    Get.put(ConfigController());
    Get.put(ListingRepository());
    Get.put(PlotRepository());
    Get.put(UserRepository());
    Get.put(WalletRepository());
    Get.put(WalletController());
    Get.put(WalletHubService());
    Get.put(ServiceCatalogRepository());
    Get.put(ServiceCatalogController());
    Get.put(InquiryRepository());
    Get.put(InquiryController());
    Get.put(InquiryHubService());
    Get.put(AgentRepository());
    // Checks "am I an agent" once per session in its own onInit() — see AgentController's doc
    // comment. Put after InquiryRepository/InquiryController since AgentRepository reuses their
    // same InquiryModel/InquiryDetailModel shapes (no hard dependency, just logical grouping).
    Get.put(AgentController());
    Get.put(NotificationRepository());
    // Fetches the Home bell's unread count once per session in its own onInit() (mirrors
    // AgentController.checkAgentStatus) — refreshed on resume below, not via a live push.
    Get.put(NotificationController());
    Get.put(ListingController());
    Get.put(PlotController());
    Get.put(ReportController());
    _locationCtrl = Get.put(LocationController());
    // HomeController.onInit() looks up LocationController — must be put after it.
    Get.put(HomeController());
    _bannerCtrl = Get.put(BannerController());
    Get.put(BannerHubService());
    _chatCtrl = Get.put(ChatController());
    Get.put(ChatHubService());
    // Persistent for the whole session (like BannerHubService below) — not scoped to any one
    // conversation screen. This is what makes ChatHub's own "always joins user_{id}" comment
    // actually true: without this, nothing joins that group until a chat screen has been
    // opened at least once, so the unread badge/new-message live updates were aspirational.
    ChatHubService.to.connect();
    // Same session-wide-connected shape as chat — unconditional, not district-gated. Delivers
    // live balance pushes for changes this device didn't itself initiate (admin credit/debit,
    // a Razorpay webhook fallback credit); locally-initiated spends already update instantly via
    // their own REST response regardless of this connection's state.
    WalletHubService.to.connect();
    // Deliberately NOT connected here, unlike Chat/Wallet above — Inquiry is a niche,
    // occasionally-visited feature (unlike chat/wallet, nothing outside the Inquiry
    // screens themselves reads from it), and the FCM half of the dual push pattern
    // (InquiryStatusPushWorkerService) already covers a backgrounded/killed app. Being
    // app-wide-connected meant every resume — including returning from the camera while
    // adding Room/Plot photos — triggered a 3rd concurrent hub reconnect for no benefit
    // most sessions never need. Connected lazily instead, from my_inquiries_screen.dart /
    // inquiry_detail_screen.dart's initState() the moment either is actually opened.
    _chatCtrl.loadConversations();
    WidgetsBinding.instance.addObserver(this);
    _bannerDistrictWorker = ever(_locationCtrl.selectedDistrict, (district) {
      if (district != null) {
        _bannerCtrl.checkBanner(district.id.toString());
        BannerHubService.to.connectForDistrict(district.id.toString());
      }
    });
    if (_locationCtrl.selectedDistrict.value != null) {
      final id = _locationCtrl.selectedDistrict.value!.id.toString();
      _bannerCtrl.checkBanner(id);
      BannerHubService.to.connectForDistrict(id);
    }
    _digestTopicWorker = ever(_locationCtrl.selectedDistrict, (district) {
      NotificationService.to.updateDistrictTopic(district?.id.toString());
    });
    if (_locationCtrl.selectedDistrict.value != null) {
      NotificationService.to.updateDistrictTopic(_locationCtrl.selectedDistrict.value!.id.toString());
    }
    _previousTabIndex = _auth.tabIndex.value;
    // A tab's own screen never pushes further routes onto its local Navigator
    // (all deep navigation goes through the global GetX navigator) — so any
    // route still on a tab's stack when we leave it is a stray open bottom
    // sheet (e.g. LocationSwitchSheet, a listing detail sheet). showDialog
    // defaults to the root navigator, so dialogs aren't affected by (or a
    // target of) this — only showModalBottomSheet-based UI is. IndexedStack
    // never disposes inactive tabs, so without this the sheet silently
    // reappears exactly as left when the user switches back. Reacting to
    // tabIndex itself (rather than patching every call site that can change
    // it — bottom nav taps, back-press, push notifications, Home screen CTAs)
    // means this stays correct even if a new tab-switch entry point is added
    // later.
    _tabLeaveWorker = ever<int>(_auth.tabIndex, (newIndex) {
      if (newIndex != _previousTabIndex) {
        final navState = tabKeys[_previousTabIndex].currentState;
        if (navState != null && navState.canPop()) {
          navState.popUntil((route) => route.isFirst);
        }
      }
      _previousTabIndex = newIndex;
    });
    _auth.refreshProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerDistrictWorker?.dispose();
    _digestTopicWorker?.dispose();
    _tabLeaveWorker?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final district = _locationCtrl.selectedDistrict.value;
      if (district != null) {
        BannerHubService.to.connectForDistrict(district.id.toString());
      }
      ChatHubService.to.connect();
      WalletHubService.to.connect();
      Get.find<NotificationController>().loadUnreadCount();
      // Chat badge's app-resume anchor — pushes may have been missed while backgrounded
      // (the hub reconnect above isn't guaranteed to fire if the connection quietly died).
      _chatCtrl.fetchUnreadCount();
      // Inquiry is intentionally not reconnected here — see the comment at its
      // Get.put()/initial-connect site above. It connects lazily instead, and
      // my_inquiries_screen.dart/inquiry_detail_screen.dart each implement their
      // own WidgetsBindingObserver + didChangeAppLifecycleState resume-reconnect
      // while they're the active screen, so this is covered without MainScreen
      // needing to know about Inquiry at all when neither screen is open.
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
        if (_auth.tabIndex.value != AppTabs.home) {
          _auth.tabIndex.value = AppTabs.home;
        } else {
          _showExitConfirmation();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            resizeToAvoidBottomInset: false,
            body: Obx(() => IndexedStack(
              index: _auth.tabIndex.value,
              children: _screens,
            )),
            bottomNavigationBar: Obx(() => _buildBottomNav()),
          ),
          Obx(() {
            final hasGate = _locationCtrl.isOffline.value ||
                            !_locationCtrl.gpsEnabled.value ||
                            _locationCtrl.districtUnavailable.value;
            if (hasGate) return const SizedBox.shrink();
            final banner = _bannerCtrl.activeBanner.value;
            if (banner == null) return const SizedBox.shrink();
            return DistrictBannerOverlay(
              banner: banner,
              onDismiss: () => _bannerCtrl.dismiss(banner.id),
            );
          }),
          Obx(() => _locationCtrl.isOffline.value
              ? _buildOfflineGate()
              : const SizedBox.shrink()),
          Obx(() => !_locationCtrl.isOffline.value && _locationCtrl.districtUnavailable.value
              ? _buildDistrictGate()
              : const SizedBox.shrink()),
          Obx(() => !_locationCtrl.gpsEnabled.value
              ? _buildGpsGate()
              : const SizedBox.shrink()),
          Obx(() => _locationCtrl.gpsEnabled.value &&
                  _locationCtrl.locationLoading.value &&
                  _locationCtrl.userLocation.value == null
              ? _buildLocationLoadingOverlay()
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildLocationLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 3),
                const SizedBox(height: 16),
                const Text(
                  'Getting your location...',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait a moment',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ),
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
            _navItem(AppTabs.home, Iconsax.home, Iconsax.home5, 'Home'),
            _navItem(AppTabs.rooms, Iconsax.map, Iconsax.map5, 'Rooms'),
            _navItem(AppTabs.plots, Iconsax.location, Iconsax.location5, 'Plots'),
            _navItem(AppTabs.services, Iconsax.briefcase, Iconsax.briefcase5, 'Services'),
            _navItem(AppTabs.profile, Iconsax.user, Iconsax.user5, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label, {int badgeCount = 0}) {
    final isActive = _auth.tabIndex.value == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == AppTabs.rooms && _auth.tabIndex.value != AppTabs.rooms) {
            Get.find<ListingController>().exploreRefreshTrigger.value++;
          }
          if (index == AppTabs.plots && _auth.tabIndex.value != AppTabs.plots) {
            Get.find<PlotController>().exploreRefreshTrigger.value++;
          }
          if (index == AppTabs.profile && _auth.tabIndex.value != AppTabs.profile) _auth.profileTabTrigger.value++;
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
              Stack(clipBehavior: Clip.none, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    color: isActive ? AppColors.primary : AppColors.textHint,
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6, top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
              ]),
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
