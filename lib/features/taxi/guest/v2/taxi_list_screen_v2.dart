import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/tab_config_controller.dart';
import '../../../../design/design.dart';
import '../../../../models/browse_item.dart';
import '../../../../models/place_result_model.dart';
import '../../../../utils/app_toast.dart';
import '../../../../widgets/location_search_sheet.dart';
import '../../../../widgets/tab_header.dart';
import '../../../nearby/controllers/nearby_centre_controller.dart';
import '../../../nearby/nearby_strings.dart';
import '../../../nearby/widgets/nearby_header_strip.dart';
import '../../../nearby/widgets/nearby_state_views.dart';
import '../../models/taxi_browse_item.dart';
import '../taxi_card.dart';
import '../taxi_navigation.dart';
import '../../taxi_option_sets.dart';
import 'taxi_date_sheet.dart';
import 'taxi_feed_repository.dart';
import 'taxi_list_controller_v2.dart';
import 'taxi_popular_routes.dart';
import 'taxi_search_card.dart';
import 'taxi_search_strings.dart';

class TaxiListScreenV2 extends StatefulWidget {
  final bool root;
  const TaxiListScreenV2({super.key, this.root = true});

  @override
  State<TaxiListScreenV2> createState() => _TaxiListScreenV2State();
}

class _TaxiListScreenV2State extends State<TaxiListScreenV2> {
  late final TaxiListControllerV2 _ctrl;
  final _auth = Get.find<AuthController>();
  final _scroll = ScrollController();
  bool _picking = false;
  bool _pickingDate = false;
  Timer? _dayTimer;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<TaxiListControllerV2>(tag: TaxiListControllerV2.tag)
        ? Get.find<TaxiListControllerV2>(tag: TaxiListControllerV2.tag)
        : Get.put(TaxiListControllerV2(root: widget.root), tag: TaxiListControllerV2.tag);
    _scroll.addListener(_onScroll);
    _life = AppLifecycleListener(onResume: _dayChanged);
    _armDay();
  }

  void _armDay() {
    _dayTimer?.cancel();
    _dayTimer = Timer(_ctrl.untilNextDay + const Duration(seconds: 1), _dayChanged);
  }

  void _dayChanged() {
    if (!mounted) return;
    _ctrl.checkDay();
    _armDay();
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    _life.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    Get.delete<TaxiListControllerV2>(tag: TaxiListControllerV2.tag);
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent * 0.7) _ctrl.loadNextPage();
  }

  void _open(TaxiFeedItem f) => TaxiNavigation.openDetail(
        f.id,
        matchedFare: f.item.isMatch ? f.item.matchedFare : null,
        matchedToName: f.item.isMatch ? f.item.matchedToName : null,
      );

  Future<void> _pick({required bool isFrom}) async {
    if (_picking) return;
    _picking = true;
    try {
      final PlaceResult? p = await LocationSearchSheet.show(context, bias: _ctrl.origin, palette: templateModulePalette);
      if (p == null || !mounted) return;
      isFrom ? _ctrl.setFrom(p) : _ctrl.setTo(p);
      if (_ctrl.samePlace) AppToast.warning(TaxiSearchStrings.samePlace);
    } catch (_) {
      AppToast.error(NearbyStrings.searchFailed);
    } finally {
      _picking = false;
    }
  }

  Future<void> _pickDate() async {
    if (_pickingDate) return;
    _pickingDate = true;
    try {
      final d = await TaxiDateSheet.pick(context, initial: _ctrl.date.value, today: _ctrl.today);
      if (d != null && mounted) _ctrl.setDate(d);
    } finally {
      _pickingDate = false;
    }
  }

  Widget _in(int i, Widget child) => EntranceOnce(index: i, child: child);

  static final _tone = ListingTone.coral;

  @override
  Widget build(BuildContext context) {
    final bottom = widget.root ? OverlayInsets.list(context) : DS.s(32) + MediaQuery.paddingOf(context).bottom;
    final list = RefreshIndicator(
      color: _tone.g2,
      backgroundColor: DesignColors.surface,
      onRefresh: _ctrl.pullRefresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _in(0, _buildReviewStrip())),
          SliverToBoxAdapter(child: _in(1, _buildTiles())),
          SliverToBoxAdapter(child: _buildPopular()),
          SliverToBoxAdapter(child: _buildHeaderStrip()),
          _buildBody(),
          SliverToBoxAdapter(child: _buildFooter(bottom)),
        ],
      ),
    );
    if (widget.root) {
      return TabEntrance(
        tab: AppTabs.taxi,
        child: Scaffold(
          backgroundColor: ListingPalette.coral.page,
          body: Obx(
            () => TabHeaderFrame(
              title: Get.find<TabConfigController>().displayNameForIndex(AppTabs.taxi, 'Taxi'),
              subtitle: _subtitle,
              color: ListingPalette.coral.page,
              child: list,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: KitStatusBar(
        lightIcons: false,
        child: SafeArea(bottom: false, child: list),
      ),
    );
  }

  String get _subtitle {
    final far = _ctrl.header.value?.farAway ?? false;
    return far ? 'Find the nearest taxis' : 'Taxis near you';
  }

  Widget _buildHeader(BuildContext context) {
    if (widget.root) return _buildSelectors();
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TopBar3D(tone: _tone, title: 'Taxi', subtitle: _subtitle, onBack: () => Get.back()),
            _buildSelectors(),
          ],
        ));
  }

  Widget _buildSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          final f = _ctrl.from.value;
          final t = _ctrl.to.value;
          final d = _ctrl.date.value;
          final err = _ctrl.toError.value;
          NearbyCentreController.to.centreVersion.value;
          return Padding(
            padding: EdgeInsets.only(top: DS.gv(24)),
            child: TaxiSearchCard(
              fromLabel: _ctrl.fromName,
              toLabel: t?.name,
              date: d,
              isToday: _ctrl.isToday,
              canSwap: _ctrl.canSwap,
              onFrom: () => _pick(isFrom: true),
              onTo: () => _pick(isFrom: false),
              onDate: _pickDate,
              onSwap: _ctrl.swap,
              onClearFrom: f == null ? null : _ctrl.useCentreAsFrom,
              onClearTo: t == null ? null : _ctrl.clearTo,
              toError: err,
            ),
          );
        }),
        SearchTaxisButton(onPressed: _ctrl.submit),
      ],
    );
  }

  Widget _buildPopular() {
    return Obx(() => TaxiPopularRoutesRail(routes: _ctrl.popular.toList(), onTap: _ctrl.applyPopular));
  }

  Widget _buildReviewStrip() {
    return Obx(() {
      final pending = _auth.taxisEnabled && _auth.user.value?.taxiStatus == 'PendingReview';
      if (!pending) return const SizedBox.shrink();
      return WideCard(
        kind: WideKind.slim,
        tone: ListingTone.cF,
        art: ListingArt.calendar,
        title: 'Under review',
        subtitle: 'Your taxi is being checked',
      );
    });
  }

  Widget _buildTiles() {
    return Obx(() {
      if (!_auth.taxisEnabled || !widget.root) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: DS.gv(18)),
        child: WhiteCard3D(
          child: IconRow3D(art: ListingArt.taxi, title: 'My Taxi', tone: _tone, onTap: () => Get.toNamed(AppRoutes.myTaxi)),
        ),
      );
    });
  }

  Widget _buildHeaderStrip() {
    return Obx(() {
      NearbyCentreController.to.centreVersion.value;
      return NearbyHeaderStrip(header: _ctrl.header.value, hasPin: NearbyCentreController.to.hasPin || _ctrl.from.value != null);
    });
  }

  String _localTitle() {
    final far = _ctrl.header.value?.farAway ?? false;
    final place = _ctrl.from.value?.name ?? _ctrl.centreName;
    if (place != null) return far ? NearbyStrings.taxisNearestToPlace(place) : NearbyStrings.taxisNearPlace(place);
    return far ? NearbyStrings.taxisNearest : NearbyStrings.taxisNear;
  }

  Widget _title(String text) => TitleRow3D(title: text, tone: _tone);

  Widget _card(TaxiFeedItem f, {int index = 0}) => EntranceOnce(
        key: ValueKey('${f.id}-$index'),
        index: index,
        child: TaxiCard(
          item: f.item,
          onOpen: () => _open(f),
          distance: f.distance,
        ),
      );

  String _heroSub(TaxiFeedItem f) {
    final t = f.item;
    final fare = t.isMatch
        ? [BrowseItem.inr(t.matchedFare!), if ((t.matchedToName ?? '').isNotEmpty) 'to ${t.matchedToName}'].join(' ')
        : t.localDayRate != null
            ? TaxiOptionSets.localRateLabel(t.localDayRate!)
            : '';
    final d = f.distance;
    final head = [t.locality, fare].where((e) => e.isNotEmpty).join(' · ');
    final dist = d == null ? '' : TaxiCard.labelFor(d);
    final road = d != null && d.isFar ? NearbyStrings.byRoad : '';
    String join(List<String> parts, String sep) => parts.where((e) => e.isNotEmpty).join(sep);
    final tail = join([dist, road], '. ');
    final options = [
      join([head, dist, road], '\n'),
      join([head, tail], '\n'),
      join([head, tail], ' · '),
    ];
    for (final s in options) {
      if (_heroSubLines(s) <= _heroSubMaxLines) return s;
    }
    return options.last;
  }

  static const int _heroSubMaxLines = 8;

  // Same width and style as the WorkoutCard subtitle beside its arrow.
  int _heroSubLines(String s) {
    final w = MediaQuery.sizeOf(context).width;
    final art = DS.s(w < 340 ? 88.0 : 104.0);
    final width = w - DS.s(36) - DS.s(44) - (art - DS.s(8) > DS.s(80) ? art - DS.s(8) : DS.s(80));
    if (width <= 0) return 0;
    final tp = TextPainter(
      text: TextSpan(text: s, style: Ink3D.text(13, FontWeight.w400, Ink3D.title, height: 1.35)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final n = tp.computeLineMetrics().length;
    tp.dispose();
    return n;
  }

  static String _keep(String s) => s.trim().replaceAll(' ', ' ');

  String _heroEyebrow(TaxiBrowseItem t) => [
        '${KitText.star} Featured',
        t.vehicleTypeName,
        if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
      ].where((e) => e.trim().isNotEmpty).map(_keep).join(' · ');

  List<String> _heroChips(TaxiFeedItem f) {
    final t = f.item;
    return [
      if (!t.isMatch) 'Local taxi',
      if (t.isMatch && t.matchedTripType == 'RoundTrip') 'Round trip',
      if (t.isMatch && t.matchReversed) 'Reverse',
      if (!t.isMatch && t.localDayRate != null && t.localDayKm != null) '${t.localDayKm} km/day',
    ];
  }

  Widget _hero(TaxiFeedItem f) {
    final t = f.item;
    return EntranceOnce(
      key: ValueKey('${f.id}-hero'),
      index: 0,
      child: Padding(
        padding: EdgeInsets.only(top: DS.gv(24), bottom: DS.gv(4)),
        child: WorkoutCard(
          tone: _tone,
          art: TaxiVehicleIcon.assetFor(t.vehicleTypeName),
          eyebrow: _heroEyebrow(t),
          title: t.driverName,
          subtitle: _heroSub(f),
          chips: _heroChips(f),
          trailing: WorkoutTrailing.arrow,
          onTap: () => _open(f),
        ),
      ),
    );
  }

  Widget _stateBox({required bool error}) => error
      ? NearbyError(onRetry: _ctrl.retry, tone: ListingTone.coral)
      : NearbyEmpty(title: NearbyStrings.taxisEmptyTitle, body: NearbyStrings.taxisEmptyBody, tone: ListingTone.coral);

  Widget _buildBody() {
    return Obx(() {
      NearbyCentreController.to.centreVersion.value;
      if (_ctrl.isLoading.value && _ctrl.items.isEmpty && _ctrl.featured.isEmpty) return _buildSkeleton();
      final items = _ctrl.items;
      final featured = _ctrl.featured;
      if (items.isEmpty && featured.isEmpty) {
        return SliverList.list(children: [_title(_localTitle()), _stateBox(error: _ctrl.loadFailed.value)]);
      }
      final thin = items.length + featured.length < 3 && !_ctrl.hasMore.value;
      return SliverList.list(children: [
        if (featured.isNotEmpty) _hero(featured.first),
        _title(_localTitle()),
        if (featured.length > 1) _card(featured[1], index: 1),
        for (var i = 0; i < items.length; i++) _card(items[i], index: i),
        if (thin) const NearbyThin(),
      ]);
    });
  }

  Widget _buildSkeleton() {
    return SliverList.builder(
      itemCount: 4,
      itemBuilder: (_, _) => const TaxiCardSkeleton(),
    );
  }

  Widget _buildFooter(double bottom) {
    return Obx(() {
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = Center(child: CircularProgressIndicator(strokeWidth: DS.s(2), color: _tone.g2));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(child: TextLink(label: "Couldn't load more. Tap to retry", onTap: _ctrl.retryLoadMore));
      }
      return Padding(
        padding: EdgeInsets.only(top: DS.gv(12), bottom: bottom),
        child: SizedBox(height: DS.s(44), child: child),
      );
    });
  }
}
