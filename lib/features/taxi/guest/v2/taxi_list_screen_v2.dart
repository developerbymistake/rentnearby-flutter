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
import '../../../nearby/controllers/nearby_centre_controller.dart';
import '../../../nearby/nearby_strings.dart';
import '../../../nearby/widgets/nearby_header_strip.dart';
import '../../../nearby/widgets/nearby_state_views.dart';
import '../../ways/widgets/taxi_ways_entry_card.dart';
import '../../models/taxi_browse_item.dart';
import '../taxi_card.dart';
import '../taxi_navigation.dart';
import '../../taxi_option_sets.dart';
import 'route_cities_strip.dart';
import 'taxi_feed_repository.dart';
import 'taxi_list_controller_v2.dart';

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

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<TaxiListControllerV2>(tag: TaxiListControllerV2.tag)
        ? Get.find<TaxiListControllerV2>(tag: TaxiListControllerV2.tag)
        : Get.put(TaxiListControllerV2(root: widget.root), tag: TaxiListControllerV2.tag);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
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
      final other = isFrom ? _ctrl.to.value : (_ctrl.from.value ?? PlaceResult(name: '', subtitle: '', latLng: _ctrl.origin));
      if (_ctrl.isTooClose(p, other)) {
        AppToast.warning('From and To must be different places');
        return;
      }
      isFrom ? _ctrl.setFrom(p) : _ctrl.setTo(p);
    } catch (_) {
      AppToast.error(NearbyStrings.searchFailed);
    } finally {
      _picking = false;
    }
  }

  Widget _in(int i, Widget child) => EntranceOnce(index: i, child: child);

  static final _tone = ListingTone.coral;

  @override
  Widget build(BuildContext context) {
    final bottom = widget.root ? OverlayInsets.list(context) : 32 + MediaQuery.paddingOf(context).bottom;
    final body = Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: KitStatusBar(
        lightIcons: false,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
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
                SliverToBoxAdapter(child: _buildHeaderStrip()),
                _buildBody(),
                SliverToBoxAdapter(child: _buildFooter(bottom)),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.root ? TabEntrance(tab: AppTabs.taxi, child: body) : body;
  }

  Widget _buildHeader(BuildContext context) {
    return Obx(() {
      final title = widget.root ? Get.find<TabConfigController>().displayNameForIndex(AppTabs.taxi, 'Taxi') : 'Taxi';
      final far = _ctrl.header.value?.farAway ?? false;
      final subtitle = _ctrl.to.value != null ? 'Taxis for your route' : (far ? 'Find the nearest taxis' : 'Taxis near you');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.root)
            ModuleTitleBar(tone: _tone, art: ListingArt.taxi, title: title, subtitle: subtitle)
          else
            TopBar3D(tone: _tone, title: title, subtitle: subtitle, onBack: () => Get.back()),
          _buildSelectors(),
        ],
      );
    });
  }

  String _fromText() {
    final f = _ctrl.from.value;
    if (f != null) return f.name;
    final c = NearbyCentreController.to;
    final label = c.pinLabel;
    return c.hasPin && label != null ? label : 'Near you';
  }

  Widget _buildSelectors() {
    return Obx(() {
      final f = _ctrl.from.value;
      final t = _ctrl.to.value;
      NearbyCentreController.to.centreVersion.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchPill(
            tone: _tone,
            label: 'From',
            value: _fromText(),
            leadingArt: ListingArt.roundPushpin,
            buttonArt: f == null ? ListingArt.compass : ListingArt.roundPushpin,
            buttonSemantics: f == null ? 'Search From' : 'Use my centre',
            onTap: () => _pick(isFrom: true),
            onButtonTap: f == null ? () => _pick(isFrom: true) : _ctrl.useCentreAsFrom,
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          ),
          SearchPill(
            tone: _tone,
            label: 'To',
            value: t?.name ?? 'Anywhere / search a place',
            hint: t == null,
            leadingArt: ListingArt.worldMap,
            buttonArt: ListingArt.compass,
            buttonSemantics: t == null ? 'Search To' : 'Clear To',
            buttonChild: t == null ? null : const Icon(Icons.close_rounded, color: DesignColors.onPrimary, size: 26),
            onTap: () => _pick(isFrom: false),
            onButtonTap: t == null ? () => _pick(isFrom: false) : _ctrl.clearTo,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          ),
        ],
      );
    });
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
        padding: const EdgeInsets.only(top: 18),
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
    final f = _ctrl.from.value;
    final c = NearbyCentreController.to;
    final place = f?.name ?? (c.hasPin ? c.pinLabel : null);
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
          tone: ListingTone.list(_tone, index),
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
    final art = w < 340 ? 88.0 : 104.0;
    final width = w - 36 - 44 - (art - 8 > 80 ? art - 8 : 80);
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
        padding: const EdgeInsets.only(top: 24, bottom: 4),
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
      : NearbyEmpty(
          title: _ctrl.isRoute ? NearbyStrings.routeEmptyTitle : NearbyStrings.taxisEmptyTitle,
          body: _ctrl.isRoute ? NearbyStrings.routeEmptyBody : NearbyStrings.taxisEmptyBody,
          tone: ListingTone.coral,
        );

  Widget _buildBody() {
    return Obx(() {
      NearbyCentreController.to.centreVersion.value;
      if (_ctrl.isLoading.value && _ctrl.items.isEmpty && _ctrl.route.value == null) return _buildSkeleton();
      if (_ctrl.isRoute) return _routeBody();
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

  Widget _tierTitle(TaxiTier t, TaxiRouteFeed r) {
    final from = _ctrl.from.value?.name;
    final to = _ctrl.to.value?.name ?? '';
    switch (t.key) {
      case TaxiTierKey.onRoute:
        return _title(NearbyStrings.driversOnRoute);
      case TaxiTierKey.passing:
        return _title(NearbyStrings.driversPassing);
      case TaxiTierKey.basedNearFrom:
        return _title(NearbyStrings.basedNearFrom(t.header?.centreCityName ?? r.header.centreCityName ?? from ?? 'your start'));
      default:
        return _title(NearbyStrings.taxisInTo(t.header?.centreCityName ?? to));
    }
  }

  Widget _showMore(TaxiTier t) {
    return Obx(() {
      final loading = _ctrl.loadingTiers.contains(t.key);
      return Padding(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 4, KitMetrics.gutter, 8),
        child: loading
            ? Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _tone.g2)))
            : Center(child: ListingFilterChip(tone: _tone, label: NearbyStrings.showMore, selected: false, onTap: () => _ctrl.showMoreOf(t.key))),
      );
    });
  }

  Widget _routeBody() {
    final r = _ctrl.route.value;
    final f = _ctrl.from.value ?? PlaceResult(name: 'Near you', subtitle: '', latLng: _ctrl.origin);
    final to = _ctrl.to.value;
    if (r == null) return SliverList.list(children: [_title(_localTitle()), _stateBox(error: _ctrl.loadFailed.value)]);
    final children = <Widget>[];
    final shown = [for (final t in r.tiers) if (t.items.isNotEmpty) t];
    if (shown.isEmpty) {
      children.add(_stateBox(error: false));
    } else if (to != null) {
      children.add(RouteCitiesStrip(
        fromLat: _ctrl.origin.latitude,
        fromLng: _ctrl.origin.longitude,
        toLat: to.latLng.latitude,
        toLng: to.latLng.longitude,
        fromName: _ctrl.from.value?.name,
        toName: to.name,
      ));
    }
    for (final t in shown) {
      final open = !t.collapsed || _ctrl.isExpanded(t.key);
      children.add(_tierTitle(t, r));
      if (open) {
        for (var i = 0; i < t.items.length; i++) {
          children.add(_card(t.items[i], index: i));
        }
      }
      if ((t.collapsed && !open) || (open && t.hasMore)) children.add(_showMore(t));
    }
    if (to != null) {
      children.add(TaxiWaysEntryCard(
        from: f,
        to: to,
        empty: shown.isEmpty,
        fromMyLocation: _ctrl.from.value == null && !NearbyCentreController.to.hasPin,
      ));
    }
    return SliverList.list(children: children);
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
        child = Center(child: CircularProgressIndicator(strokeWidth: 2, color: _tone.g2));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(child: TextLink(label: "Couldn't load more. Tap to retry", onTap: _ctrl.retryLoadMore));
      }
      return Padding(
        padding: EdgeInsets.only(top: 12, bottom: bottom),
        child: SizedBox(height: 44, child: child),
      );
    });
  }
}
