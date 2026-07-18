import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/service_catalog_controller.dart';
import '../models/service_package_model.dart';
import '../widgets/inclusion_chip.dart';
import '../widgets/max_width_content.dart';
import '../widgets/service_package_price.dart';

/// Full Package List for one Service — richer cards than the descriptive
/// list screen: thumbnail, price/"Get Custom Quote"/"Starting at ₹X" +
/// discount badge (ServicePackagePrice — same widget the Service Detail
/// preview cards use), duration, and Inclusion icon+label chips. A single
/// scrolling column (not a grid), MaxWidthContent-wrapped.
class ServicePackageListScreen extends StatefulWidget {
  const ServicePackageListScreen({super.key});

  @override
  State<ServicePackageListScreen> createState() => _ServicePackageListScreenState();
}

class _ServicePackageListScreenState extends State<ServicePackageListScreen> {
  final _ctrl = Get.find<ServiceCatalogController>();
  late final String _serviceId;
  late final String _title;
  List<ServicePackageModel> _packages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _serviceId = args['serviceId'] as String? ?? '';
    _title = args['title'] as String? ?? 'Packages';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final packages = await _ctrl.loadPackages(_serviceId);
      packages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (mounted) setState(() { _packages = packages.where((p) => p.isActive).toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enquire(ServicePackageModel package) {
    Get.toNamed(
      AppRoutes.inquiryForm,
      arguments: {'serviceId': _serviceId, 'serviceName': _title, 'package': package},
    );
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
              onRefresh: _load,
              child: _loading ? _buildShimmer() : _buildList(),
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

  Widget _buildList() {
    if (_packages.isEmpty) {
      return MaxWidthContent(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const Center(
              child: Text('No packages available right now.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
            ),
          ],
        ),
      );
    }
    return MaxWidthContent(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
        itemCount: _packages.length,
        itemBuilder: (_, i) => _PackageCard(package: _packages[i], onEnquire: () => _enquire(_packages[i])),
      ),
    );
  }

  Widget _buildShimmer() {
    return MaxWidthContent(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(
              height: 190,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final ServicePackageModel package;
  final VoidCallback onEnquire;
  const _PackageCard({required this.package, required this.onEnquire});

  @override
  Widget build(BuildContext context) {
    String? duration;
    if (package.durationDays != null) {
      duration = (package.durationNights != null)
          ? '${package.durationDays}D/${package.durationNights}N'
          : '${package.durationDays} day${package.durationDays == 1 ? '' : 's'}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (package.thumbnailUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: CachedNetworkImage(
                imageUrl: package.thumbnailUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(height: 140, color: AppColors.surface),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  package.name,
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                                ),
                              ),
                              if (package.isFeatured)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('POPULAR', style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                            ],
                          ),
                          if (duration != null) ...[
                            const SizedBox(height: 3),
                            Text(duration, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ServicePackagePrice(
                  price: package.price,
                  originalPrice: package.originalPrice,
                  discountPercent: package.discountPercent,
                  isStartingAtPrice: package.isStartingAtPrice,
                  priceUnit: package.priceUnit,
                ),
                if (package.inclusions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: package.inclusions
                        .where((i) => i.isActive)
                        .map((i) => InclusionChip(iconName: i.iconName, label: i.name))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onEnquire,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      package.price == null ? 'Get Quote' : 'Enquire Now',
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
