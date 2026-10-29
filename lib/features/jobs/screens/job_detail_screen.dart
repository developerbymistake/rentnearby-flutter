import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_shadows.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../data/jobs_repository.dart';
import '../models/job_detail_model.dart';

const _kAccent = StayColors.accent;
const _kAccentDark = StayColors.accentDark;
const _kGradient = StayColors.gradient;
const _kDivider = Padding(
  padding: EdgeInsets.symmetric(vertical: 10),
  child: Divider(height: 1, color: AppColors.divider),
);

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key});
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _auth = Get.find<AuthController>();
  late final String _id;
  JobDetailModel? _job;
  bool _loading = true;
  bool _notFound = false;

  bool get _isOwner => _job != null && (_job!.isOwner || _auth.user.value?.id == _job!.ownerUserId);

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _id = args is Map ? args['id'] as String : args as String;
    _load();
  }

  void _retry() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await const JobsRepository().getById(_id);
      if (mounted) setState(() { _job = j; _loading = false; });
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (status != 401 && status != 404) AppToast.error(DioErrorMapper.toMessage(e, 'Could not load the job.'));
      if (mounted) setState(() { _notFound = status == 404; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: _loading ? _buildLoader() : _buildContent(),
      bottomNavigationBar: _loading || _job == null ? null : _buildActionBar(),
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
                    Container(height: 260 + MediaQuery.of(context).padding.top, color: Colors.white),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                            height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
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
    if (_job == null) {
      return SafeArea(
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_notFound ? 'Job not found' : "Couldn't load the job",
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(_notFound ? 'It may be closed' : 'Please try again',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              if (!_notFound) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  child: GradientButton(
                    label: 'Retry',
                    height: 42,
                    gradient: _kGradient,
                    shadowColor: _kAccent,
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
    final j = _job!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: _kAccent,
          leading: _backButton(margin: const EdgeInsets.all(8)),
          flexibleSpace: FlexibleSpaceBar(
            background: j.coverPhotoUrl == null
                ? Container(
                    decoration: const BoxDecoration(gradient: _kGradient),
                    child: const Center(child: Icon(Iconsax.briefcase, size: 80, color: Colors.white38)),
                  )
                : CachedNetworkImage(
                    imageUrl: j.coverPhotoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(color: AppColors.surface),
                    errorWidget: (ctx, url, err) => Container(
                      color: AppColors.surface,
                      child: const Icon(Icons.broken_image_rounded, size: 48, color: AppColors.textHint),
                    ),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!j.isActive) ...[
                _closedBanner(),
                const SizedBox(height: 12),
              ],
              Text(j.title,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (j.roleName.isNotEmpty) _chip(Iconsax.user_tag, j.roleName),
                if (j.departmentName.isNotEmpty) _chip(Iconsax.briefcase, j.departmentName),
                _chip(Iconsax.medal_star, j.experienceLabel),
              ]),
              const SizedBox(height: 16),
              _salaryBlock(j),
              const SizedBox(height: 16),
              _infoCard(j),
              if (j.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle('About this job'),
                const SizedBox(height: 8),
                Text(j.description,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
              ],
              const SizedBox(height: 24),
              _sectionTitle('About the stay'),
              const SizedBox(height: 8),
              _stayCard(j),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('Posted ${_timeAgo(j.createdAt)}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _closedBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.divider.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
        child: const Text('This job is closed',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      );

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: _kAccentDark),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: _kAccentDark)),
        ]),
      );

  Widget _salaryBlock(JobDetailModel j) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StayColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SALARY',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textLight)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: j.salaryLabel),
              if (j.salaryUnit.isNotEmpty)
                TextSpan(text: ' ${j.salaryUnit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold),
          ),
        ]),
      );

  Widget _infoCard(JobDetailModel j) {
    final rows = <Widget>[
      _infoRow(Iconsax.medal_star, 'Experience', j.experienceDetail),
      _infoRow(Iconsax.briefcase, 'Job type', j.jobTypeName),
      _infoRow(Iconsax.clock, 'Shift', j.shiftTypeName),
      _infoRow(Iconsax.money, 'Salary type', j.salaryTypeName),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.premium(_kAccent, alpha: 0.06, blur: 12, offset: const Offset(0, 4)),
      ),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) _kDivider,
          rows[i],
        ],
      ]),
    );
  }

  Widget _stayCard(JobDetailModel j) {
    final subtitle = [j.stayTypeName, j.placeLabel].where((e) => e != null && e.isNotEmpty).join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': j.stayListingId}),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(_kAccent, alpha: 0.06, blur: 12, offset: const Offset(0, 4)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: _kGradient, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Iconsax.building_4, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.stayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark));

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
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
    final j = _job!;
    final reportCtrl = Get.find<ReportController>();
    return Obx(() => DetailActionBar(
          ownerPhone: j.hasContact ? j.contactPhone : null,
          whatsAppPhone: j.hasContact ? j.whatsAppOrPhone : null,
          isOwner: false,
          showDirections: false,
          callLabel: 'Call',
          reportLabel: 'Report this stay',
          safetyText: 'Never pay to get a job. Visit the stay before joining.',
          onReport: (j.hasReportedStay || reportCtrl.reportedListingIds.contains(j.stayListingId))
              ? null
              : () => ReportListingSheet.show(context, listingId: j.stayListingId, listingType: 'Stay'),
          accent: _kAccent,
        ));
  }
}
