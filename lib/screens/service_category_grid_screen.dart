import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/service_catalog_controller.dart';
import '../widgets/service_rail_card.dart';
import '../widgets/service_zone.dart';

/// "View all" for one catalog Category — the SAME rich service cards the
/// rails show (image + name + description via [ServiceRailCard]), just as a
/// full 2-column grid. No grouping, no intermediate text lists: card tap goes
/// straight to Service Detail. Replaces the old two-hop
/// ServiceCatalogListScreen (Section -> Categories list -> Services list).
///
/// Stateless over [ServiceCatalogController]'s already-loaded catalog —
/// `servicesForCategory` is a client-side slice, so opening this screen costs
/// zero network requests. Expects `Get.arguments`: {categoryId, title}.
class ServiceCategoryGridScreen extends StatefulWidget {
  const ServiceCategoryGridScreen({super.key});

  @override
  State<ServiceCategoryGridScreen> createState() => _ServiceCategoryGridScreenState();
}

class _ServiceCategoryGridScreenState extends State<ServiceCategoryGridScreen> {
  final _catalog = Get.find<ServiceCatalogController>();

  // Mirrors ViewAllScreen's grid geometry; slightly taller aspect than the
  // rooms/plots grid (0.80 vs 0.72) since ServiceRailCard's text block is
  // shorter than ListingGridCard's price+location footer.
  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 190,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 0.80,
  );

  @override
  void initState() {
    super.initState();
    _catalog.ensureServicesLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final args = (Get.arguments as Map?) ?? const {};
    final categoryId = args['categoryId'] as String? ?? '';
    final title = args['title'] as String? ?? 'Services';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(title),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => catalog.refreshAll(),
              child: Obx(() {
                final services = catalog.servicesForCategory(categoryId);
                if (catalog.servicesLoading.value && services.isEmpty) {
                  return _buildGridShimmer(context);
                }
                if (services.isEmpty) return _buildEmpty(context);
                // Zone matches the rail this category renders as on Home/the
                // Services tab — same index-rotation, so the grid inherits
                // the exact colors the user just tapped through.
                final zoneIndex = catalog.activeCategories.indexWhere((c) => c.id == categoryId);
                final zone = serviceZoneForIndex(zoneIndex);
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                  gridDelegate: _gridDelegate,
                  itemCount: services.length,
                  itemBuilder: (_, i) => ServiceRailCard(
                    service: services[i],
                    zone: zone,
                    width: null,
                    imageHeight: 110,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridShimmer(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
      gridDelegate: _gridDelegate,
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    // Inside a RefreshIndicator, so keep it scrollable for pull-to-refresh.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(
          child: Text(
            'No services yet — check back soon.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
          ),
        ),
      ],
    );
  }
}
