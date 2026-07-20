import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/inquiry_controller.dart';
import '../controllers/service_catalog_controller.dart';
import '../models/service_list_item_model.dart';
import '../models/service_section_model.dart';
import '../utils/service_icons.dart';
import '../widgets/max_width_content.dart';

// Service-catalog rail zones (Explore Uttarakhand / Expert Consultations / Celebrations &
// Events). Relocated verbatim from home_screen.dart — this screen is now local services'
// one home instead of a Home rail *and* a separate tab duplicating the same content.
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

const _kCelebrationsZone = _SectionZone(
  background: Color(0xFFFDF2F8),
  cardBg: Colors.white,
  imgBg: Color(0xFFFBCFE8),
  accent: Color(0xFFBE185D),
);

const _expertConsultationsSectionName = 'Expert Consultations';
const _celebrationsEventsSectionName = 'Celebrations & Events';

// Explicit per-section branches, not a fallback-swallows-everything default — a section's color
// zone is a deliberate design pick each new section needs, so an unrecognized new section falling
// silently into Explore's green is exactly the bug to avoid here.
_SectionZone _zoneForSection(ServiceSectionModel section) {
  if (section.name == _expertConsultationsSectionName) return _kExpertZone;
  if (section.name == _celebrationsEventsSectionName) return _kCelebrationsZone;
  return _kExploreZone;
}

class LocalServicesScreen extends StatefulWidget {
  const LocalServicesScreen({super.key});

  @override
  State<LocalServicesScreen> createState() => _LocalServicesScreenState();
}

class _LocalServicesScreenState extends State<LocalServicesScreen> {
  final _serviceCatalog = Get.find<ServiceCatalogController>();
  final _inquiryCtrl = Get.find<InquiryController>();

  @override
  void initState() {
    super.initState();
    // IndexedStack builds every tab child at MainScreen mount, so this fires effectively at
    // app start — same eager-load convention ChatController/ServiceCatalogController already
    // use — giving the Inquiries badge real data quickly rather than staying at 0 until the
    // user happens to open My Inquiries directly.
    _inquiryCtrl.loadMyInquiries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 + AppInsets.bottomViewPadding(context)),
        child: MaxWidthContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 4),
              _buildServiceSections(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: title + Inquiries button (live count) + tagline ────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Explore',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.myInquiries),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Iconsax.receipt_text, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text('Inquiries',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        Obx(() {
                          final count = _inquiryCtrl.activeInquiryCount.value;
                          if (count <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 18),
                              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          );
                        }),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Trips, experts & events',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Service section rails — relocated verbatim from home_screen.dart ───────

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
}

/// Rail card for one Service preview — tapping goes straight to Service Detail (skipping the
/// Category-list step). Relocated verbatim from home_screen.dart.
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
