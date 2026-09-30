import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/app_shadows.dart';
import '../config/app_tabs.dart';
import '../controllers/explore_landing_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../models/browse_item.dart';
import '../models/explore_kind.dart';
import '../navigation/tour_keys.dart';
import '../services/add_listing_flow.dart';
import '../services/explore_navigation.dart';
import '../widgets/add_listing_shortcut_button.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/gradient_button.dart';
import '../widgets/listing_grid_card.dart';
import '../widgets/location_switch_sheet.dart';
import '../widgets/selectable_chip.dart';
import 'explore_location_search_mixin.dart';

const _kGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 190,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  mainAxisExtent: ListingGridCard.height,
);

const _kMapGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.accentLight, AppColors.accent],
);
const _kNearestGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
);
const _kMineGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFBBF24), AppColors.warning],
);

class ExploreLandingScreen extends StatefulWidget {
  const ExploreLandingScreen({super.key, required this.kind});

  final ExploreKind kind;

  @override
  State<ExploreLandingScreen> createState() => _ExploreLandingScreenState();
}

class _ExploreLandingScreenState extends State<ExploreLandingScreen>
    with ExploreLocationSearchMixin<ExploreLandingScreen> {
  late final ExploreLandingController _ctrl;
  final _scroll = ScrollController();

  bool get _isRooms => widget.kind == ExploreKind.rooms;

  @override
  bool get searchPlotsTheme => !_isRooms;
  int get _tab => _isRooms ? AppTabs.rooms : AppTabs.plots;
  Color get _accent => _isRooms ? AppColors.primary : AppColors.plot;
  Color get _accentDark => _isRooms ? AppColors.primary : AppColors.plotDark;
  Gradient get _gradient => _isRooms ? AppColors.primaryGradient : AppColors.plotGradient;
  GlobalKey get _listKey => _isRooms ? TourKeys.roomsLandingList : TourKeys.plotsLandingList;

  @override
  void initState() {
    super.initState();
    final tag = widget.kind.name;
    _ctrl = Get.isRegistered<ExploreLandingController>(tag: tag)
        ? Get.find<ExploreLandingController>(tag: tag)
        : Get.put(ExploreLandingController(widget.kind), tag: tag);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    Get.delete<ExploreLandingController>(tag: widget.kind.name);
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent * 0.7) _ctrl.loadNextPage();
  }

  void _viewDetails(BrowseItem item) {
    if (_isRooms) {
      Get.toNamed(AppRoutes.listingDetail, arguments: {'id': item.id});
    } else {
      Get.toNamed(AppRoutes.plotDetail, arguments: item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _accent,
            onRefresh: _ctrl.pullRefresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: _buildTiles()),
                SliverToBoxAdapter(child: _buildTypeChips()),
                SliverToBoxAdapter(child: _buildListHeader()),
                _buildBody(),
                SliverToBoxAdapter(child: _buildFooter()),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: AddListingShortcutButton(
                key: _isRooms ? TourKeys.roomsLandingMapPill : TourKeys.plotsLandingMapPill,
                label: 'Map view',
                icon: Icons.map_outlined,
                gradient: _gradient,
                onTap: () => ExploreNavigation.openMap(_tab),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => Text(
                              Get.find<TabConfigController>().displayNameForIndex(_tab, _isRooms ? 'Rooms' : 'Plots'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                            )),
                        const SizedBox(height: 2),
                        Text(
                          _isRooms ? 'Find rooms for rent near you' : 'Find plots for sale near you',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  KeyedSubtree(
                    key: _isRooms ? TourKeys.roomsLandingSearch : TourKeys.plotsLandingSearch,
                    child: _buildSearchButton(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              KeyedSubtree(
                key: _isRooms ? TourKeys.roomsLandingLocation : TourKeys.plotsLandingLocation,
                child: _buildCityDropdown(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return Obx(() {
      final active = isSearchActive;
      final resolving = searchResolving;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: resolving ? null : () => onSearchToggleTap(context),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.error : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: resolving
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                )
              : active
                  ? const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 15, color: _accent),
                        const SizedBox(width: 5),
                        Text(
                          'Search',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: _accent),
                        ),
                      ],
                    ),
        ),
      );
    });
  }

  Widget _buildCityDropdown() {
    final loc = Get.find<LocationController>();
    return Obx(() {
      final district = loc.effectiveDistrict;
      if (district == null) return const SizedBox(height: 46);
      final cityName = loc.browsingCity.value?.name ?? loc.autoCity.value?.name ?? 'Current';
      final searchLabel = loc.searchPinLabel.value;
      final searching = searchLabel != null;
      final List<InlineSpan> spans = searching
          ? [TextSpan(text: searchLabel)]
          : [
              TextSpan(text: district.name),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded, size: 14, color: _accentDark.withValues(alpha: 0.6)),
                ),
              ),
              TextSpan(text: cityName),
            ];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: searching ? null : () => LocationSwitchSheet.show(context, plots: !_isRooms),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.premium(_accent, alpha: 0.16, blur: 16, offset: const Offset(0, 6)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 17, color: _accentDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spans),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _accentDark),
                ),
              ),
              if (!searching)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _accentDark),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTiles() {
    final tiles = [
      _OptionTile(
        label: _isRooms ? 'Add Room' : 'Add Plot',
        icon: Icons.add_rounded,
        gradient: _gradient,
        onTap: () => AddListingFlow.start(_isRooms),
      ),
      _OptionTile(
        label: _isRooms ? 'My Rooms' : 'My Plots',
        icon: Icons.bar_chart_rounded,
        gradient: _kMineGradient,
        onTap: () => Get.toNamed(_isRooms ? AppRoutes.myListings : AppRoutes.myPlots),
      ),
      _OptionTile(
        label: 'Map view',
        icon: Icons.map_outlined,
        gradient: _kMapGradient,
        onTap: () => ExploreNavigation.openMap(_tab),
      ),
      _OptionTile(
        label: 'Nearest',
        icon: Icons.explore_outlined,
        gradient: _kNearestGradient,
        onTap: () => ExploreNavigation.openMap(_tab, startNearest: true),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: KeyedSubtree(
        key: _isRooms ? TourKeys.roomsLandingTiles : TourKeys.plotsLandingTiles,
        child: Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: KeyedSubtree(
        key: _isRooms ? TourKeys.roomsLandingFilters : TourKeys.plotsLandingFilters,
        child: SizedBox(
          height: 17 + MediaQuery.textScalerOf(context).scale(17),
          child: Obx(() {
            final types = _isRooms
                ? Get.find<ListingController>().roomTypes.map((t) => (id: t.id, name: t.name)).toList()
                : Get.find<PlotController>().plotTypes.map((t) => (id: t.id, name: t.name)).toList();
            final selected = _ctrl.selectedTypeId.value;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: types.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final id = i == 0 ? null : types[i - 1].id;
                return SelectableChip(
                  label: i == 0 ? 'All' : types[i - 1].name,
                  selected: selected == id,
                  activeColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                  onTap: () => _ctrl.setType(id),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isRooms ? 'Rooms near you' : 'Plots near you',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
          GestureDetector(
            key: _isRooms ? TourKeys.roomsLandingSort : TourKeys.plotsLandingSort,
            onTap: () => FilterSortSheet.show(context, controller: _ctrl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: _accentDark),
                  const SizedBox(width: 5),
                  Text(
                    'Filter & Sort',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: _accentDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) return _buildShimmerGrid();
        return SliverToBoxAdapter(child: _buildMessage(failed: _ctrl.loadFailed.value));
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        sliver: SliverGrid(
          gridDelegate: _kGridDelegate,
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final item = items[i];
              final card = ListingGridCard(
                key: ValueKey(item.id),
                thumbnailUrl: item.thumbnailUrl,
                tagLabel: item.tagLabel,
                title: item.title,
                locationLabel: item.locationLabel,
                facts: item.facts,
                priceCaption: item.priceCaption,
                priceValue: item.priceValue,
                priceUnit: item.priceUnit,
                isPlot: !_isRooms,
                onViewDetails: () => _viewDetails(item),
              );
              return i == 0 ? KeyedSubtree(key: _listKey, child: card) : card;
            },
            childCount: items.length,
            addAutomaticKeepAlives: false,
          ),
        ),
      );
    });
  }

  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      sliver: SliverGrid(
        gridDelegate: _kGridDelegate,
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final cell = Shimmer.fromColors(
              baseColor: AppColors.shimmerBase,
              highlightColor: AppColors.shimmerHighlight,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
            );
            return i == 0 ? KeyedSubtree(key: _listKey, child: cell) : cell;
          },
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildMessage({required bool failed}) {
    final noun = _isRooms ? 'rooms' : 'plots';
    return KeyedSubtree(
      key: _listKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: Column(
          children: [
            Icon(failed ? Icons.cloud_off_rounded : Icons.search_off_rounded, size: 40, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(
              failed ? "Couldn't load $noun" : 'No $noun found',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
            const SizedBox(height: 4),
            Text(
              failed ? 'Check your connection and try again' : 'Try another type or a different location',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
            ),
            if (failed) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                child: GradientButton(
                  label: 'Retry',
                  height: 42,
                  gradient: _gradient,
                  shadowColor: _accent,
                  onPressed: _ctrl.retry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Obx(() {
      if (_ctrl.items.isEmpty) return const SizedBox(height: 96);
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accent));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextButton(
            onPressed: _ctrl.retryLoadMore,
            child: Text(
              "Couldn't load more. Tap to retry",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: _accentDark),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 96),
        child: SizedBox(height: 36, child: child),
      );
    });
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
          boxShadow: AppShadows.premium(AppColors.primary, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
