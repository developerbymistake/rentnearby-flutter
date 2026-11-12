import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import '../jobs_colors.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../data/jobs_repository.dart';
import '../models/job_detail_model.dart';
import '../widgets/jobs_ui.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key});
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  static const KitTone _tone = JobsUi.tone;
  static const double _heroHeight = 260;
  static const double _seam = 24;
  static const double _fadeStart = 120;
  static const double _fadeSpan = 60;
  static const SystemUiOverlayStyle _darkIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  final _auth = Get.find<AuthController>();
  final _scroll = ScrollController();
  final _fade = ValueNotifier<double>(0);
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
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _onScroll() {
    _fade.value = ((_scroll.offset - _fadeStart) / _fadeSpan).clamp(0.0, 1.0);
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
      backgroundColor: DesignColors.scaffold,
      body: _loading ? _buildLoader() : _buildContent(),
      bottomNavigationBar: _loading || _job == null ? null : _buildActionBar(),
    );
  }

  Widget _backButton() => PressScale(
        child: SizedBox(
          width: KitMetrics.touch,
          height: KitMetrics.touch,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: DesignColors.surface,
              shape: BoxShape.circle,
              boxShadow: ShadowTokens.elev1,
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Get.back(),
                splashColor: DesignColors.splash,
                highlightColor: Colors.transparent,
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: DesignColors.textStrong),
              ),
            ),
          ),
        ),
      );

  Widget _seamStrip() => const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: _seam,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DesignColors.scaffold,
            borderRadius: BorderRadius.vertical(top: Radius.circular(CardRadius.headerValue)),
          ),
        ),
      );

  Widget _buildLoader() {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _darkIcons,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: _heroHeight + top,
                  child: Stack(children: [
                    Positioned.fill(child: TemplatePlaceholder(height: _heroHeight + top, radius: 0)),
                    _seamStrip(),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const TemplatePlaceholder(height: 14, width: 120),
                    const SizedBox(height: 12),
                    const TemplatePlaceholder(height: 28),
                    const SizedBox(height: 16),
                    SectionTile.skeleton(lines: 5),
                    const SizedBox(height: 24),
                    SectionTile.skeleton(lines: 3),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(top: top + 6, left: 16, child: _backButton()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_job == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: _darkIcons,
        child: SafeArea(
          child: Stack(children: [
            Center(
              child: _notFound
                  ? const StateCard(
                      kit: _tone,
                      asset: TravelIcon.map,
                      title: 'Job not found',
                      message: 'It may be closed',
                    )
                  : StateCard.error(
                      kit: _tone,
                      title: "Couldn't load the job",
                      message: 'Please try again',
                      actionLabel: 'Retry',
                      onAction: _retry,
                    ),
            ),
            Positioned(top: 6, left: 16, child: _backButton()),
          ]),
        ),
      );
    }
    final j = _job!;
    final top = MediaQuery.paddingOf(context).top;
    final children = <Widget>[
      if (!j.isActive)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SlimBar(
            margin: EdgeInsets.zero,
            tone: _tone,
            leading: const Icon(Icons.lock_outline_rounded, size: 22, color: DesignColors.textGrey),
            title: 'This job is closed',
          ),
        ),
      Padding(padding: const EdgeInsets.only(bottom: 16), child: _titleRow(j)),
      Padding(padding: const EdgeInsets.only(bottom: 24), child: _infoCard(j)),
      if (j.description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About this job', style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2)),
            const SizedBox(height: 8),
            Text(j.description, style: TypeTokens.style(14, FontWeight.w400, color: DesignColors.textPrimary, height: 1.6)),
          ]),
        ),
      Row(children: [
        const Icon(Icons.schedule_rounded, size: 16, color: DesignColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(j.postedAgoLong, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
        ),
      ]),
    ];
    return Stack(children: [
      CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHero(j, top)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, 24),
              child: StaggerColumn(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ],
      ),
      Positioned(top: 0, left: 0, right: 0, child: _topBar(j, top)),
    ]);
  }

  Widget _topBar(JobDetailModel j, double top) {
    return ValueListenableBuilder<double>(
      valueListenable: _fade,
      builder: (_, t, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: t < 0.5 ? ModuleHeader.lightIcons : _darkIcons,
        child: SizedBox(
          height: top + 56,
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DesignColors.tint(DesignColors.surface, t),
                  boxShadow: [ShadowTokens.tint(DesignColors.textGrey, const ShadowSpec(0.4, Offset(1.1, 1.1), 10).scaled(t))],
                ),
              ),
            ),
            Positioned(top: top + 6, left: 16, child: _backButton()),
            Positioned(
              top: top,
              left: 72,
              right: KitMetrics.gutter,
              height: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(j.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(16, FontWeight.w700,
                        color: DesignColors.tint(DesignColors.textStrong, t))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _titleRow(JobDetailModel j) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              const KitTagChip('JOB', tone: _tone, solid: true),
              KitTagChip(j.experienceLabel, tone: _tone),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TravelIcon(JobsUi.roleIcon, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(j.title,
                    style: TypeTokens.style(22, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27)),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('SALARY', maxLines: 1, style: TypeTokens.caption),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: j.salaryCompact),
                  if (j.salaryUnit.isNotEmpty) TextSpan(text: j.salaryUnit, style: TypeTokens.caption),
                ]),
                maxLines: 1,
                softWrap: false,
                style: TypeTokens.style(20, FontWeight.w800, color: _tone.accentDark),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _openStay(JobDetailModel j) => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': j.stayListingId});

  Widget _heroFallback() => DecoratedBox(
        decoration: BoxDecoration(gradient: _tone.gradient),
        child: Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.tint(DesignColors.surfaceAlt, Alpha.soft)),
            child: Center(child: TravelIcon(JobsUi.roleIcon, size: 72)),
          ),
        ),
      );

  Widget _buildHero(JobDetailModel j, double top) {
    final url = j.coverPhotoUrl;
    final h = _heroHeight + top;
    return SizedBox(
      height: h,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: j.stayListingId.isEmpty ? null : () => _openStay(j),
            child: (url != null && url.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => TemplatePlaceholder(height: h, radius: 0),
                    errorWidget: (_, _, _) => _heroFallback(),
                  )
                : _heroFallback(),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 120,
          child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: DesignGradients.scrimTop))),
        ),
        _seamStrip(),
      ]),
    );
  }

  Widget _infoCard(JobDetailModel j) {
    final jobTypeShift = [j.jobTypeName, j.shiftTypeName].where((e) => e.isNotEmpty).join(' · ');
    final rows = <Widget>[
      _infoRow(JobsUi.roleIcon, 'Job role', j.roleName),
      _infoRow(
        TravelIcon.stay,
        'Stay',
        j.stayName,
        onTap: j.stayListingId.isEmpty ? null : () => _openStay(j),
      ),
      _infoRow(TravelIcon.place, 'Location', j.placeLabel),
      _infoRow(JobsUi.experienceIcon, 'Experience', j.experienceDetail),
      _infoRow(JobsUi.shiftIcon, 'Job type · Shift', jobTypeShift),
      _infoRow(TravelIcon.money, 'Salary type', j.salaryTypeName),
    ];
    return SectionTile(
      tone: _tone,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: DesignColors.dividerSoft),
            ),
          rows[i],
        ],
      ]),
    );
  }

  Widget _infoRow(String iconAsset, String label, String value, {VoidCallback? onTap}) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KitMetrics.touch),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: KitMetrics.tileSmall,
              gradient: LinearGradient(
                colors: [DesignColors.tint(_tone.accent, Alpha.soft), DesignColors.tint(_tone.accentDark, Alpha.tint)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(child: TravelIcon(iconAsset, size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TypeTokens.caption),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '-' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(14, FontWeight.w600, color: DesignColors.textStrong)),
            ]),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 22, color: _tone.accentDark),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: KitMetrics.tileSmall,
      splashColor: DesignColors.splash,
      highlightColor: Colors.transparent,
      child: row,
    );
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
