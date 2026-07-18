import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/service_catalog_controller.dart';
import '../models/service_category_model.dart';
import '../models/service_list_item_model.dart';
import '../utils/service_icons.dart';
import '../widgets/max_width_content.dart';
import '../widgets/service_list_row.dart';

enum ServiceCatalogListMode { categories, services }

/// The shared descriptive-list screen for both catalog steps:
///   - Category-list (Section -> its Categories): pushed as
///     [AppRoutes.serviceCategoryList], mode=categories, parentId=sectionId.
///   - Service-list (Category -> its Services): pushed as
///     [AppRoutes.serviceList], mode=services, parentId=categoryId.
/// Same descriptive-row shape either way (icon+title+one-liner+chevron,
/// confirmed NOT a grid) — only the data source and next-hop route differ.
/// Expects `Get.arguments` as a Map: {mode, parentId, title}.
class ServiceCatalogListScreen extends StatefulWidget {
  const ServiceCatalogListScreen({super.key});

  @override
  State<ServiceCatalogListScreen> createState() => _ServiceCatalogListScreenState();
}

class _ServiceCatalogListScreenState extends State<ServiceCatalogListScreen> {
  final _ctrl = Get.find<ServiceCatalogController>();
  late final ServiceCatalogListMode _mode;
  late final String _parentId;
  late final String _title;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _mode = args['mode'] == 'services' ? ServiceCatalogListMode.services : ServiceCatalogListMode.categories;
    _parentId = args['parentId'] as String? ?? '';
    _title = args['title'] as String? ?? (_mode == ServiceCatalogListMode.categories ? 'Categories' : 'Services');
  }

  List<ServiceCategoryModel> get _categoryItems => _ctrl.categoriesForSection(_parentId);
  List<ServiceListItemModel> get _serviceItems => _ctrl.servicesForCategory(_parentId);

  void _openCategory(ServiceCategoryModel category) {
    Get.toNamed(AppRoutes.serviceList, arguments: {
      'mode': 'services',
      'parentId': category.id,
      'title': category.name,
    });
  }

  void _openService(ServiceListItemModel service) {
    Get.toNamed(AppRoutes.serviceDetail, arguments: {'id': service.id});
  }

  Future<void> _refresh() => _ctrl.loadCatalog(forceRefresh: true);

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
              onRefresh: _refresh,
              child: Obx(() {
                if (_ctrl.catalogLoading.value && (_mode == ServiceCatalogListMode.categories ? _categoryItems.isEmpty : _serviceItems.isEmpty)) {
                  return _buildShimmerList();
                }
                return _mode == ServiceCatalogListMode.categories ? _buildCategoryList() : _buildServiceList();
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
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return Obx(() {
      final items = _categoryItems;
      if (items.isEmpty) return _buildEmpty('No categories here yet.');
      return MaxWidthContent(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 12, 0, 16 + AppInsets.bottomViewPadding(context)),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final c = items[i];
            return ServiceListRow(
              icon: serviceIconFor(c.iconName),
              title: c.name,
              onTap: () => _openCategory(c),
            );
          },
        ),
      );
    });
  }

  Widget _buildServiceList() {
    return Obx(() {
      final items = _serviceItems;
      if (items.isEmpty) return _buildEmpty('No services here yet.');
      return MaxWidthContent(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 12, 0, 16 + AppInsets.bottomViewPadding(context)),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final s = items[i];
            return ServiceListRow(
              icon: serviceIconFor(s.iconName),
              title: s.name,
              description: s.shortDescription,
              onTap: () => _openService(s),
            );
          },
        ),
      );
    });
  }

  Widget _buildEmpty(String text) {
    return MaxWidthContent(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Text(text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return MaxWidthContent(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(
              height: 74,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}
