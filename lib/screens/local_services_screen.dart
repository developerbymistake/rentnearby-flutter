import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/inquiry_controller.dart';
import '../controllers/service_catalog_controller.dart';
import '../widgets/service_category_rail.dart';
import '../widgets/service_zone.dart';

// Rails/zones/cards live in widgets/service_category_rail.dart +
// widgets/service_zone.dart, shared verbatim with home_screen.dart — one rail
// per active ServiceCategory, color-zoned by index rotation (never by name).
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
    _serviceCatalog.ensureServicesLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 + AppInsets.bottomViewPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 4),
            _buildServiceRails(),
          ],
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
                      'Services',
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
                'Trips & expert consultations',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Service section rails — relocated verbatim from home_screen.dart ───────

  Widget _buildServiceRails() {
    return Obx(() {
      final stillLoading = _serviceCatalog.categoriesLoading.value || _serviceCatalog.servicesLoading.value;
      if (stillLoading && _serviceCatalog.categories.isEmpty) {
        return const ServiceRailShimmer();
      }
      final cats = _serviceCatalog.activeCategories;
      if (cats.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cats.length; i++) ...[
            ServiceCategoryRail(
              category: cats[i],
              zone: serviceZoneForIndex(i),
              // containsKey, not just an empty list, distinguishes "this category's
              // preview hasn't come back yet" (rail shows its shimmer) from "it came
              // back and there's genuinely nothing to show" (rail renders nothing).
              items: _serviceCatalog.categoryPreviews.containsKey(cats[i].id)
                  ? _serviceCatalog.categoryPreviews[cats[i].id]
                  : null,
            ),
            const SizedBox(height: 28),
          ],
        ],
      );
    });
  }
}
