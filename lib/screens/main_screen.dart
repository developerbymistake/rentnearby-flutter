import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../design/design.dart';
import '../design/extra/template_nav.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/app_version_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/report_controller.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/plan_repository.dart';
import '../controllers/config_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../controllers/plan_controller.dart';
import '../controllers/banner_controller.dart';
import '../controllers/chat_controller.dart';
import '../services/banner_hub_service.dart';
import '../services/chat_hub_service.dart';
import '../services/deep_link_service.dart';
import '../services/notification_hub_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/district_banner_overlay.dart';
import '../widgets/global_location_gates.dart';
import '../navigation/tab_router.dart';
import '../navigation/tab_keys.dart';
import '../navigation/tour_keys.dart';
import '../controllers/tour_controller.dart';
import '../features/stay/guest/stay_landing_controller.dart';
import '../features/stay/guest/stay_guest_controller.dart';
import '../features/taxi/guest/taxi_list_controller.dart';
import '../features/trip/controllers/my_trips_controller.dart';
import '../features/trip/widgets/trip_bar.dart';

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
  late final TabConfigController _tabConfigCtrl;
  Worker? _bannerDistrictWorker;
  Worker? _digestTopicWorker;
  Worker? _tabLeaveWorker;
  Worker? _tabConfigWorker;
  int _previousTabIndex = AppTabs.home;

  final _screens = const [
    TabNavigator(tabId: AppTabs.home),
    TabNavigator(tabId: AppTabs.stays),
    TabNavigator(tabId: AppTabs.trips),
    TabNavigator(tabId: AppTabs.taxi),
    TabNavigator(tabId: AppTabs.profile),
  ];

  @override
  void initState() {
    super.initState();
    _tabConfigCtrl = TabConfigController.to;
    Get.put(ConfigController());
    Get.put(PlanRepository());
    Get.put(PlanController());
    _locationCtrl = Get.put(LocationController());
    // GlobalLocationGates (main.dart's builder:) sits above the Navigator and
    // only re-evaluates Get.isRegistered<LocationController>() when nudged —
    // see its doc comment.
    GlobalLocationGates.notifyReady();
    // HomeController.onInit() looks up LocationController — must be put after it.
    Get.put(HomeController());
    Get.put(NotificationRepository());
    // Fetches the Home bell's unread count once per session in its own onInit() — refreshed on
    // resume below, not via a live push.
    Get.put(NotificationController());
    _chatCtrl = Get.put(ChatController());
    Get.put(ChatHubService());
    // Persistent for the whole session (like BannerHubService below) — not scoped to any one
    // conversation screen. This is what makes ChatHub's own "always joins user_{id}" comment
    // actually true: without this, nothing joins that group until a chat screen has been
    // opened at least once, so the unread badge/new-message live updates were aspirational.
    ChatHubService.to.connect();
    Get.put(NotificationHubService());
    Get.put(ReportController());
    Get.put(UserRepository());
    // Session-wide like Chat — delivers the generic NotificationReceived push that
    // updates the Home bell live, regardless of which tab is open.
    NotificationHubService.to.connect();
    _chatCtrl.loadConversations();
    _bannerCtrl = Get.put(BannerController());
    Get.put(BannerHubService());
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
        if (_previousTabIndex == AppTabs.stays) _locationCtrl.resetBrowsing();
        final navState = tabKeys[_previousTabIndex].currentState;
        if (navState != null && navState.canPop()) {
          navState.popUntil((route) => route.isFirst);
        }
      }
      _previousTabIndex = newIndex;
    });
    _tabConfigWorker = ever<int>(_tabConfigCtrl.version, (_) {
      if (!_tabConfigCtrl.isActiveForIndex(_auth.tabIndex.value)) _auth.switchToTab(AppTabs.home);
      final route = Get.currentRoute;
      if (AppRoutes.tabKeyForRoute(route) != null && !_auth.canOpenRoute(route)) {
        Get.until((r) => r.settings.name == AppRoutes.main);
      }
    });
    if (!_tabConfigCtrl.isActiveForIndex(_auth.tabIndex.value)) _auth.switchToTab(AppTabs.home);
    _auth.refreshProfile();
    // Last, deliberately — needs every controller any tour could reference
    // (LocationController, AuthController) already registered above.
    Get.put(TourController());
    // Replays any /go/{type}/{slug} deep link caught before main was ever reached this
    // session (see DeepLinkService's doc comment) — post-frame so this MainScreen build
    // has fully settled before a detail screen gets pushed on top of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.to.markMainReady();
      AppVersionController.to.maybeShowSoftPrompt();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerDistrictWorker?.dispose();
    _digestTopicWorker?.dispose();
    _tabLeaveWorker?.dispose();
    _tabConfigWorker?.dispose();
    // Permanent for the session (trip bar, Home card); the next login must not see these trips.
    if (Get.isRegistered<MyTripsController>()) Get.delete<MyTripsController>(force: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _locationCtrl.refreshOnResume();
      final district = _locationCtrl.selectedDistrict.value;
      if (district != null) {
        BannerHubService.to.connectForDistrict(district.id.toString());
      }
      ChatHubService.to.connect();
      NotificationHubService.to.connect();
      _tabConfigCtrl.load(forceRefresh: true);
      Get.find<ConfigController>().refreshPaymentFeature();
      Get.find<PlanController>().invalidate();
      Get.find<PlanController>().onAppResumed();
      Get.find<NotificationController>().loadUnreadCount();
      // Chat badge's app-resume anchor — pushes may have been missed while backgrounded
      // (the hub reconnect above isn't guaranteed to fire if the connection quietly died).
      _chatCtrl.fetchUnreadCount();
      // Tour re-attempt anchor for app resume — Future.delayed timers inside
      // TourController's bounded retry (_searchForReadyStep) keep firing even
      // while the app is backgrounded (e.g. during a native location-permission
      // dialog), so its ~2s retry budget can silently exhaust without a single
      // frame ever being produced, wasting the only attempt for nothing.
      // attemptShowTourForCurrentTab() is fully self-validating (tourInProgress,
      // seen-flag, hasActiveGate, its own generation bump) so it's safe to call
      // unconditionally here, same as every other call in this block.
      Get.find<TourController>().attemptShowTourForCurrentTab();
    } else if (state == AppLifecycleState.paused) {
      _locationCtrl.appPaused();
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: DesignColors.surface,
            borderRadius: CardRadius.hero,
            boxShadow: ShadowTokens.elev3,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: KitTone.rose.gradient,
                    boxShadow: ShadowTokens.glow(KitTone.rose.glow),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 32, color: DesignColors.onPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Exit App?',
                  style: TypeTokens.style(18, FontWeight.w700, color: DesignColors.textStrong),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to exit?',
                  textAlign: TextAlign.center,
                  style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Cancel',
                        neutral: true,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Exit',
                        tone: KitTone.rose,
                        onPressed: () => SystemNavigator.pop(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        // This is the app's only back-handling (tabs live under one
        // IndexedStack, none independently poppable) — block it outright
        // while a logout is in flight so the user can't tab-switch away
        // from (and lose sight of) the non-dismissible logout overlay.
        if (_auth.isLoggingOut.value) return;
        if (Get.isRegistered<StayGuestController>() && Get.find<StayGuestController>().isLoadingNearest.value) {
          return;
        }
        final tabNav = tabKeys[_auth.tabIndex.value].currentState;
        if (tabNav != null && tabNav.canPop()) {
          tabNav.maybePop();
          return;
        }
        if (_auth.tabIndex.value != AppTabs.home) {
          _auth.switchToTab(AppTabs.home);
        } else {
          _showExitConfirmation();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            resizeToAvoidBottomInset: false,
            extendBody: true,
            body: Obx(() => IndexedStack(
              index: _auth.tabIndex.value,
              children: _screens,
            )),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => _locationCtrl.hasActiveGate || _auth.isLoggingOut.value
                    ? const SizedBox.shrink()
                    : Transform.translate(offset: const Offset(0, 38), child: const TripBar())),
                Obx(() => _buildBottomNav()),
              ],
            ),
          ),
          Obx(() {
            if (_locationCtrl.hasActiveGate) return const SizedBox.shrink();
            final banner = _bannerCtrl.activeBanner.value;
            if (banner == null) return const SizedBox.shrink();
            return DistrictBannerOverlay(
              banner: banner,
              onDismiss: () => _bannerCtrl.dismiss(banner.id),
            );
          }),
          Obx(() => _locationCtrl.gpsEnabled.value &&
                  _locationCtrl.locationPermissionGranted.value &&
                  _locationCtrl.locationLoading.value &&
                  _locationCtrl.userLocation.value == null
              ? _buildLocationLoadingOverlay()
              : const SizedBox.shrink()),
          // Sits above the Scaffold's body AND its bottomNavigationBar (both
          // are children of this same top-level Stack), so it blocks tab
          // switching too — a body-level overlay inside one tab screen can't
          // cover a sibling bottomNavigationBar living in a different
          // Scaffold. Non-dismissible by construction: a plain painted
          // overlay, not a Dialog/route push, so there's no barrier-tap or
          // Navigator entry to dismiss. System back is separately blocked by
          // this screen's own root PopScope while isLoggingOut is true.
          Obx(() => _auth.isLoggingOut.value
              ? AppLoadingOverlay.stackChild(message: 'Logging out...')
              : const SizedBox.shrink()),
          // Same non-dismissible, tab-blocking overlay pattern as logout above —
          // covers the Scaffold's body AND bottomNavigationBar since both are
          // siblings in this Stack, so the user can't switch tabs mid-search.
          Obx(() {
            // StayGuestController is lazy and makes no call on put; .to registers it so this Obx subscribes.
            final stayLoading = StayGuestController.to.isLoadingNearest.value;
            if (!stayLoading) return const SizedBox.shrink();
            return AppLoadingOverlay.stackChild(message: 'Finding nearest stays...');
          }),
        ],
      ),
    );
  }

  Widget _buildLocationLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: DesignColors.scrim,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: const BoxDecoration(
              color: DesignColors.surface,
              borderRadius: CardRadius.hero,
              boxShadow: ShadowTokens.elev3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KitDots(color: DesignColors.primary, size: 9),
                const SizedBox(height: 16),
                Text(
                  'Getting your location...',
                  style: TypeTokens.style(16, FontWeight.w600, color: DesignColors.textStrong),
                ),
                const SizedBox(height: 4),
                Text('Please wait a moment', style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    const fit = 'assets/images/design/fitness_app/';
    const t3d = 'assets/images/design/travel3d/';
    return TemplateBottomBar(
      bottomInset: bottomInset,
      selectedIndex: _auth.tabIndex.value,
      onTap: _onNavTap,
      items: [
        TemplateNavItem(
            index: AppTabs.home,
            image: '${fit}tab_1.png',
            selectedImage: '${fit}tab_1s.png',
            label: _tabConfigCtrl.displayNameForIndex(AppTabs.home, 'Home')),
        if (_tabConfigCtrl.isActive(AppTabKeys.stays))
          TemplateNavItem(
              index: AppTabs.stays,
              image: '${t3d}hotel.png',
              itemKey: TourKeys.homeStaysNavIcon,
              label: _tabConfigCtrl.displayNameForIndex(AppTabs.stays, 'Stays')),
        TemplateNavItem(
            index: AppTabs.trips,
            image: '${t3d}compass.png',
            center: true,
            label: _tabConfigCtrl.displayNameForIndex(AppTabs.trips, 'Trips')),
        if (_tabConfigCtrl.isActive(AppTabKeys.taxi))
          TemplateNavItem(
              index: AppTabs.taxi,
              image: '${t3d}taxi.png',
              itemKey: TourKeys.homeTaxiNavIcon,
              label: _tabConfigCtrl.displayNameForIndex(AppTabs.taxi, 'Taxi')),
        TemplateNavItem(
            index: AppTabs.profile,
            image: '${fit}tab_4.png',
            selectedImage: '${fit}tab_4s.png',
            itemKey: TourKeys.homeProfileNavIcon,
            label: _tabConfigCtrl.displayNameForIndex(AppTabs.profile, 'Profile')),
      ],
    );
  }

  void _onNavTap(int index) {
    final stays = Get.isRegistered<StayLandingController>(tag: 'stays')
        ? Get.find<StayLandingController>(tag: 'stays')
        : null;
    if (index == AppTabs.stays && _auth.tabIndex.value != AppTabs.stays) {
      stays?.exploreRefreshTrigger.value++;
    }
    if (index == AppTabs.taxi && Get.isRegistered<TaxiListController>(tag: TaxiListController.tag)) {
      Get.find<TaxiListController>(tag: TaxiListController.tag).refreshIfStale();
    }
    if (index == AppTabs.profile && _auth.tabIndex.value != AppTabs.profile) _auth.profileTabTrigger.value++;
    stays?.filterResetTrigger.value++;
    _auth.switchToTab(index);
  }
}
