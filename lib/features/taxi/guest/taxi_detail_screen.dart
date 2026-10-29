import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/detail_header.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../models/taxi_detail_model.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';

const _kDivider = Padding(
  padding: EdgeInsets.symmetric(vertical: 10),
  child: Divider(height: 1, color: AppColors.divider),
);

class TaxiDetailScreen extends StatefulWidget {
  const TaxiDetailScreen({super.key});
  @override
  State<TaxiDetailScreen> createState() => _TaxiDetailScreenState();
}

class _TaxiDetailScreenState extends State<TaxiDetailScreen> {
  final _auth = Get.find<AuthController>();
  final _isSharing = false.obs;
  late final String _id;
  int? _matchedFare;
  String? _matchedToName;
  TaxiDetailModel? _taxi;
  bool _loading = true;
  bool _notFound = false;

  bool get _isOwner => _taxi != null && _auth.user.value?.id == _taxi!.userId;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _id = args['id'] as String;
      final fare = args['matchedFare'];
      _matchedFare = fare is num ? fare.toInt() : null;
      final to = args['matchedToName'];
      _matchedToName = to is String && to.isNotEmpty ? to : null;
    } else {
      _id = args as String;
    }
    _load();
  }

  void _retry() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await const TaxiBrowseRepository().getById(_id);
      if (mounted) setState(() { _taxi = t; _notFound = false; _loading = false; });
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (status != 401 && status != 404) AppToast.error(DioErrorMapper.toMessage(e, 'Could not load the taxi.'));
      if (mounted) setState(() { _notFound = status == 404; _loading = false; });
    }
  }

  Future<void> _share(TaxiDetailModel t) async {
    if (_isSharing.value) return;
    _isSharing.value = true;
    try {
      await shareListing(
        context: context,
        type: 't',
        slug: t.slug!,
        photoUrl: t.platePhotoUrl,
        priceOrArea: t.minFare != null ? 'From ${BrowseItem.inr(t.minFare!)}' : 'Local taxi',
        typeLabel: t.vehicleTypeName,
        locality: t.locality,
      );
    } finally {
      _isSharing.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Obx(() => AppLoadingOverlay(
            isLoading: _isSharing.value,
            message: 'Sharing...',
            child: _loading ? _buildLoader() : _buildContent(),
          )),
      bottomNavigationBar: _loading || _taxi == null ? null : _buildActionBar(),
    );
  }

  Widget _backButton({EdgeInsets margin = EdgeInsets.zero}) => GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: margin,
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      );

  Widget _buildLoader() => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Stack(
          children: [
            Shimmer.fromColors(
              baseColor: AppColors.shimmerBase,
              highlightColor: AppColors.shimmerHighlight,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 300 + MediaQuery.of(context).padding.top, color: Colors.white),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                            height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                        const SizedBox(height: 16),
                        Container(
                            height: 140,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                        const SizedBox(height: 16),
                        Container(
                            height: 120,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(top: MediaQuery.of(context).padding.top + 8, left: 8, child: _backButton()),
          ],
        ),
      );

  Widget _buildContent() {
    if (_taxi == null) {
      return SafeArea(
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_notFound ? 'Taxi not found' : "Couldn't load the taxi",
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(_notFound ? 'It may be offline now' : 'Please try again',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              if (!_notFound) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  child: GradientButton(
                    label: 'Retry',
                    height: 42,
                    gradient: TaxiColors.gradient,
                    shadowColor: TaxiColors.accent,
                    onPressed: _retry,
                  ),
                ),
              ],
            ]),
          ),
          Positioned(top: 8, left: 8, child: _backButton()),
        ]),
      );
    }
    final t = _taxi!;
    final matched = _matchedFare != null && _matchedToName != null;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: TaxiColors.accent,
          leading: _backButton(margin: const EdgeInsets.all(8)),
          actions: [
            if (!_isOwner && t.slug != null)
              GestureDetector(
                onTap: () => _share(t),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Share',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: t.platePhotoUrl == null
                ? Container(
                    decoration: BoxDecoration(gradient: TaxiColors.gradient),
                    child: const Center(child: Icon(Iconsax.car, size: 80, color: Colors.white38)),
                  )
                : CachedNetworkImage(
                    imageUrl: t.platePhotoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(decoration: BoxDecoration(gradient: TaxiColors.gradient)),
                    errorWidget: (ctx, url, err) => Container(
                      decoration: BoxDecoration(gradient: TaxiColors.gradient),
                      child: const Icon(Iconsax.car, size: 64, color: Colors.white38),
                    ),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_isOwner && !t.isAvailable) ...[
                _banner('Hidden from search'),
                const SizedBox(height: 12),
              ],
              DetailTitleRow(
                accent: TaxiColors.accent,
                tag: 'TAXI',
                icon: Iconsax.car,
                title: '${t.driverName} · ${t.vehicleTypeName}',
                caption: matched ? 'TO ${_short(_matchedToName!).toUpperCase()}' : 'FROM',
                value: matched
                    ? BrowseItem.inr(_matchedFare!)
                    : (t.minFare != null ? BrowseItem.inr(t.minFare!) : 'On request'),
              ),
              if (t.locality.isNotEmpty) ...[
                const SizedBox(height: 12),
                DetailChipRow(accent: TaxiColors.accentDark, icon: Iconsax.location, label: t.locality),
              ],
              const SizedBox(height: 16),
              _sectionTitle('Vehicle'),
              const SizedBox(height: 8),
              _vehicleCard(t),
              if (t.routes.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle('Routes and fares'),
                const SizedBox(height: 8),
                _routesCard(t.routes),
              ],
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('Posted ${_timeAgo(t.createdAt)}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _banner(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.divider.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      );

  Widget _card(List<Widget> rows) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.06, blur: 12, offset: const Offset(0, 4)),
        ),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) _kDivider,
            rows[i],
          ],
        ]),
      );

  Widget _vehicleCard(TaxiDetailModel t) {
    final category = TaxiOptionSets.categoryLabel(t.vehicleCategory);
    return _card([
      _infoRow(Iconsax.car, 'Vehicle', [t.vehicleTypeName, if (category.isNotEmpty) category].join(' · ')),
      if (t.plateDisplay.isNotEmpty) _infoRow(Iconsax.card, 'Number plate', t.plateDisplay),
      if (t.seats != null) _infoRow(Iconsax.people, 'Seats', '${TaxiOptionSets.seatsLabel(t.seats!)} seats'),
      _infoRow(Iconsax.location, 'Base', t.locality.isEmpty ? '-' : t.locality),
      Row(children: [
        const Icon(Icons.verified_outlined, size: 18, color: AppColors.success),
        const SizedBox(width: 12),
        Text(TaxiOptionSets.plateCheckedLabel,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
      ]),
    ]);
  }

  Widget _routesCard(List<TaxiRouteModel> routes) => _card([for (final r in routes) _routeRow(r)]);

  Widget _routeRow(TaxiRouteModel r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Iconsax.routing, size: 18, color: TaxiColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.fromName} → ${r.toName}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(TaxiOptionSets.tripLabel(r.tripType),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(BrowseItem.inr(r.fare),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.gold)),
      ],
    );
  }

  static String _short(String s) => s.length > 16 ? '${s.substring(0, 15)}…' : s;

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark));

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: TaxiColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
            ]),
          ),
        ],
      );

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  Widget? _buildActionBar() {
    if (_isOwner) return null;
    final t = _taxi!;
    final reportCtrl = Get.find<ReportController>();
    return Obx(() {
      final reportedLocally = reportCtrl.reportedListingIds.contains(t.id);
      return DetailActionBar(
        ownerPhone: t.hasContact ? t.contactPhone : null,
        whatsAppPhone: t.hasContact ? (t.whatsAppNumber ?? t.contactPhone) : null,
        isOwner: false,
        showDirections: false,
        callLabel: 'Call Driver',
        reportLabel: 'Report this listing',
        safetyText: TaxiOptionSets.safetyLine,
        onReport: (t.hasReported || reportedLocally)
            ? null
            : () => ReportListingSheet.show(context, listingId: t.id, listingType: 'Taxi'),
        accent: TaxiColors.accent,
      );
    });
  }
}
