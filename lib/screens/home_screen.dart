import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../config/app_tabs.dart';
import '../navigation/tour_keys.dart';
import '../services/add_listing_flow.dart';
import '../widgets/home_owner_carousel.dart';
import '../widgets/icon_motion.dart';

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
              const SizedBox(height: 12),
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
              const SizedBox(height: 15),
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

  // ── "Rooms for Rent near you" / "Plots for Sale near you" ──────────────────

  Widget _buildListingsSections() {
    return Obx(() {
      final rooms = _tabs.isRoomsActive;
      final plots = _tabs.isPlotsActive;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rooms)
            _buildRail(
              title: 'Rooms for Rent near you',
              tab: AppTabs.rooms,
              loading: _home.roomsLoading.value,
              rail: () => _buildRoomsRail(_home.recentRooms),
            ),
          if (rooms && plots) const SizedBox(height: 15),
          if (plots)
            _buildRail(
              title: 'Plots for Sale near you',
              tab: AppTabs.plots,
              loading: _home.plotsLoading.value,
              rail: () => _buildPlotsRail(_home.recentPlots),
            ),
        ],
      );
    });
  }

  Widget _buildRail({
    required String title,
    required int tab,
    required bool loading,
    required Widget Function() rail,
  }) {
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
        SizedBox(
          height: 150,
          child: loading ? _buildListingShimmerRail() : rail(),
        ),
      ],
    );
  }

  Widget _buildRoomsRail(List<HomeRoomModel> items) {
    if (items.isEmpty) return _emptyRailMessage('No rooms listed here yet.');
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final r = items[i];
        return _HomeListingCard(
          thumbnailUrl: r.thumbnailUrl,
          priceLabel: '₹${r.priceMonthly}/mo',
          title:
              '${r.roomTypeName ?? 'Room'}${r.furnishedStatus != 'None' ? ' · ${r.furnishedStatus}' : ''}',
          locationLabel: r.districtName,
          onTap: () =>
              Get.toNamed(AppRoutes.listingDetail, arguments: {'id': r.id}),
        );
      },
    );
  }

  Widget _buildPlotsRail(List<HomePlotModel> items) {
    if (items.isEmpty) return _emptyRailMessage('No plots listed here yet.');
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final p = items[i];
        final area = p.areaValue == p.areaValue.roundToDouble()
            ? p.areaValue.toStringAsFixed(0)
            : p.areaValue.toStringAsFixed(1);
        return _HomeListingCard(
          thumbnailUrl: p.thumbnailUrl,
          priceLabel: '$area ${p.areaUnit}',
          title: p.plotTypeName ?? 'Plot',
          locationLabel: p.districtName,
          onTap: () =>
              Get.toNamed(AppRoutes.plotDetail, arguments: {'id': p.id}),
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
          width: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // No fixed height — inside the near-you rail's SizedBox(height: 150)
  // parent it gets stretched tight to fill that space (unchanged from
  // before); inside Recently Added's plain Column it sizes to content.
  Widget _emptyRailMessage(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
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
          AppColors.primary,
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
              Icons.search_rounded,
              size: 60,
              color: AppColors.primaryLight.withValues(alpha: 0.08),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nothing here yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
  );

  // ── Owner quick actions ─────────────────────────────────────────────────

  Widget _buildOwnerQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Obx(() {
        final rooms = _tabs.isRoomsActive;
        final plots = _tabs.isPlotsActive;
        final checking = AddListingFlow.checking.value;
        final tiles = <Widget>[
          if (rooms)
            KeyedSubtree(
              key: TourKeys.homeQuickActionAddRoom,
              child: _ownerQuickActionTile(
                icon: Icons.add_rounded,
                gradient: AppColors.primaryGradient,
                shadowColor: AppColors.primaryLight,
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
                shadowColor: AppColors.plotDark,
                label: 'Add Plot',
                motion: IconMotionStyle.pulse,
                isLoading: checking == false,
                onTap: checking != null ? null : () => AddListingFlow.start(false),
              ),
            ),
          if (rooms || plots)
            KeyedSubtree(
              key: TourKeys.homeQuickActionLeads,
              child: _ownerQuickActionTile(
                icon: Icons.bar_chart_rounded,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFBBF24), AppColors.warning],
                ),
                shadowColor: AppColors.warning,
                label: 'My Listings',
                motion: IconMotionStyle.grow,
                onTap: () => Get.toNamed(
                  rooms ? AppRoutes.myListings : AppRoutes.myPlots,
                ),
              ),
            ),
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      }),
    );
  }

  Widget _ownerQuickActionTile({
    required IconData icon,
    required Gradient gradient,
    required Color shadowColor,
    required String label,
    required VoidCallback? onTap,
    String? badge,
    IconMotionStyle? motion,
    bool isLoading = false,
  }) {
    final iconGlyph = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Icon(icon, size: 26, color: Colors.white);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(
            shadowColor,
            alpha: 0.14,
            blur: 12,
            offset: const Offset(0, 5),
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 1,
                    ),
                    boxShadow: AppShadows.premium(
                      shadowColor,
                      alpha: 0.3,
                      blur: 4,
                      offset: const Offset(0, 2),
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
      if (!rooms && !plots) return const SizedBox.shrink();
      final loading =
          (rooms && _home.recentlyAddedRoomsLoading.value) ||
          (plots && _home.recentlyAddedPlotsLoading.value);
      final items = loading
          ? const <HomeRecentItem>[]
          : _home.recentMixed(rooms: rooms, plots: plots);

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
      return _HomeListingRow(
        thumbnailUrl: r.thumbnailUrl,
        priceLabel: '₹${r.priceMonthly}/mo',
        title:
            '${r.roomTypeName ?? 'Room'}${r.furnishedStatus != 'None' ? ' · ${r.furnishedStatus}' : ''}',
        locationLabel: r.districtName,
        isNew: true,
      );
    }
    final p = item.plot!;
    final area = p.areaValue == p.areaValue.roundToDouble()
        ? p.areaValue.toStringAsFixed(0)
        : p.areaValue.toStringAsFixed(1);
    return _HomeListingRow(
      thumbnailUrl: p.thumbnailUrl,
      priceLabel: '$area ${p.areaUnit}',
      title: p.plotTypeName ?? 'Plot',
      locationLabel: p.districtName,
      isNew: true,
      placeholderIcon: Icons.landscape_rounded,
      accent: AppColors.plot,
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
                  color: Colors.white,
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

class _HomeListingCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String priceLabel;
  final String title;
  final String locationLabel;
  final VoidCallback onTap;

  const _HomeListingCard({
    required this.thumbnailUrl,
    required this.priceLabel,
    required this.title,
    required this.locationLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(
            AppColors.primary,
            alpha: 0.10,
            blur: 16,
            offset: const Offset(0, 6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: thumbnailUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth:
                                (140 * MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                            memCacheHeight:
                                (100 * MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                            placeholder: (_, __) =>
                                Container(color: AppColors.surface),
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.93),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        priceLabel,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Iconsax.location,
                        size: 10,
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _placeholder() => Container(
    color: AppColors.surface,
    child: const Center(
      child: Icon(Icons.home_rounded, size: 28, color: AppColors.primaryLight),
    ),
  );
}

/// "Recently added"'s vertical row layout — same chat-conversation-row card
/// treatment (white, rounded, soft shadow), thumbnail left, price right.
/// Display-only (no onTap) — matches _buildRoomsRail/_buildPlotsRail's
/// clickable: false for this section.
class _HomeListingRow extends StatelessWidget {
  final String? thumbnailUrl;
  final String priceLabel;
  final String title;
  final String locationLabel;
  final bool isNew;
  final IconData placeholderIcon;
  final Color accent;

  const _HomeListingRow({
    required this.thumbnailUrl,
    required this.priceLabel,
    required this.title,
    required this.locationLabel,
    this.isNew = false,
    this.placeholderIcon = Icons.home_rounded,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.premium(
          AppColors.primary,
          alpha: 0.10,
          blur: 12,
          offset: const Offset(0, 4),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth:
                              (60 * MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          memCacheHeight:
                              (60 * MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          placeholder: (_, __) =>
                              Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => _placeholder(placeholderIcon),
                        )
                      : _placeholder(placeholderIcon),
                ),
                if (isNew)
                  Positioned(
                    bottom: 3,
                    right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 6.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Iconsax.location,
                      size: 10,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            priceLabel,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _placeholder(IconData icon) => Container(
    color: AppColors.surface,
    child: Center(
      child: Icon(icon, size: 22, color: AppColors.primaryLight),
    ),
  );
}

