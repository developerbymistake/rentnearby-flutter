import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/service_catalog_controller.dart';
import '../widgets/service_category_rail.dart';
import '../widgets/service_zone.dart';

class ServiceCategoriesOverviewScreen extends StatefulWidget {
  const ServiceCategoriesOverviewScreen({super.key});

  @override
  State<ServiceCategoriesOverviewScreen> createState() => _ServiceCategoriesOverviewScreenState();
}

class _ServiceCategoriesOverviewScreenState extends State<ServiceCategoriesOverviewScreen> {
  final _catalog = Get.find<ServiceCatalogController>();

  @override
  void initState() {
    super.initState();
    _catalog.ensureServicesLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _catalog.refreshAll(),
              child: Obx(() {
                final loading = (_catalog.categoriesLoading.value && _catalog.categories.isEmpty) ||
                    (_catalog.servicesLoading.value && _catalog.services.isEmpty);
                if (loading) return _buildShimmer(context);
                final cats = _catalog.activeCategories;
                if (cats.isEmpty) return _buildEmpty(context);
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: cats.length,
                  itemBuilder: (_, i) => ServiceCategoryRail(
                    category: cats[i],
                    zone: serviceZoneForIndex(i),
                    items: _catalog.servicesForCategory(cats[i].id),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
              const Expanded(
                child: Text(
                  'All Services',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 16 + AppInsets.bottomViewPadding(context)),
      children: const [
        SizedBox(height: 4),
        ServiceRailShimmer(),
        ServiceRailShimmer(),
        ServiceRailShimmer(),
      ],
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
