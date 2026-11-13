import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../models/taxi_browse_item.dart';
import '../ways/widgets/taxi_ways_entry_card.dart';
import 'taxi_card.dart';
import 'taxi_list_controller.dart';
import 'taxi_navigation.dart';

class TaxiListScreen extends StatefulWidget {
  final bool root;
  const TaxiListScreen({super.key, this.root = false});

  @override
  State<TaxiListScreen> createState() => _TaxiListScreenState();
}

class _TaxiListScreenState extends State<TaxiListScreen> {
  late final TaxiListController _ctrl;
  late final String _tag;
  final _auth = Get.find<AuthController>();
  final _scroll = ScrollController();
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _tag = widget.root ? TaxiListController.tag : TaxiListController.pushTag;
    if (Get.isRegistered<TaxiListController>(tag: _tag)) {
      _ctrl = Get.find<TaxiListController>(tag: _tag);
      if (!widget.root) {
        final preset = TaxiPreset.fromArgs(Get.arguments);
        if (preset != null) _ctrl.applyPreset(preset);
      }
    } else {
      _ctrl = Get.put(
        TaxiListController(root: widget.root, preset: widget.root ? null : TaxiPreset.fromArgs(Get.arguments)),
        tag: _tag,
      );
    }
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    Get.delete<TaxiListController>(tag: _tag);
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent * 0.7) _ctrl.loadNextPage();
  }

  void _open(TaxiBrowseItem t) => TaxiNavigation.openDetail(
        t.id,
        matchedFare: t.isMatch ? t.matchedFare : null,
        matchedToName: t.isMatch ? t.matchedToName : null,
      );

  Future<void> _pick({required bool isFrom}) async {
    if (_picking) return;
    _picking = true;
    try {
      final picked = await LocationSwitchSheet.pick(
        context,
        palette: templateModulePalette,
        title: isFrom ? 'From city' : 'To city',
      );
      if (picked == null || !mounted) return;
      final other = isFrom ? _ctrl.to.value : _ctrl.from.value;
      if (_ctrl.isTooClose(TaxiListController.placeOf(picked), other)) {
        AppToast.warning('From and To must be different places');
        return;
      }
      if (isFrom) {
        _ctrl.setFromCity(picked);
      } else {
        _ctrl.setToCity(picked);
      }
    } finally {
      _picking = false;
    }
  }

  Widget _in(int i, Widget child) => EntranceOnce(index: i, child: child);

  @override
  Widget build(BuildContext context) {
    final bottom = widget.root
        ? BarMetrics.bodyBottomOf(context)
        : 32 + MediaQuery.paddingOf(context).bottom;
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
            SliverToBoxAdapter(child: _in(2, _buildListHeader())),
            SliverToBoxAdapter(child: _in(3, _buildWaysEntry())),
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

  Widget _buildHeader(BuildContext context) {
    final headerH = ModuleHeader.heightOf(context, hasSubtitle: true, bottomHeight: _headerBottom);
    return Obx(() {
      final title = widget.root
          ? Get.find<TabConfigController>().displayNameForIndex(AppTabs.taxi, 'Taxi')
          : 'Taxi';
      return SizedBox(
        height: headerH + (_selectorCard - _selectorOverlap) + 12,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ModuleHeader(
              title: title,
              subtitle: _ctrl.to.value != null ? 'Taxis for your route' : 'Local taxis near you',
              tone: KitTone.taxi,
              tabRoot: widget.root,
              onBack: widget.root ? null : () => Get.back(),
              bottomHeight: _headerBottom,
              bottom: const SizedBox.shrink(),
            ),
            Positioned(
              left: KitMetrics.gutter,
              right: KitMetrics.gutter,
              top: headerH - _selectorOverlap,
              child: _buildSelectors(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSelectors() {
    return Obx(() {
      final f = _ctrl.from.value;
      final t = _ctrl.to.value;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev3,
        ),
        child: SizedBox(
          height: _selectorCard,
          child: Column(children: [
            Expanded(
              child: _selector(
                label: 'From',
                asset: TravelIcon.place,
                value: f?.name,
                placeholder: 'Pick a city',
                onTap: () => _pick(isFrom: true),
                trailing: _ctrl.fromIsCurrent.value || f == null && _ctrl.isLoading.value
                    ? null
                    : _trailingButton(Image.asset(TravelIcon.pin, width: 22, height: 22), _ctrl.useCurrentFrom),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: DesignColors.dividerSoft),
            Expanded(
              child: _selector(
                label: 'To',
                asset: TravelIcon.map,
                value: t?.name,
                placeholder: 'Anywhere / pick a city',
                onTap: () => _pick(isFrom: false),
                trailing: t != null
                    ? _trailingButton(
                        const Icon(Icons.close_rounded, size: 18, color: DesignColors.primary), _ctrl.clearTo)
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
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isSet = value != null;
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
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(14, isSet ? FontWeight.w700 : FontWeight.w500,
                        color: isSet ? DesignColors.textStrong : DesignColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing ?? const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: DesignColors.primary),
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
      final enabled = _auth.taxisEnabled;
      if (!widget.root || !enabled) return const SizedBox.shrink();
      return ListRow(
        title: 'My Taxi',
        iconAsset: TravelIcon.taxi,
        tone: KitTone.taxi,
        compact: true,
        onTap: () => Get.toNamed(AppRoutes.myTaxi),
      );
    });
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 4),
      child: Obx(() => Text(
            _ctrl.to.value != null ? 'Route taxis' : 'Taxis near you',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong),
          )),
    );
  }

  Widget _buildWaysEntry() {
    return Obx(() {
      final f = _ctrl.from.value;
      final t = _ctrl.to.value;
      if (!_ctrl.isSearch || _ctrl.items.isEmpty || f == null || t == null) return const SizedBox.shrink();
      return TaxiWaysEntryCard(from: f, to: t, fromMyLocation: _ctrl.fromIsCurrent.value);
    });
  }

  Widget _empty({String? asset, bool error = false, required String title, required String subtitle, VoidCallback? onRetry}) =>
      SliverToBoxAdapter(
        child: error
            ? StateCard.error(
                title: title,
                message: subtitle,
                kit: KitTone.taxi,
                actionLabel: onRetry == null ? null : 'Try again',
                onAction: onRetry,
              )
            : StateCard(
                title: title,
                message: subtitle,
                kit: KitTone.taxi,
                asset: asset ?? TravelIcon.taxi,
              ),
      );

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) return _buildSkeleton();
        if (_ctrl.from.value == null) {
          return _empty(asset: TravelIcon.place, title: 'Pick where you start', subtitle: 'Tap From to choose a city');
        }
        final failed = _ctrl.loadFailed.value;
        final f = _ctrl.from.value;
        final t = _ctrl.to.value;
        if (_ctrl.isSearch && !failed && !_ctrl.isLoading.value && f != null && t != null) {
          return SliverToBoxAdapter(
            child: TaxiWaysEntryCard(from: f, to: t, empty: true, fromMyLocation: _ctrl.fromIsCurrent.value),
          );
        }
        final hint = _ctrl.to.value != null ? 'Try another city' : 'Pick a To city for route taxis';
        return _empty(
          asset: TravelIcon.taxi,
          error: failed,
          title: failed ? "Couldn't load taxis" : 'No taxis yet',
          subtitle: failed ? 'Check your connection and try again' : hint,
          onRetry: failed ? _ctrl.retry : null,
        );
      }
      return SliverList.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final t = items[i];
          return EntranceOnce(
            key: ValueKey(t.id),
            index: i,
            child: TaxiCard(item: t, onOpen: () => _open(t), tone: ListingTone.list(ListingTone.coral, i)),
          );
        },
      );
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
      if (_ctrl.items.isEmpty) return SizedBox(height: bottom);
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = const Center(child: CircularProgressIndicator(strokeWidth: 2, color: DesignColors.primary));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextLink(label: "Couldn't load more. Tap to retry", onTap: _ctrl.retryLoadMore),
        );
      }
      return Padding(
        padding: EdgeInsets.only(top: 12, bottom: bottom),
        child: SizedBox(height: 44, child: child),
      );
    });
  }
}
