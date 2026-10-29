import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_shadows.dart';
import '../config/module_palette.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../models/browse_item.dart';
import '../config/app_tabs.dart';
import '../navigation/tour_keys.dart';
import '../features/jobs/controllers/my_jobs_controller.dart';
import '../features/jobs/jobs_colors.dart';
import '../features/stay/setup/stay_flow.dart';
import '../features/stay/setup/stay_option_sets.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../features/taxi/setup/taxi_flow.dart';
import '../features/taxi/taxi_option_sets.dart';
import '../services/add_listing_flow.dart';
import '../utils/app_toast.dart';
import '../widgets/home_owner_carousel.dart';
import '../widgets/home_stay_rail_card.dart';
import '../widgets/home_taxi_rail_card.dart';
import '../widgets/icon_motion.dart';
import '../widgets/listing_grid_card.dart';
import '../widgets/nearby_item_row.dart';

const _kInstagramGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();
  final _tabs = Get.find<TabConfigController>();

  // Same "try the app-scheme deep link, fall back to the web URL" idiom as
  // ProfileScreen._rateApp — instagram:// opens the app directly to the profile if it's
  // installed; a failed launchUrl (app not installed / scheme unhandled) falls back to the
  // plain https:// profile page in a browser.
  Future<void> _openInstagram() async {
    final appUri = Uri.parse('instagram://user?username=${AppConstants.instagramUsername}');
    if (!await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse('https://www.instagram.com/${AppConstants.instagramUsername}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _home.reloadDistrict,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: 24 + AppInsets.bottomViewPadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(context),
              const SizedBox(height: 16),
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                from: 14,
                child: KeyedSubtree(
                  key: TourKeys.homeManageListingsCard,
                  child: const HomeOwnerCarousel(),
                ),
              ),
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                delay: const Duration(milliseconds: 120),
                from: 14,
                child: _buildOwnerQuickActions(),
              ),
              const SizedBox(height: 15),
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                delay: const Duration(milliseconds: 180),
                from: 14,
                child: _buildInstagramCard(),
              ),
              const SizedBox(height: 15),
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                delay: const Duration(milliseconds: 220),
                from: 14,
                child: _buildListingsSections(),
              ),
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                delay: const Duration(milliseconds: 260),
                from: 14,
                child: _buildRecentlyAddedSection(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero: greeting + notification bell + district-scoped stat cards ────────

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        AppInsets.topViewPadding(context) + 14,
        20,
        22,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Obx(() {
              final name = _auth.profileName.value;
              final firstName = name.trim().isNotEmpty
                  ? name.trim().split(' ').first
                  : 'there';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $firstName 👋',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Let's find your perfect space",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(width: 12),
          _buildHeaderIcons(),
        ],
      ),
    );
  }

  Widget _buildHeaderIcons() {
    return Row(
      key: TourKeys.homeActionMenu,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headerIconButton(
          icon: Iconsax.notification,
          unreadCount: Get.find<NotificationController>().unreadCount,
          onTap: () => Get.toNamed(AppRoutes.notifications),
        ),
        const SizedBox(width: 10),
        _headerIconButton(
          icon: Iconsax.message,
          unreadCount: Get.find<ChatController>().unreadCount,
          onTap: () => Get.toNamed(AppRoutes.chatsList),
        ),
      ],
    );
  }

  // Solid white circle (was translucent-on-gradient) so the icon glyph reads
  // as AppColors.primary instead of white — badge Positioned/Obx logic below
  // is untouched, still the real unread count, not simplified to a dot.
  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
    RxInt? unreadCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: AppShadows.premium(
                Colors.black,
                alpha: 0.12,
                blur: 8,
                offset: const Offset(0, 3),
              ),
            ),
            child: Icon(icon, color: AppColors.primary, size: 17),
          ),
          if (unreadCount != null)
            Positioned(
              top: -4,
              right: -4,
              child: Obx(() {
                final count = unreadCount.value;
                if (count <= 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  // ── Near-you rails: Rooms, Plots, Stays, Taxis ─────────────────────────────

  Widget _buildListingsSections() {
    return Obx(() {
      final rails = <Widget>[
        if (_tabs.isRoomsActive)
          _buildRail(
            title: 'Rooms for Rent near you',
            tab: AppTabs.rooms,
            section: HomeSectionKeys.rooms,
            palette: ModulePalette.rooms,
            loading: _home.roomsLoading.value,
            isEmpty: _home.recentRooms.isEmpty,
            rail: () => _buildRoomsRail(_home.recentRooms),
          ),
        if (_tabs.isPlotsActive)
          _buildRail(
            title: 'Plots for Sale near you',
            tab: AppTabs.plots,
            section: HomeSectionKeys.plots,
            palette: ModulePalette.plots,
            loading: _home.plotsLoading.value,
            isEmpty: _home.recentPlots.isEmpty,
            rail: () => _buildPlotsRail(_home.recentPlots),
          ),
        if (_tabs.isStaysActive)
          _buildRail(
            title: 'Stays near you',
            tab: AppTabs.stays,
            section: HomeSectionKeys.stays,
            palette: ModulePalette.stays,
            loading: _home.staysLoading.value,
            isEmpty: _home.stays.isEmpty,
            rail: () => _buildStaysRail(_home.stays),
          ),
        if (_tabs.isTaxiActive)
          _buildRail(
            title: 'Taxis near you',
            tab: AppTabs.taxi,
            section: HomeSectionKeys.taxis,
            palette: ModulePalette.taxi,
            loading: _home.taxisLoading.value,
            isEmpty: _home.taxis.isEmpty,
            rail: () => _buildTaxisRail(_home.taxis),
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rail in rails)
            Padding(padding: const EdgeInsets.only(bottom: 15), child: rail),
        ],
      );
    });
  }

  Widget _buildStaysRail(List<HomeStayModel> items) {
    if (items.isEmpty) {
      return _emptyRailMessage('No stays listed here yet.', palette: ModulePalette.stays);
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => HomeStayRailCard(stay: items[i]),
    );
  }

  Widget _buildTaxisRail(List<TaxiBrowseItem> items) {
    if (items.isEmpty) {
      return _emptyRailMessage('No taxis listed here yet.', palette: ModulePalette.taxi, icon: Iconsax.car);
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => HomeTaxiRailCard(taxi: items[i]),
    );
  }

  Widget _buildRail({
    required String title,
    required int tab,
    required String section,
    required ModulePalette palette,
    required bool loading,
    required bool isEmpty,
    required Widget Function() rail,
  }) {
    final failed = _home.failedSections.contains(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => _auth.switchToTab(tab),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          SizedBox(height: ListingGridCard.height, child: _buildListingShimmerRail())
        else if (failed)
          _railErrorMessage(palette, () => _home.reloadSections({section}))
        else if (isEmpty)
          rail()
        else
          SizedBox(height: ListingGridCard.height, child: rail()),
      ],
    );
  }

  Widget _buildRoomsRail(List<HomeRoomModel> items) {
    if (items.isEmpty) {
      return _emptyRailMessage('No rooms listed here yet.');
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final r = items[i];
        final item = BrowseItem.room(
          id: r.id,
          userId: r.userId,
          thumbnailUrl: r.thumbnailUrl,
          type: r.roomTypeName,
          furnishedStatus: r.furnishedStatus,
          isAc: r.isAc,
          priceMonthly: r.priceMonthly,
          city: r.cityName,
          district: r.districtName,
        );
        return SizedBox(
          width: 160,
          child: ListingGridCard(
            thumbnailUrl: item.thumbnailUrl,
            tagLabel: item.tagLabel,
            title: item.title,
            locationLabel: item.locationLabel,
            facts: item.facts,
            priceCaption: item.priceCaption,
            priceValue: item.priceValue,
            priceUnit: item.priceUnit,
            isPlot: false,
            onViewDetails: () =>
                Get.toNamed(AppRoutes.listingDetail, arguments: {'id': r.id}),
          ),
        );
      },
    );
  }

  Widget _buildPlotsRail(List<HomePlotModel> items) {
    if (items.isEmpty) {
      return _emptyRailMessage(
        'No plots listed here yet.',
        palette: ModulePalette.plots,
        icon: Icons.landscape_rounded,
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final p = items[i];
        final item = BrowseItem.plot(
          id: p.id,
          userId: p.userId,
          thumbnailUrl: p.thumbnailUrl,
          type: p.plotTypeName,
          areaValue: p.areaValue,
          areaUnit: p.areaUnit,
          city: p.cityName,
          district: p.districtName,
        );
        return SizedBox(
          width: 160,
          child: ListingGridCard(
            thumbnailUrl: item.thumbnailUrl,
            tagLabel: item.tagLabel,
            title: item.title,
            locationLabel: item.locationLabel,
            facts: item.facts,
            priceCaption: item.priceCaption,
            priceValue: item.priceValue,
            priceUnit: item.priceUnit,
            isPlot: true,
            onViewDetails: () =>
                Get.toNamed(AppRoutes.plotDetail, arguments: {'id': p.id}),
          ),
        );
      },
    );
  }

  Widget _buildListingShimmerRail() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _emptyRailMessage(
    String text, {
    ModulePalette palette = ModulePalette.rooms,
    IconData icon = Icons.home_rounded,
  }) =>
      _railMessage(
        title: 'Nothing here yet',
        text: text,
        palette: palette,
        icon: icon,
        watermark: Icons.search_rounded,
      );

  Widget _railErrorMessage(ModulePalette palette, VoidCallback onRetry) => _railMessage(
        title: "Couldn't load",
        text: 'Tap to retry',
        palette: palette,
        icon: Icons.refresh_rounded,
        watermark: Icons.cloud_off_rounded,
        onTap: onRetry,
      );

  Widget _railMessage({
    required String title,
    required String text,
    required ModulePalette palette,
    required IconData icon,
    required IconData watermark,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.premium(
          palette.accent,
          alpha: 0.06,
          blur: 16,
          offset: const Offset(0, 6),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -8,
            bottom: -12,
            child: Icon(
              watermark,
              size: 60,
              color: palette.accentLight.withValues(alpha: 0.08),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: palette.accentLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    ),
  );

  // ── Owner quick actions ─────────────────────────────────────────────────

  Future<void> _postJob() async {
    if (_auth.user.value?.stayStatus != 'Approved') {
      AppToast.info('Stay must be live first');
      return;
    }
    final result = await Get.toNamed(AppRoutes.postJob);
    if (result == true) MyJobsController.invalidateList();
  }

  Widget _buildOwnerQuickActions() {
    return Obx(() {
      final rooms = _auth.roomsEnabled;
      final plots = _auth.plotsEnabled;
      final stays = _auth.staysEnabled;
      final taxis = _auth.taxisEnabled;
      final jobs = _auth.jobsEnabled;
      final checking = AddListingFlow.checking.value;
      final tiles = <Widget>[
        if (rooms)
          KeyedSubtree(
            key: TourKeys.homeQuickActionAddRoom,
            child: _ownerQuickActionTile(
              icon: Icons.add_rounded,
              gradient: AppColors.primaryGradient,
              label: 'Add Room',
              motion: IconMotionStyle.pulse,
              isLoading: checking == true,
              onTap: checking != null ? null : () => AddListingFlow.start(true),
            ),
          ),
        if (plots)
          KeyedSubtree(
            key: TourKeys.homeQuickActionAddPlot,
            child: _ownerQuickActionTile(
              icon: Icons.add_rounded,
              gradient: AppColors.plotGradient,
              label: 'Add Plot',
              motion: IconMotionStyle.pulse,
              isLoading: checking == false,
              onTap: checking != null ? null : () => AddListingFlow.start(false),
            ),
          ),
        if (stays)
          KeyedSubtree(
            key: TourKeys.homeQuickActionAddStay,
            child: _ownerQuickActionTile(
              icon: Icons.add_rounded,
              gradient: StayColors.gradient,
              label: 'Add Stay',
              motion: IconMotionStyle.pulse,
              compact: true,
              onTap: StayFlow.start,
            ),
          ),
        if (taxis)
          KeyedSubtree(
            key: TourKeys.homeQuickActionAddTaxi,
            child: _ownerQuickActionTile(
              icon: Icons.add_rounded,
              gradient: TaxiColors.gradient,
              label: 'Add Taxi',
              motion: IconMotionStyle.pulse,
              onTap: () => TaxiFlow.start(),
            ),
          ),
        if (rooms || plots || stays || taxis)
          KeyedSubtree(
            key: TourKeys.homeQuickActionLeads,
            child: _ownerQuickActionTile(
              icon: Icons.bar_chart_rounded,
              gradient: AppColors.warningGradient,
              label: stays ? 'My Stays' : 'My Listings',
              motion: IconMotionStyle.grow,
              compact: stays,
              onTap: () => Get.toNamed(
                rooms
                    ? AppRoutes.myListings
                    : plots
                        ? AppRoutes.myPlots
                        : stays
                            ? AppRoutes.myStays
                            : AppRoutes.myTaxi,
              ),
            ),
          ),
        if (jobs) ...[
          _ownerQuickActionTile(
            icon: Iconsax.briefcase,
            gradient: JobColors.gradient,
            label: 'Post Job',
            compact: true,
            onTap: _postJob,
          ),
          _ownerQuickActionTile(
            icon: Iconsax.task_square,
            gradient: JobColors.gradient,
            label: 'My Jobs',
            compact: true,
            onTap: () => Get.toNamed(AppRoutes.myJobs),
          ),
        ],
      ];
      if (tiles.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
    });
  }

  Widget _ownerQuickActionTile({
    required IconData icon,
    required Gradient gradient,
    required String label,
    required VoidCallback? onTap,
    String? badge,
    IconMotionStyle? motion,
    bool isLoading = false,
    bool compact = false,
  }) {
    final iconBox = compact ? 46.0 : 52.0;
    final iconGlyph = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Icon(icon, size: compact ? 23 : 26, color: Colors.white);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: compact ? 4 : 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
          boxShadow: AppShadows.premium(
            AppColors.primary,
            alpha: 0.05,
            blur: 8,
            offset: const Offset(0, 2),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: motion == null || isLoading
                        ? iconGlyph
                        : IconMotion(style: motion, child: iconGlyph),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── "Recently added across India" — rooms and plots merged, newest first ──

  Widget _buildRecentlyAddedSection() {
    return Obx(() {
      final rooms = _tabs.isRoomsActive;
      final plots = _tabs.isPlotsActive;
      final stays = _tabs.isStaysActive;
      if (!rooms && !plots && !stays) return const SizedBox.shrink();
      final loading =
          (rooms && _home.recentlyAddedRoomsLoading.value) ||
          (plots && _home.recentlyAddedPlotsLoading.value) ||
          (stays && _home.recentlyAddedStaysLoading.value);
      final items = loading
          ? const <HomeRecentItem>[]
          : _home.recentMixed(rooms: rooms, plots: plots, stays: stays);
      final failed = {
        if (rooms) HomeSectionKeys.recentRooms,
        if (plots) HomeSectionKeys.recentPlots,
        if (stays) HomeSectionKeys.recentStays,
      }.where(_home.failedSections.contains).toSet();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Recently added across India',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            _buildRecentlyAddedShimmerList()
          else if (items.isEmpty && failed.isNotEmpty)
            _railErrorMessage(ModulePalette.rooms, () => _home.reloadSections(failed))
          else if (items.isEmpty)
            _emptyRailMessage('No listings yet.')
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _recentRow(items[i]),
                  ],
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _recentRow(HomeRecentItem item) {
    final r = item.room;
    if (r != null) {
      return NearbyItemRow(
        thumbnailUrl: r.thumbnailUrl,
        tag: 'FOR RENT',
        title: '${r.roomTypeName ?? 'Room'} Room',
        subtitle: r.districtName,
        caption: 'MONTHLY RENT',
        value: BrowseItem.inr(r.priceMonthly),
        unit: '/mo',
        placeholderIcon: Icons.home_rounded,
        onTap: () => Get.toNamed(AppRoutes.listingDetail, arguments: {'id': r.id}),
      );
    }
    final s = item.stay;
    if (s != null) {
      return NearbyItemRow(
        thumbnailUrl: s.item.thumbnailUrl,
        tag: s.item.tagLabel,
        title: s.item.title,
        subtitle: s.districtName.isNotEmpty ? s.districtName : s.item.locationLabel,
        caption: s.item.priceCaption,
        value: s.item.priceValue,
        unit: s.item.priceUnit,
        palette: ModulePalette.stays,
        placeholderIcon: Icons.home_rounded,
        onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.item.id}),
      );
    }
    final p = item.plot!;
    final area = p.areaValue == p.areaValue.roundToDouble()
        ? p.areaValue.toStringAsFixed(0)
        : p.areaValue.toStringAsFixed(1);
    return NearbyItemRow(
      thumbnailUrl: p.thumbnailUrl,
      tag: 'FOR SALE',
      title: '${p.plotTypeName ?? 'Plot'} Plot',
      subtitle: p.districtName,
      caption: 'PLOT AREA',
      value: '$area ${p.areaUnit}'.trim(),
      palette: ModulePalette.plots,
      placeholderIcon: Icons.landscape_rounded,
      onTap: () => Get.toNamed(AppRoutes.plotDetail, arguments: {'id': p.id}),
    );
  }

  Widget _buildInstagramCard() {
    return Padding(
      key: TourKeys.homeInstagramCard,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _openInstagram,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _kInstagramGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.premium(
              const Color(0xFFDD2A7B),
              alpha: 0.25,
              blur: 16,
              offset: const Offset(0, 6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Iconsax.camera, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Follow us on Instagram',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDD2A7B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyAddedShimmerList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Shimmer.fromColors(
              baseColor: AppColors.shimmerBase,
              highlightColor: AppColors.shimmerHighlight,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
