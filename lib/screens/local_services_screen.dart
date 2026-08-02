import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_shadows.dart';
import '../controllers/enquiry_controller.dart';
import '../controllers/service_catalog_controller.dart';
import '../models/service_category_model.dart';
import '../navigation/tour_keys.dart';
import '../widgets/home_banner_carousel.dart';
import '../widgets/pulse_once.dart';
import '../widgets/service_category_peek_card.dart';
import '../widgets/service_zone.dart';
import '../widgets/sweep_highlight.dart';

const _kHeroHighlight = Color(0xFFFDBA74);
const _kPromoAccent = Color(0xFF15803D);
const _kPromoBg = Color(0xFFF0FDF4);

// Local-expert redesign: "book direct, skip the middleman" pitch in the hero,
// banner carousel right below it, a feature-highlights card (trust badges),
// then every category as a ServiceCategoryPeekCard, wrapped into rows below.
class LocalServicesScreen extends StatefulWidget {
  const LocalServicesScreen({super.key});

  @override
  State<LocalServicesScreen> createState() => _LocalServicesScreenState();
}

class _LocalServicesScreenState extends State<LocalServicesScreen> {
  final _serviceCatalog = Get.find<ServiceCatalogController>();
  final _enquiryCtrl = Get.find<EnquiryController>();

  @override
  void initState() {
    super.initState();
    _serviceCatalog.ensureServicesLoaded();
  }

  void _openCategoryGrid(ServiceCategoryModel category) => Get.toNamed(
        AppRoutes.serviceCategoryGrid,
        arguments: {'categoryId': category.id, 'title': category.name},
      );

  void _openServiceCategoriesOverview() => Get.toNamed(AppRoutes.serviceCategoriesOverview);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servicesScaffoldBg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 + AppInsets.bottomViewPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            // HomeBannerCarousel already carries its own horizontal:20 padding
            // internally — no extra Padding wrapper needed here.
            FadeInUp(
              duration: const Duration(milliseconds: 260),
              from: 14,
              child: HomeBannerCarousel(onTap: _openServiceCategoriesOverview),
            ),
            const SizedBox(height: 18),
            FadeInUp(
              duration: const Duration(milliseconds: 260),
              delay: const Duration(milliseconds: 60),
              from: 14,
              child: _buildFeatureHighlightsCard(),
            ),
            const SizedBox(height: 18),
            FadeInUp(
              duration: const Duration(milliseconds: 260),
              delay: const Duration(milliseconds: 120),
              from: 14,
              child: _buildServiceCategories(),
            ),
            const SizedBox(height: 4),
            FadeInUp(
              duration: const Duration(milliseconds: 260),
              delay: const Duration(milliseconds: 180),
              from: 14,
              child: _buildPromoBanner(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Header: title + Enquiries button (live count) + trust subtitle ──────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
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
                      "What's Next?",
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.myEnquiries),
                    child: PulseOnce(
                      child: Container(
                        key: TourKeys.servicesEnquiriesButton,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppShadows.premium(AppColors.primary, alpha: 0.15, blur: 8, offset: const Offset(0, 3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Iconsax.receipt_text, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          const Text('Enquiries',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          Obx(() {
                            final count = _enquiryCtrl.activeEnquiryCount.value;
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
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, height: 1.35),
                  children: [
                    const TextSpan(text: 'Direct Booking with\n'),
                    TextSpan(text: 'Uttarakhand Local Experts', style: TextStyle(color: _kHeroHighlight)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _featureHighlights = [
    (Iconsax.profile_remove, 'No Middleman', 'Save More'),
    (Iconsax.tag, 'Best Price', 'Transparent Pricing'),
    (Iconsax.headphone, '24x7 Support', 'Always with You'),
  ];

  // ── Feature-highlights card — trust badges on a tinted gradient panel ───────

  Widget _buildFeatureHighlightsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.servicesFeatureGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.premium(AppColors.primary, alpha: 0.06, blur: 16, offset: const Offset(0, 6)),
        ),
        child: Row(
          children: [
            for (final feat in _featureHighlights)
              Expanded(child: _FeatureHighlight(icon: feat.$1, title: feat.$2, subtitle: feat.$3)),
          ],
        ),
      ),
    );
  }

  // ── Every active category as a peek card, wrapped into rows so all categories
  // stay visible without needing a horizontal swipe — placed below the new
  // hero/carousel/feature-highlights pieces instead of being the entire body,
  // unlike the pre-redesign screen (ServiceCategoryRail/service_zone.dart).

  Widget _buildServiceCategories() {
    return Obx(() {
      final loading = _serviceCatalog.categoriesLoading.value && _serviceCatalog.categories.isEmpty;
      if (loading) return const ServiceCategoryPeekCardShimmer();
      final cats = _serviceCatalog.activeCategories;
      if (cats.isEmpty) return const SizedBox.shrink();
      const spacing = 14.0;
      const columns = 2;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final footprint = (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final cardWidth = ServiceCategoryPeekCard.cardWidthForFootprint(footprint);
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < cats.length; i++)
                  KeyedSubtree(
                    key: TourKeys.serviceCategoryKey(cats[i].id),
                    child: ServiceCategoryPeekCard(
                      category: cats[i],
                      zone: serviceZoneForIndex(i),
                      serviceCount: cats[i].serviceCount,
                      onTap: () => _openCategoryGrid(cats[i]),
                      cardWidth: cardWidth,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    });
  }

  // ── Promo banner — last element on the page ─────────────────────────────────

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kPromoBg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Book Direct • Save More',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w800, color: _kPromoAccent),
          ),
          const SizedBox(height: 6),
          Text.rich(
            const TextSpan(
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.25),
              children: [
                TextSpan(text: 'Same Experience, '),
                TextSpan(text: 'Better Price!', style: TextStyle(color: _kPromoAccent)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          const Text(
            'Connect directly with Uttarakhand local experts and save upto 20-30% on every booking.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textMedium, height: 1.45),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openServiceCategoriesOverview,
            child: PulseOnce(
              child: SweepHighlight(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: _kPromoAccent, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Send Inquiry Now',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureHighlight({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.textLight),
        ),
      ],
    );
  }
}
