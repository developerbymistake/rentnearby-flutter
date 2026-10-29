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
import '../../../widgets/detail_header.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../data/jobs_repository.dart';
import '../jobs_colors.dart';
import '../models/job_detail_model.dart';

const _kAccent = JobColors.accent;
const _kAccentDark = JobColors.accentDark;
const _kGradient = JobColors.gradient;
const _kHeroFallback = DecoratedBox(
  decoration: BoxDecoration(gradient: _kGradient),
  child: Center(child: Icon(Iconsax.briefcase, size: 56, color: Colors.white)),
);
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
          child: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 18),
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
                    Container(height: 240 + MediaQuery.of(context).padding.top, color: Colors.white),
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
          expandedHeight: 240,
          pinned: true,
          backgroundColor: _kAccent,
          leading: _backButton(margin: const EdgeInsets.all(8)),
          flexibleSpace: FlexibleSpaceBar(background: _buildHero(j)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!j.isActive) ...[
                _closedBanner(),
                const SizedBox(height: 12),
              ],
              DetailTitleRow(
                accent: _kAccent,
                tag: 'JOB',
                secondTag: j.experienceLabel,
                icon: Iconsax.briefcase,
                title: j.title,
                caption: 'SALARY',
                value: j.salaryCompact,
                unit: j.salaryUnit,
              ),
              const SizedBox(height: 16),
              _infoCard(j),
              if (j.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle('About this job'),
                const SizedBox(height: 8),
                Text(j.description,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Iconsax.clock, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(j.postedAgoLong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
                ),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  void _openStay(JobDetailModel j) => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': j.stayListingId});

  Widget _buildHero(JobDetailModel j) {
    final url = j.coverPhotoUrl;
    return GestureDetector(
      onTap: j.stayListingId.isEmpty ? null : () => _openStay(j),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: AppColors.shimmerBase),
              errorWidget: (_, _, _) => _kHeroFallback,
            )
          else
            _kHeroFallback,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.black45, Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.divider.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
        child: const Text('This job is closed',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      );

  Widget _infoCard(JobDetailModel j) {
    final jobTypeShift = [j.jobTypeName, j.shiftTypeName].where((e) => e.isNotEmpty).join(' · ');
    final rows = <Widget>[
      _infoRow(Iconsax.briefcase, 'Job role', j.roleName),
      _infoRow(
        Iconsax.house_2,
        'Stay',
        j.stayName,
        onTap: j.stayListingId.isEmpty ? null : () => _openStay(j),
      ),
      _infoRow(Iconsax.location, 'Location', j.placeLabel),
      _infoRow(Iconsax.timer_1, 'Experience', j.experienceDetail),
      _infoRow(Iconsax.clock, 'Job type · Shift', jobTypeShift),
      _infoRow(Iconsax.wallet_3, 'Salary type', j.salaryTypeName),
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

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark));

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final row = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: _kAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
            const SizedBox(height: 2),
            Text(value.isEmpty ? '-' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ]),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          const Icon(Iconsax.arrow_right_3, size: 16, color: _kAccentDark),
        ],
      ],
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: row);
  }

  Widget? _buildActionBar() {
    if (_isOwner) return null;
    final j = _job!;
    final reportCtrl = Get.find<ReportController>();
    final canContact = j.isActive && j.hasContact;
    return Obx(() {
      final reported = reportCtrl.reportedListingIds.contains(j.stayListingId) || j.hasReportedStay;
      return DetailActionBar(
        ownerPhone: canContact ? j.contactPhone : null,
        whatsAppPhone: canContact ? j.whatsAppOrPhone : null,
        isOwner: false,
        showDirections: false,
        callLabel: 'Call',
        reportLabel: 'Report this stay',
        safetyText: 'Never pay to get a job. Visit the stay before joining.',
        onReport: reported
            ? null
            : () => ReportListingSheet.show(context, listingId: j.stayListingId, listingType: 'Stay', palette: JobColors.palette),
        palette: JobColors.palette,
      );
    });
  }
}
