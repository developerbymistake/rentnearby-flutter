import 'dart:ui' as ui;

import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_shadows.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/notification_controller.dart';
import '../config/app_tabs.dart';
import '../navigation/tour_keys.dart';
import '../widgets/floating_loop.dart';
import '../widgets/icon_motion.dart';
import '../widgets/pulse_once.dart';
import '../widgets/sliding_chip_toggle.dart';
import '../widgets/sweep_highlight.dart';

const _kPlotColor = AppColors.plot;
const _kPlotGradient = AppColors.plotGradient;
const _kQuickActionGreen = Color(0xFF22C55E);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();

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
              FadeInDown(
                duration: const Duration(milliseconds: 260),
                from: 10,
                child: _buildToggle(),
              ),
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                delay: const Duration(milliseconds: 60),
                from: 14,
                child: _buildOwnerCtaBanner(),
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
                child: _buildListingsSection(),
              ),
              const SizedBox(height: 15),
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                delay: const Duration(milliseconds: 240),
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
        52,
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

  // ── Rooms/Plots toggle, floating in the hero's bottom edge ─────────────────
  // Single sliding track (SlidingChipToggle), not two independent chips —
  // the gradient pill physically slides between Rooms/Plots.

  Widget _buildToggle() {
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Obx(() {
          final active = _home.activeTab.value;
          return SlidingChipToggle(
            key: TourKeys.homeToggle,
            selectedIndex: active == 'rooms' ? 0 : 1,
            onChanged: (i) => _home.setActiveTab(i == 0 ? 'rooms' : 'plots'),
            options: [
              ToggleOption(
                label: 'Rooms',
                icon: Iconsax.home,
                activeColor: AppColors.primary,
                gradient: AppColors.primaryGradient,
              ),
              ToggleOption(
                label: 'Plots',
                icon: Icons.landscape_rounded,
                activeColor: _kPlotColor,
                gradient: _kPlotGradient,
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── "Rooms for Rent near you" / "Plots for Sale near you" — one visible rail at a time ─

  Widget _buildListingsSection() {
    return Obx(() {
      final isRooms = _home.activeTab.value == 'rooms';
      final loading = isRooms
          ? _home.roomsLoading.value
          : _home.plotsLoading.value;
      final title = isRooms ? 'Rooms for Rent near you' : 'Plots for Sale near you';

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
                  onTap: () => Get.toNamed(
                    isRooms ? AppRoutes.viewAllRooms : AppRoutes.viewAllPlots,
                  ),
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
            child: loading
                ? _buildListingShimmerRail()
                : isRooms
                ? _buildRoomsRail(_home.recentRooms)
                : _buildPlotsRail(_home.recentPlots),
          ),
        ],
      );
    });
  }

  // "Rooms for Rent near you"/"Plots for Sale near you" — the only remaining callers of these two, both
  // always clickable and never NEW-tagged. Recently added has its own
  // vertical list builders below instead.
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
          // Same "RoomType · FurnishedStatus" combination ViewAllController
          // already uses for this same data — Home's rail was silently
          // dropping the furnished-status half of it.
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

  // ── Owner CTA banner — mode-aware, illustration bleeds off the right edge ──

  Widget _buildOwnerCtaBanner() {
    return Transform.translate(
      offset: const Offset(0, -6),
      child: Padding(
      key: TourKeys.homeManageListingsCard,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Obx(() {
        final isRooms = _home.activeTab.value == 'rooms';
        final accent = isRooms ? AppColors.primary : AppColors.success;
        return Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isRooms
                  ? const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]
                  : const [Color(0xFFEAFBF0), Color(0xFFF0FDF4)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.premium(
              accent,
              alpha: 0.16,
              blur: 20,
              offset: const Offset(0, 8),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 185,
                child: SizedBox.expand(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        bottom: 14,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 8),
                            child: Container(
                              width: 84,
                              height: 16,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                        ),
                      ),
                      FloatingLoop(
                        child: SizedBox.expand(
                          child: Image.asset(
                            isRooms
                                ? 'assets/images/owner_cta/house.png'
                                : 'assets/images/owner_cta/plot.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 70, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (isRooms
                                  ? AppColors.primary
                                  : AppColors.success)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Are you an Owner?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isRooms ? 'List your room' : 'List your plot',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isRooms
                              ? AppColors.primary
                              : const Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Grow your reach',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Get.toNamed(
                          isRooms ? AppRoutes.myListings : AppRoutes.myPlots,
                        ),
                        child: PulseOnce(
                          child: SweepHighlight(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Add Your Listing',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }),
      ),
    );
  }

  // ── Owner quick actions — 3 tiles ───────────────────────────────────────

  Widget _buildOwnerQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Obx(() {
        final isRooms = _home.activeTab.value == 'rooms';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ownerQuickActionTile(
                icon: Icons.add_rounded,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF60A5FA), AppColors.primaryLight],
                ),
                shadowColor: AppColors.primaryLight,
                label: isRooms ? 'Add Room' : 'Add Plot',
                motion: IconMotionStyle.pulse,
                onTap: () => Get.toNamed(
                  isRooms ? AppRoutes.addListing : AppRoutes.addPlot,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ownerQuickActionTile(
                icon: Icons.search_rounded,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4ADE80), _kQuickActionGreen],
                ),
                shadowColor: _kQuickActionGreen,
                label: isRooms ? 'Find Room' : 'Find Plot',
                motion: IconMotionStyle.scan,
                onTap: () => _auth.tabIndex.value =
                    isRooms ? AppTabs.rooms : AppTabs.plots,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ownerQuickActionTile(
                icon: Icons.bar_chart_rounded,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFBBF24), AppColors.warning],
                ),
                shadowColor: AppColors.warning,
                label: 'Views & Leads',
                badge: 'Soon',
                motion: IconMotionStyle.grow,
                onTap: null,
              ),
            ),
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
  }) {
    final iconGlyph = Icon(icon, size: 26, color: Colors.white);
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
                    child: motion == null
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

  // ── "Recently added Rooms"/"Recently added Plots" — toggle-aware like
  // "Rooms for Rent near you"/"Plots for Sale near you" above, but sorted newest-first, and
  // district-free (see HomeController.recentlyAddedRooms/Plots and the
  // dedicated /home/{rooms|plots}/recent endpoints).

  Widget _buildRecentlyAddedSection() {
    return Obx(() {
      final isRooms = _home.activeTab.value == 'rooms';
      final loading = isRooms
          ? _home.recentlyAddedRoomsLoading.value
          : _home.recentlyAddedPlotsLoading.value;
      final title = isRooms ? 'Rooms for Rent across India' : 'Plots for Sale across India';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          loading
              ? _buildRecentlyAddedShimmerList()
              : isRooms
              ? _buildRecentlyAddedRoomsList(_home.recentlyAddedRooms)
              : _buildRecentlyAddedPlotsList(_home.recentlyAddedPlots),
        ],
      );
    });
  }

  // Vertical list-row layout for "Recently added" — same white rounded-card
  // + soft-shadow treatment as a chat conversation row, stacked top to
  // bottom and scrolled with the rest of the page (not its own horizontal
  // rail). Display-only — _HomeListingRow has no onTap at all.
  Widget _buildRecentlyAddedRoomsList(List<HomeRoomModel> items) {
    if (items.isEmpty) return _emptyRailMessage('No rooms listed here yet.');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _HomeListingRow(
              thumbnailUrl: items[i].thumbnailUrl,
              priceLabel: '₹${items[i].priceMonthly}/mo',
              title:
                  '${items[i].roomTypeName ?? 'Room'}${items[i].furnishedStatus != 'None' ? ' · ${items[i].furnishedStatus}' : ''}',
              locationLabel: items[i].districtName,
              isNew: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentlyAddedPlotsList(List<HomePlotModel> items) {
    if (items.isEmpty) return _emptyRailMessage('No plots listed here yet.');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _HomeListingRow(
              thumbnailUrl: items[i].thumbnailUrl,
              priceLabel: items[i].areaValue == items[i].areaValue.roundToDouble()
                  ? '${items[i].areaValue.toStringAsFixed(0)} ${items[i].areaUnit}'
                  : '${items[i].areaValue.toStringAsFixed(1)} ${items[i].areaUnit}',
              title: items[i].plotTypeName ?? 'Plot',
              locationLabel: items[i].districtName,
              isNew: true,
            ),
          ],
        ],
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

  const _HomeListingRow({
    required this.thumbnailUrl,
    required this.priceLabel,
    required this.title,
    required this.locationLabel,
    this.isNew = false,
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
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
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
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _placeholder() => Container(
    color: AppColors.surface,
    child: const Center(
      child: Icon(Icons.home_rounded, size: 22, color: AppColors.primaryLight),
    ),
  );
}
