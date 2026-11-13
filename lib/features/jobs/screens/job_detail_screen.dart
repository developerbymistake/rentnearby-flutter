import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
import '../jobs_colors.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/money_format.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../data/jobs_repository.dart';
import '../models/job_detail_model.dart';
import '../widgets/jobs_ui.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key});

  @visibleForTesting
  static Widget Function(String url)? photoOverride;
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  ListingTone get _look => JobsUi.look;
  static const double _heroHeight = 260;
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
      backgroundColor: JobsLook.pageColor,
      body: _loading ? _buildLoader() : _buildContent(),
      bottomNavigationBar: _loading || _job == null ? null : _buildActionBar(),
    );
  }

  Widget _backButton() => JobsBackButton(tone: _look, onTap: () => Get.back());

  Widget _buildLoader() {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _darkIcons,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _heroHeight + top,
                  child: Stack(children: [
                    Positioned.fill(child: TemplatePlaceholder(height: _heroHeight + top, radius: 0)),
                    _seamStrip(),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 6, 18, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SkeletonBox(height: 14, width: 120),
                    SizedBox(height: 12),
                    SkeletonBox(height: 28),
                    SizedBox(height: 18),
                    SkeletonBox(height: 330, radius: 24),
                    SizedBox(height: 24),
                    SkeletonBox(height: 110, radius: 24),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(top: top + 10, left: 16, child: _backButton()),
        ],
      ),
    );
  }

  Widget _seamStrip() => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: JobsDetailHero.seam,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: JobsLook.pageColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(JobsDetailHero.seam)),
          ),
        ),
      );

  Widget _buildContent() {
    if (_job == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: _darkIcons,
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 0), child: _backButton()),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: _notFound
                      ? JobsStateBlock(
                          tone: _look,
                          art: ListingArt.worldMap,
                          title: 'Job not found',
                          message: 'It may be closed',
                        )
                      : JobsStateBlock(
                          tone: _look,
                          art: ListingArt.compass,
                          title: "Couldn't load the job",
                          message: 'Please try again',
                          actionLabel: 'Retry',
                          onAction: _retry,
                        ),
                ),
              ),
            ),
          ]),
        ),
      );
    }
    final j = _job!;
    final top = MediaQuery.paddingOf(context).top;
    final children = <Widget>[
      if (!j.isActive)
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: JobsNoteCard(art: ListingArt.key, text: 'This job is closed'),
        ),
      Padding(padding: const EdgeInsets.only(top: 18), child: _titleRow(j)),
      Padding(padding: const EdgeInsets.only(top: 18), child: _infoCard(j)),
      if (j.description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('About this job', style: Ink3D.text(16, FontWeight.w700, Ink3D.title))),
            const SizedBox(height: 8),
            Text(j.description, style: Ink3D.text(14, FontWeight.w400, JobsLook.about, letterSpacing: 0, height: 1.6)),
          ]),
        ),
      Padding(padding: const EdgeInsets.only(top: 14), child: JobsArtLine(art: ListingArt.calendar, text: j.postedAgoLong)),
    ];
    return Stack(children: [
      CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHero(j, top)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
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
          height: top + 64,
          child: Stack(children: [
            Positioned.fill(
              child: Opacity(
                opacity: t,
                child: const DecoratedBox(decoration: BoxDecoration(color: DesignColors.surface, boxShadow: JobsLook.card3)),
              ),
            ),
            Positioned(top: top + 9, left: 18, child: _backButton()),
            Positioned(
              top: top,
              left: 78,
              right: 18,
              height: 64,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: t,
                  child: Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _titleRow(JobDetailModel j) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        JobsTagPill(tone: _look, label: 'JOB', solid: true),
        JobsTagPill(tone: _look, label: j.experienceLabel),
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final titleStyle = Ink3D.text(18, FontWeight.w700, Ink3D.title, height: 1.25);
        final salaryMax = constraints.maxWidth * 0.45;
        final salaryText = _salaryText(j);
        final salaryW = (KitText.widthOf(salaryText, Ink3D.text(19, FontWeight.w700, _look.text, letterSpacing: 0), scaler) +
                KitText.widthOf(j.salaryUnit, Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0), scaler))
            .clamp(0.0, salaryMax);
        var longest = 0.0;
        for (final w in j.title.split(RegExp(r'\s+'))) {
          final x = KitText.widthOf(w, titleStyle, scaler);
          if (x > longest) longest = x;
        }
        final titleMax = constraints.maxWidth - 60 - 18;
        final salaryBox = (titleMax - longest * 0.9).clamp(salaryW * 0.85, salaryW).toDouble();
        final stacked = longest * 0.8 > titleMax - salaryBox;
        final salary = Column(crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
          Text('SALARY', maxLines: 1, style: Ink3D.text(11, FontWeight.w600, Ink3D.grey, letterSpacing: 0.6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: stacked ? Alignment.centerLeft : Alignment.centerRight,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: salaryText),
                if (j.salaryUnit.isNotEmpty) TextSpan(text: j.salaryUnit, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ]),
              maxLines: 1,
              softWrap: false,
              style: Ink3D.text(19, FontWeight.w700, _look.text, letterSpacing: 0),
            ),
          ),
        ]);
        final title = LayoutBuilder(
          builder: (context, box) => Semantics(
            header: true,
            child: Text(j.title, style: KitText.wholeWords(j.title, titleStyle, box.maxWidth - 2, scaler)),
          ),
        );
        const art = ExcludeSemantics(child: Art3D(asset: ListingArt.briefcase, size: 52, shadowBlur: 3, shadowOffset: Offset(2, 4), shadowAlpha: 0.25));
        if (stacked) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [art, const SizedBox(width: 8), Expanded(child: title)]),
            Padding(padding: const EdgeInsets.only(top: 10, left: 60), child: salary),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Row(children: [art, const SizedBox(width: 8), Expanded(child: title)])),
          const SizedBox(width: 18),
          ConstrainedBox(constraints: BoxConstraints(maxWidth: salaryBox), child: salary),
        ]);
      }),
    ]);
  }

  static String _unitUpper(int n) {
    final b = Money.body(n);
    return b.endsWith('k') ? '${b.substring(0, b.length - 1)}K' : b;
  }

  static String _salaryText(JobDetailModel j) {
    final min = j.minSalary, max = j.maxSalary;
    if (min <= 0 && max <= 0) return j.salaryCompact;
    if (min == max || min <= 0 || max <= 0) return '${Money.symbol}${_unitUpper(max > 0 ? max : min)}';
    return '${Money.symbol}${_unitUpper(min)} - ${_unitUpper(max)}';
  }

  void _openStay(JobDetailModel j) => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': j.stayListingId});

  Widget _buildHero(JobDetailModel j, double top) {
    final url = j.coverPhotoUrl;
    final h = _heroHeight + top;
    final hasPhoto = url != null && url.isNotEmpty;
    return JobsDetailHero(
      tone: _look,
      height: h,
      onTap: j.stayListingId.isEmpty ? null : () => _openStay(j),
      photo: !hasPhoto
          ? null
          : JobDetailScreen.photoOverride?.call(url) ??
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => TemplatePlaceholder(height: h, radius: 0),
              errorWidget: (_, _, _) => DecoratedBox(decoration: BoxDecoration(gradient: _look.gradient)),
            ),
    );
  }

  Widget _infoCard(JobDetailModel j) {
    final jobTypeShift = [j.jobTypeName, j.shiftTypeName].where((e) => e.isNotEmpty).join(' · ');
    return JobsInfoCard(children: [
      JobsInfoRow(tone: _look, art: ListingArt.briefcase, label: 'Job role', value: j.roleName, divider: false),
      JobsInfoRow(
        tone: _look,
        art: ListingArt.hotel,
        label: 'Stay',
        value: j.stayName,
        onTap: j.stayListingId.isEmpty ? null : () => _openStay(j),
      ),
      JobsInfoRow(tone: _look, art: ListingArt.roundPushpin, label: 'Location', value: j.placeLabel),
      JobsInfoRow(tone: _look, art: ListingArt.mountain, label: 'Experience', value: j.experienceDetail),
      JobsInfoRow(tone: _look, art: ListingArt.sunrise, label: 'Job type · Shift', value: jobTypeShift),
      JobsInfoRow(tone: _look, art: ListingArt.moneyBag, label: 'Salary type', value: j.salaryTypeName),
    ]);
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
        safetyArt: ListingArt.clipboard,
        safetyText: 'Never pay to get a job. Visit the stay before joining.',
        onReport: reported
            ? null
            : () => ReportListingSheet.show(context, listingId: j.stayListingId, listingType: 'Stay', palette: JobColors.palette),
        palette: JobColors.palette,
      );
    });
  }
}
