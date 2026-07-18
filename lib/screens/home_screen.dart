import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/service_catalog_controller.dart';
import '../models/service_list_item_model.dart';
import '../models/service_section_model.dart';
import '../utils/service_icons.dart';
import '../widgets/coin_balance_chip.dart';
import '../widgets/max_width_content.dart';
import '../widgets/sliding_chip_toggle.dart';

const _kPlotColor = Color(0xFF92400E);
const _kPlotGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF92400E), Color(0xFF78350F)],
);

// Service-catalog rail zones (Explore Uttarakhand / Expert Consultations
// only — Rooms/Plots, Quick Actions and the promo banner are untouched by
// this). Adjacent rails deliberately stay separated by the scaffold's own
// white/near-white background (the SizedBox gap in _buildServiceSections)
// rather than touching zone-to-zone.
class _SectionZone {
  final Color background;
  final Color cardBg;
  final Color imgBg;
  final Color accent;
  const _SectionZone({
    required this.background,
    required this.cardBg,
    required this.imgBg,
    required this.accent,
  });
}

const _kExploreZone = _SectionZone(
  background: Color(0xFFECFDF5),
  cardBg: Colors.white,
  imgBg: Color(0xFFD1FAE5),
  accent: Color(0xFF059669),
);

const _kExpertZone = _SectionZone(
  background: Color(0xFFF3E4CE),
  cardBg: Color(0xFFFFFDF8),
  imgBg: Color(0xFFEAD9BE),
  accent: Color(0xFFC2410C),
);

const _expertConsultationsSectionName = 'Expert Consultations';

_SectionZone _zoneForSection(ServiceSectionModel section) =>
    section.name == _expertConsultationsSectionName ? _kExpertZone : _kExploreZone;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();
  final _serviceCatalog = Get.find<ServiceCatalogController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _home.reloadDistrict,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 24 + AppInsets.bottomViewPadding(context)),
          child: MaxWidthContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(context),
                _buildToggle(),
                const SizedBox(height: 2),
                _buildListingsSection(),
                const SizedBox(height: 15),
                _buildQuickActions(),
                const SizedBox(height: 15),
                _buildServiceSections(),
                const SizedBox(height: 20),
                _buildPromoBanner(),
              ],
            ),
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
      padding: EdgeInsets.fromLTRB(20, AppInsets.topViewPadding(context) + 14, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Obx(() {
                  final name = _auth.profileName.value;
                  final firstName = name.trim().isNotEmpty ? name.trim().split(' ').first : 'there';
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
              const CoinBalanceChip(color: Colors.white),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.notification, color: Colors.white, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Obx(() => Row(
                children: [
                  Expanded(
                    child: _statCard(
                      Iconsax.home,
                      _home.summaryLoading.value ? null : _home.roomsCount.value,
                      'Rooms nearby',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      Icons.landscape_rounded,
                      _home.summaryLoading.value ? null : _home.plotsCount.value,
                      'Plots nearby',
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, int? count, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              count == null
                  ? _shimmerBlock(width: 24, height: 16, dark: false)
                  : Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
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

  // ── "Rooms for you" / "Plots for you" — one visible rail at a time ─────────

  Widget _buildListingsSection() {
    return Obx(() {
      final isRooms = _home.activeTab.value == 'rooms';
      final loading = isRooms ? _home.roomsLoading.value : _home.plotsLoading.value;
      final title = isRooms ? 'Rooms for you' : 'Plots for you';

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
                  onTap: () => Get.toNamed(isRooms ? AppRoutes.viewAllRooms : AppRoutes.viewAllPlots),
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
            height: 168,
            child: loading
                ? _buildListingShimmerRail()
                : isRooms
                    ? _buildRoomsRail()
                    : _buildPlotsRail(),
          ),
        ],
      );
    });
  }

  Widget _buildRoomsRail() {
    final items = _home.recentRooms;
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
          title: r.roomTypeName ?? 'Room',
          locationLabel: r.cityName ?? r.districtName,
        );
      },
    );
  }

  Widget _buildPlotsRail() {
    final items = _home.recentPlots;
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
          locationLabel: p.cityName ?? p.districtName,
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _emptyRailMessage(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 100,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          ),
        ),
      );

  // ── Quick actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _quickAction(Iconsax.home, 'Find Room', AppColors.primary, AppColors.primary.withValues(alpha: 0.1), () {
              _auth.tabIndex.value = AppTabs.rooms;
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickAction(
              Icons.landscape_rounded,
              'Find Plot',
              AppColors.success,
              AppColors.success.withValues(alpha: 0.1),
              () => _auth.tabIndex.value = AppTabs.plots,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickAction(
              Icons.meeting_room_rounded,
              'My Rooms',
              AppColors.warning,
              AppColors.warning.withValues(alpha: 0.1),
              () => Get.toNamed(AppRoutes.myListings),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickAction(
              Icons.terrain_rounded,
              'My Plots',
              _kPlotColor,
              _kPlotColor.withValues(alpha: 0.1),
              () => Get.toNamed(AppRoutes.myPlots),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Service Catalog rails — one per active ServiceSection the API ──────
  // returns (Explore Uttarakhand, Expert Consultations, and any future
  // vertical an admin adds) — never hardcoded to two named rails, so a new
  // Section needs zero app code to show up here.

  Widget _buildServiceSections() {
    return Obx(() {
      if (_serviceCatalog.catalogLoading.value && _serviceCatalog.sections.isEmpty) {
        return _buildServiceSectionShimmer();
      }
      final sections = _serviceCatalog.activeSections;
      if (sections.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in sections) ...[
            _buildServiceSectionRail(section),
            const SizedBox(height: 28),
          ],
        ],
      );
    });
  }

  Widget _buildServiceSectionRail(ServiceSectionModel section) {
    // containsKey, not just an empty list, distinguishes "this section's preview
    // hasn't come back from the backend yet" (show a shimmer) from "it came back
    // and there's genuinely nothing to show" (render nothing) — sectionPreviews
    // is populated per-section after the core catalog load, so there's a real
    // window right after launch where a Section is known but its preview isn't.
    final hasPreview = _serviceCatalog.sectionPreviews.containsKey(section.id);
    final items = _serviceCatalog.sectionPreviews[section.id] ?? const [];
    if (hasPreview && items.isEmpty) return const SizedBox.shrink();
    final zone = _zoneForSection(section);
    return Container(
      width: double.infinity,
      color: zone.background,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(serviceIconFor(section.iconName), size: 16, color: zone.accent),
                    const SizedBox(width: 6),
                    Text(
                      section.name,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.serviceCategoryList, arguments: {
                    'mode': 'categories',
                    'parentId': section.id,
                    'title': section.name,
                  }),
                  child: Text(
                    'View all',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: zone.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!hasPreview)
            _buildServiceSectionShimmer()
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _ServiceRailCard(
                  service: items[i],
                  cardBg: zone.cardBg,
                  imgBg: zone.imgBg,
                  iconColor: zone.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceSectionShimmer() {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            width: 150,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  // ── Promo banner ─────────────────────────────────────────────────────────

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.all(Radius.circular(11))),
              child: const Icon(Iconsax.add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'List your property',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  Text(
                    'Reach renters nearby',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.myListings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.all(Radius.circular(20))),
                child: const Text(
                  'My Room',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBlock({required double width, required double height, double radius = 6, bool dark = true}) {
    return Shimmer.fromColors(
      baseColor: dark ? AppColors.shimmerBase : Colors.white.withValues(alpha: 0.3),
      highlightColor: dark ? AppColors.shimmerHighlight : Colors.white.withValues(alpha: 0.6),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

class _HomeListingCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String priceLabel;
  final String title;
  final String locationLabel;

  const _HomeListingCard({
    required this.thumbnailUrl,
    required this.priceLabel,
    required this.title,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                SizedBox(
                  height: 108,
                  width: double.infinity,
                  child: thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.93), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      priceLabel,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
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
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Iconsax.location, size: 10, color: AppColors.primaryLight),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _placeholder() => Container(
        color: AppColors.surface,
        child: const Center(child: Icon(Icons.home_rounded, size: 28, color: AppColors.primaryLight)),
      );
}

/// Home-rail card for one Service preview — tapping goes straight to
/// Service Detail (skipping the Category-list step), same shortcut shape as
/// _HomeListingCard going straight to listing/plot detail.
class _ServiceRailCard extends StatelessWidget {
  final ServiceListItemModel service;
  final Color cardBg;
  final Color imgBg;
  final Color iconColor;

  const _ServiceRailCard({
    required this.service,
    this.cardBg = Colors.white,
    this.imgBg = AppColors.surface,
    this.iconColor = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.serviceDetail, arguments: {'id': service.id}),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: service.coverPhotoUrl.isEmpty
                        ? _placeholder()
                        : CachedNetworkImage(
                            imageUrl: service.coverPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: imgBg),
                            errorWidget: (_, __, ___) => _placeholder(),
                          ),
                  ),
                  if (service.isFeatured)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.93), borderRadius: BorderRadius.circular(20)),
                        child: const Text(
                          'Featured',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.primary),
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
                  Row(
                    children: [
                      Icon(serviceIconFor(service.iconName), size: 12, color: iconColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          service.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, color: AppColors.textLight, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: imgBg,
        child: Center(child: Icon(Icons.travel_explore_rounded, size: 26, color: iconColor)),
      );
}
