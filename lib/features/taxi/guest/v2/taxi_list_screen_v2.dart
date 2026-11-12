import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/tab_config_controller.dart';
import '../../../../design/design.dart';
import '../../../../models/place_result_model.dart';
import '../../../../utils/app_toast.dart';
import '../../../../widgets/location_search_sheet.dart';
import '../../../nearby/controllers/nearby_centre_controller.dart';
import '../../../nearby/nearby_strings.dart';
import '../../../nearby/widgets/nearby_centre_bar.dart';
import '../../../nearby/widgets/nearby_featured_slot.dart';
import '../../../nearby/widgets/nearby_header_strip.dart';
import '../../../nearby/widgets/nearby_label_text.dart';
import '../../../nearby/widgets/nearby_state_views.dart';
import '../../ways/widgets/taxi_ways_entry_card.dart';
import '../taxi_card.dart';
import '../taxi_navigation.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottom = widget.root ? BarMetrics.bodyBottomOf(context) : 32 + MediaQuery.paddingOf(context).bottom;
    final body = Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: RefreshIndicator(
        color: DesignColors.primary,
        backgroundColor: DesignColors.surface,
        onRefresh: _ctrl.pullRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _in(0, _buildReviewStrip())),
            SliverToBoxAdapter(child: _in(1, _buildTiles())),
            SliverToBoxAdapter(child: _buildCentreBar()),
            SliverToBoxAdapter(child: _buildHeaderStrip()),
            _buildBody(),
            SliverToBoxAdapter(child: _buildFooter(bottom)),
          ],
        ),
      ),
    );
    return widget.root ? TabEntrance(tab: AppTabs.taxi, child: body) : body;
  }

  static const double _selectorCard = 88;
  static const double _headerBottom = 44;
  static const double _selectorOverlap = _headerBottom + ModuleHeader.paddingBottom;

  double _cardHeight(BuildContext context) =>
      math.max(_selectorCard, 2 * (MediaQuery.textScalerOf(context).scale(36) + 8) + 1);

  Widget _buildHeader(BuildContext context) {
    final card = _cardHeight(context);
    return Obx(() {
      final title = widget.root ? Get.find<TabConfigController>().displayNameForIndex(AppTabs.taxi, 'Taxi') : 'Taxi';
      final far = _ctrl.header.value?.farAway ?? false;
      final subtitle = _ctrl.to.value != null ? 'Taxis for your route' : (far ? 'Find the nearest taxis' : 'Taxis near you');
      return Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ModuleHeader(
                title: title,
                subtitle: subtitle,
                tone: KitTone.taxi,
                tabRoot: widget.root,
                onBack: widget.root ? null : () => Get.back(),
                autoHeight: true,
                bottom: const SizedBox(height: _headerBottom),
              ),
              Positioned(
                left: KitMetrics.gutter,
                right: KitMetrics.gutter,
                bottom: -(card - _selectorOverlap),
                child: _buildSelectors(card),
              ),
            ],
          ),
          SizedBox(height: card - _selectorOverlap + 12),
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

  Widget _buildSelectors(double card) {
    return Obx(() {
      final f = _ctrl.from.value;
      final t = _ctrl.to.value;
      NearbyCentreController.to.centreVersion.value;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev3,
        ),
        child: SizedBox(
          height: card,
          child: Column(children: [
            Expanded(
              child: _selector(
                label: 'From',
                asset: TravelIcon.place,
                value: _fromText(),
                isSet: f != null,
                onTap: () => _pick(isFrom: true),
                trailing: f == null
                    ? null
                    : _trailingButton(Image.asset(TravelIcon.pin, width: 22, height: 22), _ctrl.useCentreAsFrom),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: DesignColors.dividerSoft),
            Expanded(
              child: _selector(
                label: 'To',
                asset: TravelIcon.map,
                value: t?.name ?? 'Anywhere / search a place',
                isSet: t != null,
                onTap: () => _pick(isFrom: false),
                trailing: t != null
                    ? _trailingButton(const Icon(Icons.close_rounded, size: 18, color: DesignColors.primary), _ctrl.clearTo)
                    : null,
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _trailingButton(Widget icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
    );
  }

  Widget _selector({
    required String label,
    required String asset,
    required String value,
    required bool isSet,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: DesignColors.splash,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: trailing != null ? 4 : 12),
        child: Row(
          children: [
            Image.asset(asset, width: 24, height: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, style: TypeTokens.caption),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(14, isSet ? FontWeight.w700 : FontWeight.w500,
                        color: isSet ? DesignColors.textStrong : DesignColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing ?? const Icon(Icons.search_rounded, size: 22, color: DesignColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStrip() {
    return Obx(() {
      final pending = _auth.taxisEnabled && _auth.user.value?.taxiStatus == 'PendingReview';
      if (!pending) return const SizedBox.shrink();
      return const SlimBar(
        title: 'Under review',
        subtitle: 'Your taxi is being checked',
        leadingAsset: TravelIcon.note,
        tone: KitTone.taxi,
      );
    });
  }

  Widget _buildTiles() {
    return Obx(() {
      if (!_auth.taxisEnabled || !widget.root) return const SizedBox.shrink();
      return ListRow(
        title: 'My Taxi',
        iconAsset: TravelIcon.taxi,
        tone: KitTone.taxi,
        compact: true,
        onTap: () => Get.toNamed(AppRoutes.myTaxi),
      );
    });
  }

  // The shared centre pill is only for the local list; a picked From replaces it.
  Widget _buildCentreBar() {
    return Obx(() => _ctrl.from.value == null && !_ctrl.isRoute ? NearbyCentreBar(far: _ctrl.header.value?.farAway ?? false) : const SizedBox.shrink());
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

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 4),
        child: Text(text, style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong)),
      );

  Widget _card(TaxiFeedItem f, {int index = 0}) => EntranceOnce(
        key: ValueKey('${f.id}-$index'),
        index: index,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TaxiCard(item: f.item, onOpen: () => _open(f)),
          if (f.distance != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(KitMetrics.gutter + 4, 0, KitMetrics.gutter, 4),
              child: NearbyLabelText(distance: f.distance!, taxi: true),
            ),
        ]),
      );

  Widget _stateBox({required bool error}) => error
      ? NearbyError(onRetry: _ctrl.retry)
      : NearbyEmpty(
          title: _ctrl.isRoute ? NearbyStrings.routeEmptyTitle : NearbyStrings.taxisEmptyTitle,
          body: _ctrl.isRoute ? NearbyStrings.routeEmptyBody : NearbyStrings.taxisEmptyBody,
        );

  Widget _buildBody() {
    return Obx(() {
      NearbyCentreController.to.centreVersion.value;
      if (_ctrl.isLoading.value && _ctrl.items.isEmpty && _ctrl.route.value == null) return _buildSkeleton();
      if (_ctrl.isRoute) return _routeBody();
      final items = _ctrl.items;
      final featured = _ctrl.featured;
      if (items.isEmpty && featured.isEmpty) {
        return SliverToBoxAdapter(child: _stateBox(error: _ctrl.loadFailed.value));
      }
      final thin = items.length + featured.length < 3 && !_ctrl.hasMore.value;
      return SliverList.list(children: [
        NearbyFeaturedSlot<TaxiFeedItem>(items: featured.toList(), builder: (_, f) => _card(f)),
        _title(_localTitle()),
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
            ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: DesignColors.primary)))
            : TextLink(label: NearbyStrings.showMore, onTap: () => _ctrl.showMoreOf(t.key)),
      );
    });
  }

  Widget _routeBody() {
    final r = _ctrl.route.value;
    final f = _ctrl.from.value ?? PlaceResult(name: 'Near you', subtitle: '', latLng: _ctrl.origin);
    final to = _ctrl.to.value;
    if (r == null) return SliverToBoxAdapter(child: _stateBox(error: _ctrl.loadFailed.value));
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
        child = const Center(child: CircularProgressIndicator(strokeWidth: 2, color: DesignColors.primary));
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
