import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/service_catalog_controller.dart';
import '../models/service_detail_model.dart';
import '../models/service_package_preview_model.dart';
import '../utils/service_icons.dart';
import '../widgets/max_width_content.dart';
import '../widgets/service_package_price.dart';

/// Service Detail — the one screen in this feature whose hero cover photo
/// is deliberately edge-to-edge (NOT wrapped in MaxWidthContent), per the
/// confirmed responsiveness rule. The back button overlaying it uses
/// AppInsets.topViewPadding(context), not a SafeArea wrapper, because the
/// photo itself must still paint behind the status bar.
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final _ctrl = Get.find<ServiceCatalogController>();
  ServiceDetailModel? _service;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final id = args is Map ? args['id'] as String : args as String;
    _ctrl.loadServiceDetail(id).then((s) {
      if (!mounted) return;
      setState(() {
        _service = s;
        _loading = false;
        _notFound = s == null;
      });
    }).catchError((_) {
      if (mounted) setState(() { _loading = false; _notFound = true; });
    });
  }

  void _viewAllPackages() {
    final s = _service;
    if (s == null) return;
    Get.toNamed(AppRoutes.servicePackageList, arguments: {'serviceId': s.id, 'title': s.name});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: _loading
            ? _buildLoader()
            : (_notFound || _service == null)
                ? _buildNotFound()
                : _buildContent(_service!),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: AppInsets.topViewPadding(context) + 10,
      left: 12,
      child: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Stack(
      children: [
        Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 300 + AppInsets.topViewPadding(context), color: Colors.white),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 22, width: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 14),
                    Container(height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(height: 14, width: 220, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildNotFound() {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: AppInsets.topViewPadding(context)),
            child: const Text('Service not found', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
          ),
        ),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildContent(ServiceDetailModel s) {
    // NOTE: unlike the full Package List screen (which filters
    // ServicePackageModel.isActive), this preview list can't filter on
    // active state — ServicePackagePreviewDto (the lightweight shape
    // embedded in ServiceDetailDto) has no IsActive field, and the backend's
    // GetByIdWithDetailsAsync doesn't filter its Packages include either.
    // A deactivated package will disappear from the full list but keep
    // appearing here — a known, backend-side limitation, not fixable from
    // this screen without either widening the preview DTO or an extra
    // round-trip that would defeat the point of having a lightweight
    // preview in the first place. Every seeded package is IsActive=true.
    final servicePackages = s.packages.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final previewPackages = servicePackages.take(3).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24 + AppInsets.bottomViewPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(s),
          MaxWidthContent(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.fullDescription.isEmpty ? s.shortDescription : s.fullDescription,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.6),
                  ),
                  if (previewPackages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Packages',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        Text(
                          '${servicePackages.length} available',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...previewPackages.map((p) => _PackagePreviewCard(package: p)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _viewAllPackages,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.4),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        child: const Text('View All Packages', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Text(
                        'No packages listed yet — check back soon.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(ServiceDetailModel s) {
    return Stack(
      children: [
        SizedBox(
          height: 300 + AppInsets.topViewPadding(context),
          width: double.infinity,
          child: s.coverPhotoUrl.isEmpty
              ? _heroPlaceholder(s)
              : CachedNetworkImage(
                  imageUrl: s.coverPhotoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) => _heroPlaceholder(s),
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
              ),
            ),
            child: Row(
              children: [
                Icon(serviceIconFor(s.iconName), color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.name,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBackButton(),
      ],
    );
  }

  Widget _heroPlaceholder(ServiceDetailModel s) => Container(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        child: Center(child: Icon(serviceIconFor(s.iconName), size: 56, color: AppColors.primaryLight)),
      );
}

class _PackagePreviewCard extends StatelessWidget {
  final ServicePackagePreviewModel package;
  const _PackagePreviewCard({required this.package});

  @override
  Widget build(BuildContext context) {
    String? duration;
    if (package.durationDays != null) {
      duration = (package.durationNights != null)
          ? '${package.durationDays}D/${package.durationNights}N'
          : '${package.durationDays} day${package.durationDays == 1 ? '' : 's'}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: package.thumbnailUrl.isEmpty
                  ? Container(color: AppColors.surface, child: const Icon(Icons.card_travel_rounded, color: AppColors.primaryLight, size: 22))
                  : CachedNetworkImage(
                      imageUrl: package.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surface),
                      errorWidget: (_, __, ___) => Container(color: AppColors.surface, child: const Icon(Icons.card_travel_rounded, color: AppColors.primaryLight, size: 22)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                if (duration != null) ...[
                  const SizedBox(height: 2),
                  Text(duration, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ServicePackagePrice(
            price: package.price,
            originalPrice: package.originalPrice,
            discountPercent: package.discountPercent,
            isStartingAtPrice: package.isStartingAtPrice,
            priceUnit: package.priceUnit,
            priceFontSize: 14,
            priceColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
