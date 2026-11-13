import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_details.dart';
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

final _kTone = ListingTone.coral;
final _kPage = ListingPalette.coral.page;
final _kRouteTones = [ListingTone.cB, ListingTone.cD, ListingTone.cC];

class TaxiDetailScreen extends StatefulWidget {
  const TaxiDetailScreen({super.key});
  @override
  State<TaxiDetailScreen> createState() => _TaxiDetailScreenState();
}

class _TaxiDetailScreenState extends State<TaxiDetailScreen> with TickerProviderStateMixin {
  final _auth = Get.find<AuthController>();
  final _isSharing = false.obs;
  late final AnimationController _anim;
  late final String _id;
  int? _matchedFare;
  String? _matchedToName;
  String? _whatsAppMessage;
  TaxiDetailModel? _taxi;
  bool _loading = true;
  bool _notFound = false;
  final _scroll = ScrollController();
  final _barOn = ValueNotifier<bool>(false);

  bool get _isOwner => _taxi != null && _auth.user.value?.id == _taxi!.userId;

  double _heroHeight(BuildContext context) => 242 + MediaQuery.paddingOf(context).top;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final on = _scroll.offset > _heroHeight(context) - DetailTopBar.heightOf(context) - 26;
    if (on != _barOn.value) _barOn.value = on;
  }

  @override
  void initState() {
    super.initState();
    _anim = SetupKit.controller(this);
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
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _barOn.dispose();
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
      if (status != 401 && status != 404) {
        final message = DioErrorMapper.toMessage(e, 'Could not load the taxi.');
        if (!ToastLane.showInHost(ToastKind.error, message)) AppToast.error(message);
      }
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
    return Stack(children: [
      Scaffold(
      backgroundColor: _kPage,
      body: Stack(children: [
        Column(children: [
          ToastSlot(
            margin: EdgeInsets.fromLTRB(
                18, !_loading && _taxi != null ? DetailTopBar.heightOf(context) + 14 : MediaQuery.paddingOf(context).top + 64, 18, 0),
          ),
          Expanded(child: _loading ? _buildLoader() : _buildContent()),
        ]),
        if (!_loading && _taxi != null) _topBar(_taxi!) else _backAt(context, strong: _taxi == null && !_loading),
      ]),
      bottomNavigationBar: _loading || _taxi == null ? null : _buildActionBar(),
      ),
      Obx(() => _isSharing.value ? Positioned.fill(child: DetailSharingOverlay(tone: _kTone)) : const SizedBox.shrink()),
    ]);
  }

  Widget _backAt(BuildContext context, {bool strong = false}) => Positioned(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 14,
        child: DetailGlassButton(onTap: () => Get.back(), dark: true, strong: strong),
      );

  Widget _buildLoader() => KitStatusBar(
        lightIcons: false,
        child: Stack(children: [
          DetailSkeleton(heroHeight: _heroHeight(context), taxi: true),
        ]),
      );

  Widget _buildContent() {
    if (_taxi == null) {
      return KitStatusBar(
        lightIcons: false,
        child: Stack(children: [
          Positioned.fill(
            child: TemplateEntrance(
              animation: templateInterval(_anim, 0, 1),
              animationController: _anim,
              child: _notFound
                  ? DetailStateView(
                      tone: _kTone,
                      art: ListingArt.taxi,
                      title: 'Taxi not found',
                      message: 'It may be offline now',
                    )
                  : DetailStateView(
                      tone: _kTone,
                      art: ListingArt.taxi,
                      title: "Couldn't load the taxi",
                      message: 'Please try again',
                      actionLabel: 'Retry',
                      onAction: _retry,
                    ),
            ),
          ),
        ]),
      );
    }
    final t = _taxi!;
    final matched = _matchedFare != null && _matchedToName != null;
    final category = TaxiOptionSets.categoryLabel(t.vehicleCategory);
    final kind = (category.isNotEmpty ? category : t.vehicleTypeName).replaceAll(' ', ' ');
    final sections = <Widget>[
      if (_isOwner && !t.isAvailable) const DetailHiddenBanner(text: 'Hidden from search'),
      DetailTitleCard(
        tone: _kTone,
        eyebrow: 'TAXI',
        title: '${t.driverName} · $kind',
        caption: matched ? 'TO ${_matchedToName!.toUpperCase()}' : 'FROM',
        value: matched ? BrowseItem.inr(_matchedFare!) : (t.minFare != null ? BrowseItem.inr(t.minFare!) : 'On request'),
        compact: true,
      ),
      _vehicleCard(t),
      if (t.routes.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const TitleRow3D(title: 'Routes and fares'),
          ..._routeCards(t),
        ]),
      DetailPosted(text: 'Posted ${_timeAgo(t.createdAt)}'),
    ];
    return KitStatusBar(
      child: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _hero(t),
              for (var i = 0; i < sections.length; i++)
                TemplateEntrance(
                  animation: templateInterval(_anim, i, sections.length),
                  animationController: _anim,
                  child: sections[i],
                ),
              const SizedBox(height: 28),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _topBar(TaxiDetailModel t) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: ValueListenableBuilder<bool>(
          valueListenable: _barOn,
          builder: (context, on, _) => DetailTopBar(
            tone: _kTone,
            coloured: true,
            showBackground: on,
            onBack: () => Get.back(),
            onShare: !_isOwner && t.slug != null ? () => _share(t) : null,
          ),
        ),
      );

  Widget _hero(TaxiDetailModel t) => SizedBox(
        height: _heroHeight(context),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: DetailHeroArt(tone: _kTone, art: TaxiVehicleIcon.assetFor(t.vehicleTypeName))),
          Positioned(left: 0, right: 0, bottom: -1, child: DetailEdge(page: _kPage)),
        ]),
      );

  String _baseCity(TaxiDetailModel t) =>
      t.cityName?.isNotEmpty == true ? t.cityName! : (t.districtName?.isNotEmpty == true ? t.districtName! : '');

  Widget _vehicleCard(TaxiDetailModel t) {
    final rows = <DetailInfo>[
      if (t.plateDisplay.isNotEmpty) DetailInfo(ListingArt.clipboard, 'Number plate', t.plateDisplay),
      if (t.seats != null) DetailInfo(DetailArt.automobile, 'Seats', '${TaxiOptionSets.seatsLabel(t.seats!)} seats'),
      DetailInfo(ListingArt.roundPushpin, 'Base', _baseCity(t)),
      if (t.localDayRate != null)
        DetailInfo(ListingArt.worldMap, 'Local sightseeing',
            '${TaxiOptionSets.localRateLabel(t.localDayRate!)}${t.localDayKm != null ? ' · ${t.localDayKm} km/day' : ''}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const TitleRow3D(title: 'Vehicle'),
      DetailInfoCard(tone: _kTone, rows: rows, top: 0),
    ]);
  }

  bool _isMatchedRoute(TaxiRouteModel r) {
    final to = _matchedToName;
    if (to == null || _matchedFare != r.fare) return false;
    final key = to.trim().toLowerCase();
    return r.toName.trim().toLowerCase() == key || r.fromName.trim().toLowerCase() == key;
  }

  List<Widget> _routeCards(TaxiDetailModel t) {
    final matchIndex = t.routes.indexWhere(_isMatchedRoute);
    return [
      for (var i = 0; i < t.routes.length; i++)
        DetailSlimCard(
          tone: i == matchIndex ? ListingTone.cA : _kRouteTones[i % _kRouteTones.length],
          art: ListingArt.roundPushpin,
          title: '${t.routes[i].fromName} to ${t.routes[i].toName}',
          subtitle: TaxiOptionSets.tripLabel(t.routes[i].tripType),
          price: BrowseItem.inr(t.routes[i].fare),
        ),
    ];
  }

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
            : () => ReportListingSheet.show(context, listingId: t.id, listingType: 'Taxi', palette: templateTaxiPalette),
        palette: templateTaxiPalette,
      );
    });
  }
}

class DetailSharingOverlay extends StatelessWidget {
  const DetailSharingOverlay({super.key, required this.tone, this.message = 'Sharing...'});

  final ListingTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onVerticalDragStart: (_) {},
      child: Semantics(
        liveRegion: true,
        container: true,
        label: message,
        child: ColoredBox(
          color: DesignColors.scrim,
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(34, 24, 34, 24),
              decoration: const BoxDecoration(
                color: DesignColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(24)),
                boxShadow: ShadowTokens.elev3,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(strokeWidth: 4, color: tone.g2, backgroundColor: DesignColors.tint(tone.haloBase, Alpha.soft)),
                ),
                const SizedBox(height: 14),
                ExcludeSemantics(
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(message, maxLines: 1, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
