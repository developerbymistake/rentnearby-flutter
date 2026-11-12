import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/taxi_setup_kit.dart';
import '../../../design/extra/trip_plan_look.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../models/taxi_detail_model.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';

const _kDivider = Padding(
  padding: EdgeInsets.symmetric(vertical: 10),
  child: Divider(height: 1, color: DesignColors.dividerSoft),
);

class TaxiDetailScreen extends StatefulWidget {
  const TaxiDetailScreen({super.key});
  @override
  State<TaxiDetailScreen> createState() => _TaxiDetailScreenState();
}

class _TaxiDetailScreenState extends State<TaxiDetailScreen> with TickerProviderStateMixin {
  final _auth = Get.find<AuthController>();
  final _isSharing = false.obs;
  late final AnimationController _anim = SetupKit.controller(this);
  late final String _id;
  int? _matchedFare;
  String? _matchedToName;
  String? _whatsAppMessage;
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
      _whatsAppMessage = args['whatsAppMessage'] as String?;
    } else {
      _id = args as String;
    }
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _loaded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context, restart: true);
    });
  }

  void _retry() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await const TaxiBrowseRepository().getById(_id);
      if (mounted) {
        setState(() {
          _taxi = t;
          _notFound = false;
          _loading = false;
        });
        _loaded();
      }
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (status != 401 && status != 404) AppToast.error(DioErrorMapper.toMessage(e, 'Could not load the taxi.'));
      if (mounted) {
        setState(() {
          _notFound = status == 404;
          _loading = false;
        });
        _loaded();
      }
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
        photoUrl: null,
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
      backgroundColor: DesignColors.scaffold,
      body: Stack(children: [
        _loading ? _buildLoader() : _buildContent(),
        Obx(() => _isSharing.value ? const SetupBusy(message: 'Sharing...') : const SizedBox.shrink()),
      ]),
      bottomNavigationBar: _loading || _taxi == null ? null : _buildActionBar(),
    );
  }

  Widget _backButton({EdgeInsets margin = EdgeInsets.zero}) => GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: margin,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: FitnessAppTheme.nearlyBlack.withValues(alpha: Alpha.soft), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: FitnessAppTheme.white, size: 18),
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
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TemplatePlaceholder(height: 220 + MediaQuery.of(context).padding.top, radius: 0),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TemplatePlaceholder(height: 28, radius: 8),
                      SizedBox(height: 16),
                      TemplatePlaceholder(height: 140, radius: 8),
                      SizedBox(height: 16),
                      TemplatePlaceholder(height: 120, radius: 8),
                    ]),
                  ),
                ],
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
          TemplateEntrance(
            animation: templateInterval(_anim, 0, 1),
            animationController: _anim,
            child: _notFound
                ? const StateCard(
                    title: 'Taxi not found',
                    message: 'It may be offline now',
                    kit: KitTone.taxi,
                    asset: TravelIcon.taxi,
                  )
                : StateCard.error(
                    title: "Couldn't load the taxi",
                    message: 'Please try again',
                    kit: KitTone.taxi,
                    actionLabel: 'Retry',
                    onAction: _retry,
                  ),
          ),
          Positioned(top: 8, left: 8, child: _backButton()),
        ]),
      );
    }
    final t = _taxi!;
    final matched = _matchedFare != null && _matchedToName != null;
    final category = TaxiOptionSets.categoryLabel(t.vehicleCategory);
    final sections = <Widget>[
      if (_isOwner && !t.isAvailable) _banner('Hidden from search'),
      _titleBlock(
        title: '${t.driverName} · ${category.isNotEmpty ? category : t.vehicleTypeName}',
        caption: matched ? 'TO ${_matchedToName!.toUpperCase()}' : 'FROM',
        value: matched ? BrowseItem.inr(_matchedFare!) : (t.minFare != null ? BrowseItem.inr(t.minFare!) : 'On request'),
      ),
      _vehicleCard(t),
      if (t.routes.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Routes and fares'),
          const SizedBox(height: 8),
          _routesCard(t),
        ]),
      Row(children: [
        const Icon(Icons.schedule_rounded, size: 16, color: FitnessAppTheme.deactivatedText),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Posted ${_timeAgo(t.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TripKit.text(12, color: FitnessAppTheme.deactivatedText)),
        ),
      ]),
    ];
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: KitTone.taxi.accent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DesignColors.scaffold,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SizedBox(height: 24, width: double.infinity),
            ),
          ),
          leading: _backButton(margin: const EdgeInsets.all(8)),
          actions: [
            if (!_isOwner && t.slug != null)
              GestureDetector(
                onTap: () => _share(t),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: FitnessAppTheme.nearlyBlack.withValues(alpha: Alpha.soft), borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ios_share_rounded, color: FitnessAppTheme.white, size: 18),
                      const SizedBox(width: 6),
                      Text('Share', style: TripKit.text(13, weight: FontWeight.w600, color: FitnessAppTheme.white)),
                    ],
                  ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(gradient: KitTone.taxi.gradient),
              child: FadeTransition(
                opacity: templateInterval(_anim, 0, 2),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.soft), shape: BoxShape.circle),
                    child: Image.asset(TaxiVehicleIcon.assetFor(t.vehicleTypeName)),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                TemplateEntrance(
                  animation: templateInterval(_anim, i, sections.length),
                  animationController: _anim,
                  child: sections[i],
                ),
              ],
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _titleBlock({required String title, required String caption, required String value}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: KitTone.taxi.accentDark, borderRadius: BorderRadius.circular(8)),
                child: Text('TAXI',
                    style: TripKit.text(10, weight: FontWeight.w800, color: FitnessAppTheme.white)
                        .copyWith(letterSpacing: 0.6)),
              ),
              const SizedBox(width: 8),
              TravelIcon(TaxiVehicleIcon.assetFor(_taxi?.vehicleTypeName), size: 22),
            ]),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TripKit.text(22, weight: FontWeight.w700).copyWith(letterSpacing: 0.27)),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TripKit.text(11, weight: FontWeight.w600, color: FitnessAppTheme.lightText)),
          ),
          Text(value, style: TripKit.text(24, color: PickKit.gold)),
        ]),
      ]);

  Widget _banner(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: TripLook.neutralChip, borderRadius: BorderRadius.circular(24)),
        child: Text(text, style: TripKit.text(13, weight: FontWeight.w600, color: FitnessAppTheme.grey)),
      );

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.elev2,
      );

  String _baseCity(TaxiDetailModel t) =>
      t.cityName?.isNotEmpty == true ? t.cityName! : (t.districtName?.isNotEmpty == true ? t.districtName! : '');

  Widget _vehicleCard(TaxiDetailModel t) {
    final rows = <Widget>[
      if (t.plateDisplay.isNotEmpty) _infoRow(TravelIcon.note, 'Number plate', t.plateDisplay),
      if (t.seats != null) _infoRow(TaxiSetupKit.car, 'Seats', '${TaxiOptionSets.seatsLabel(t.seats!)} seats'),
      _infoRow(TravelIcon.place, 'Base', _baseCity(t)),
      if (t.localDayRate != null)
        _infoRow(TravelIcon.route, 'Local sightseeing',
            '${TaxiOptionSets.localRateLabel(t.localDayRate!)}${t.localDayKm != null ? ' · ${t.localDayKm} km/day' : ''}'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Vehicle'),
        const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) _kDivider,
          rows[i],
        ],
      ]),
    );
  }

  bool _isMatchedRoute(TaxiRouteModel r) {
    final to = _matchedToName;
    if (to == null || _matchedFare != r.fare) return false;
    final key = to.trim().toLowerCase();
    return r.toName.trim().toLowerCase() == key || r.fromName.trim().toLowerCase() == key;
  }

  Widget _routesCard(TaxiDetailModel t) {
    final matchIndex = t.routes.indexWhere(_isMatchedRoute);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Column(children: [
        for (var i = 0; i < t.routes.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: DesignColors.dividerSoft),
          _routeRow(t.routes[i], highlight: i == matchIndex),
        ],
      ]),
    );
  }

  Widget _routeRow(TaxiRouteModel r, {required bool highlight}) {
    return Container(
      color: highlight ? KitTone.taxi.tint : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.fromName} to ${r.toName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TripKit.text(14, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(TaxiOptionSets.tripLabel(r.tripType),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TripKit.text(11, color: FitnessAppTheme.lightText)),
            ]),
          ),
          const SizedBox(width: 12),
          Text(BrowseItem.inr(r.fare), style: TripKit.text(15, weight: FontWeight.w800, color: PickKit.gold)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong));

  Widget _infoRow(String asset, String label, String value) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: KitTone.taxi.gradient,
              boxShadow: ShadowTokens.elev1,
            ),
            child: Image.asset(asset),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TripKit.text(11, color: FitnessAppTheme.lightText)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '-' : value, style: TripKit.text(14)),
            ]),
          ),
        ],
      );

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    String unit(int n, String word) => '$n $word${n == 1 ? '' : 's'} ago';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return unit(diff.inMinutes, 'minute');
    if (diff.inDays < 1) return unit(diff.inHours, 'hour');
    if (diff.inDays < 7) return unit(diff.inDays, 'day');
    if (diff.inDays < 30) return unit(diff.inDays ~/ 7, 'week');
    if (diff.inDays < 365) return unit(diff.inDays ~/ 30, 'month');
    return unit(diff.inDays ~/ 365, 'year');
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
        whatsAppMessage: _whatsAppMessage,
        isOwner: false,
        showDirections: false,
        callLabel: 'Call Driver',
        reportLabel: 'Report this listing',
        safetyText: TaxiOptionSets.safetyLine,
        onReport: (t.hasReported || reportedLocally)
            ? null
            : () => ReportListingSheet.show(context, listingId: t.id, listingType: 'Taxi', palette: templateModulePalette),
        palette: templateTaxiPalette,
      );
    });
  }
}
