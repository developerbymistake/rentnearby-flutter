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
import '../controllers/location_controller.dart';
import '../widgets/sliding_chip_toggle.dart';

const _kPlotColor = Color(0xFF92400E);
const _kPlotGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF92400E), Color(0xFF78350F)],
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();
  final _location = Get.find<LocationController>();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(context),
              _buildToggle(),
              const SizedBox(height: 6),
              _buildListingsSection(),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildPopularAreas(),
              const SizedBox(height: 20),
              _buildPromoBanner(),
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
            child: _quickAction(Iconsax.home, 'Find Room', AppColors.primary, AppColors.surface, () {
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 7),
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

  // ── Popular Areas — the district's cities, already loaded by LocationController ─

  Widget _buildPopularAreas() {
    return Obx(() {
      final cities = _location.nearbyCities;
      if (cities.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Popular Areas',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final c = cities[i];
                return SizedBox(
                  width: 60,
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(gradient: AppColors.cardGradient, shape: BoxShape.circle),
                        child: const Icon(Iconsax.location, color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
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
                    'Reach renters nearby — free',
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
