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
import '../models/service_package_model.dart';
import '../utils/service_icons.dart';
import '../widgets/max_width_content.dart';
import '../widgets/service_package_card.dart';

/// Service Detail — the one screen in this feature whose hero cover photo
/// is deliberately edge-to-edge (NOT wrapped in MaxWidthContent), per the
/// confirmed responsiveness rule. The back button overlaying it uses
/// AppInsets.topViewPadding(context), not a SafeArea wrapper, because the
/// photo itself must still paint behind the status bar.
///
/// Every available package/plan for this service is rendered inline here
/// (no separate "View All Packages" screen) — see [ServicePackageCard].
/// "Package" vs "Plan" wording switches per Section (Expert Consultations
/// says "Plan"; every other Section, including any future one, says
/// "Package" by default).
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  static const _expertConsultationsSectionName = 'Expert Consultations';

  final _ctrl = Get.find<ServiceCatalogController>();
  ServiceDetailModel? _service;
  List<ServicePackageModel> _packages = [];
  bool _loading = true;
  bool _notFound = false;

  bool get _isPlansVertical => (_service?.serviceSectionName ?? '') == _expertConsultationsSectionName;
  String get _packagesNoun => _isPlansVertical ? 'Plan' : 'Package';

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final id = args is Map ? args['id'] as String : args as String;
    Future.wait([
      _ctrl.loadServiceDetail(id),
      _ctrl.loadPackages(id).catchError((_) => <ServicePackageModel>[]),
    ]).then((results) {
      if (!mounted) return;
      final service = results[0] as ServiceDetailModel?;
      final packages = (results[1] as List<ServicePackageModel>).where((p) => p.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setState(() {
        _service = service;
        _packages = packages;
        _loading = false;
        _notFound = service == null;
      });
    }).catchError((_) {
      if (mounted) setState(() { _loading = false; _notFound = true; });
    });
  }

  void _enquire(ServicePackageModel package) {
    final s = _service;
    if (s == null) return;
    Get.toNamed(
      AppRoutes.inquiryForm,
      arguments: {'serviceId': s.id, 'serviceName': s.name, 'package': package, 'formType': s.serviceCategoryFormType},
    );
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
                  if (_packages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_packagesNoun}s',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        Text(
                          '${_packages.length} $_packagesNoun${_packages.length == 1 ? '' : 's'} available',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._packages.map((p) => ServicePackageCard(
                          package: p,
                          onEnquire: () => _enquire(p),
                          placeholderIcon: serviceIconFor(s.iconName),
                        )),
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
                      child: Text(
                        'No ${_packagesNoun.toLowerCase()}s listed yet — check back soon.',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight),
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
