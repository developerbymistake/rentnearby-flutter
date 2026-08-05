import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/service_catalog_controller.dart';
import '../models/service_list_item_model.dart';
import '../widgets/service_rail_card.dart';
import '../widgets/service_zone.dart';

/// "View all" for one catalog Category — the SAME rich service cards the
/// rails show (image + name + description via [ServiceRailCard]), just as a
/// full 2-column grid. No grouping, no intermediate text lists: card tap goes
/// straight to Service Detail. Replaces the old two-hop
/// ServiceCatalogListScreen (Section -> Categories list -> Services list).
class ServiceCategoryGridScreen extends StatefulWidget {
  const ServiceCategoryGridScreen({super.key});

  @override
  State<ServiceCategoryGridScreen> createState() => _ServiceCategoryGridScreenState();
}

class _ServiceCategoryGridScreenState extends State<ServiceCategoryGridScreen> {
  final _catalog = Get.find<ServiceCatalogController>();
  late final String _categoryId;
  late final String _title;

  List<ServiceListItemModel> _services = [];
  bool _loading = true;

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
    final args = (Get.arguments as Map?) ?? const {};
    _categoryId = args['categoryId'] as String? ?? '';
    _title = args['title'] as String? ?? 'Services';
    _catalog.loadServicesForCategory(_categoryId).then((list) {
      if (!mounted) return;
      setState(() {
        _services = list;
        _loading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _onRefresh() => _catalog.loadServicesForCategory(_categoryId, forceRefresh: true).then((list) {
        if (mounted) setState(() => _services = list);
      });

  @override
  Widget build(BuildContext context) {
    // Zone matches the rail this category renders as elsewhere in the app —
    // same index-rotation, so the grid inherits the exact colors the user
    // just tapped through.
    final zoneIndex = _catalog.activeCategories.indexWhere((c) => c.id == _categoryId);
    final zone = serviceZoneForIndex(zoneIndex);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(_title),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _onRefresh,
              child: _loading
                  ? _buildGridShimmer(context)
                  : _services.isEmpty
                      ? _buildEmpty(context)
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                          gridDelegate: _gridDelegate,
                          itemCount: _services.length,
                          // Delay is capped at index 9 (max 360ms) so a large category's
                          // last row doesn't wait over a second to appear.
                          itemBuilder: (_, i) => FadeInUp(
                            duration: const Duration(milliseconds: 260),
                            delay: Duration(milliseconds: (i < 9 ? i : 9) * 40),
                            from: 14,
                            child: ServiceRailCard(
                              service: _services[i],
                              zone: zone,
                              width: null,
                              imageHeight: 110,
                            ),
                          ),
                        ),
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
      itemBuilder: (_, _) => Shimmer.fromColors(
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
