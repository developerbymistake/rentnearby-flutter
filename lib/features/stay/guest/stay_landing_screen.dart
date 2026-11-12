import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../../navigation/tour_keys.dart';
import '../../../screens/explore_location_search_mixin.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../jobs/controllers/my_jobs_controller.dart';
import '../setup/stay_flow.dart';
import '../stay_types_controller.dart';
import 'stay_filter_sort_sheet.dart';
import 'stay_landing_controller.dart';
import 'stay_navigation.dart';

const _kAccent = DesignColors.primary;
const _kSections = 5;
const _kTone = KitTone.stay;

void _openMyStays() => Get.toNamed(AppRoutes.myStays);

class StayLandingScreen extends StatefulWidget {
  const StayLandingScreen({super.key});

  @override
  State<StayLandingScreen> createState() => _StayLandingScreenState();
}

class _StayLandingScreenState extends State<StayLandingScreen>
    with ExploreLocationSearchMixin<StayLandingScreen> {
  late final StayLandingController _ctrl;
  final _auth = Get.find<AuthController>();
  final _types = StayTypesController.ensure();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<StayLandingController>(tag: StayLandingController.tag)
        ? Get.find<StayLandingController>(tag: StayLandingController.tag)
        : Get.put(StayLandingController(), tag: StayLandingController.tag);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    Get.delete<StayLandingController>(tag: StayLandingController.tag);
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent * 0.7) _ctrl.loadNextPage();
  }

  @override
  get searchPalette => templateModulePalette;

  void _viewDetails(BrowseItem item) => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': item.id});

  Widget _section(int i, Widget child) => StaggerItem(index: i, child: child);

  @override
  Widget build(BuildContext context) {
    final bottom = BarMetrics.bodyBottomOf(context);
    return TabEntrance(
      tab: AppTabs.stays,
      child: Scaffold(
        backgroundColor: DesignColors.scaffold,
        body: StaggerHost(
          count: _kSections,
          child: Stack(
            children: [
              RefreshIndicator(
                color: _kAccent,
                onRefresh: _ctrl.pullRefresh,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(child: _section(0, _buildHeader(context))),
                    SliverToBoxAdapter(child: _section(1, _buildReviewStrip())),
                    SliverToBoxAdapter(child: _section(2, _buildTiles())),
                    SliverToBoxAdapter(child: _section(3, _buildTypeChips())),
                    SliverToBoxAdapter(child: _section(4, _buildListHeader())),
                    _buildBody(),
                    SliverToBoxAdapter(child: _buildFooter(bottom)),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottom,
                child: Center(
                  child: EntranceOnce(
                    index: 3,
                    offset: 24,
                    child: PressScale(
                      child: StayFloatingPill(
                        key: TourKeys.staysLandingMapPill,
                        label: 'Map view',
                        onTap: StayNavigation.openMap,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Obx(() => ModuleHeader(
          tone: _kTone,
          tabRoot: true,
          animate: false,
          title: Get.find<TabConfigController>().displayNameForIndex(AppTabs.stays, 'Stays'),
          subtitle: 'Find stays near you',
          trailing: [KeyedSubtree(key: TourKeys.staysLandingSearch, child: _buildSearchButton())],
          bottomHeight: 46 + 12,
          bottom: Padding(
            padding: const EdgeInsets.only(left: 12, top: 12),
            child: KeyedSubtree(key: TourKeys.staysLandingLocation, child: _buildCityDropdown()),
          ),
        ));
  }

  Widget _buildSearchButton() {
    return Obx(() {
      final active = isSearchActive;
      final resolving = searchResolving;
      return PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: resolving ? null : () => onSearchToggleTap(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? DesignColors.error : DesignColors.surface,
              borderRadius: CardRadius.pill,
              boxShadow: ShadowTokens.elev1,
            ),
            child: resolving
                ? const KitDots(color: _kAccent, size: 6)
                : active
                    ? Text('Cancel', style: TypeTokens.style(12, FontWeight.w700, color: DesignColors.onPrimary))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_rounded, size: 16, color: _kAccent),
                          const SizedBox(width: 5),
                          Text('Search', style: TypeTokens.style(12, FontWeight.w700, color: _kAccent)),
                        ],
                      ),
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
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded, size: 14, color: DesignColors.textSecondary),
                ),
              ),
              TextSpan(text: cityName),
            ];
      return PressScale(
        enabled: !searching,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: searching ? null : () => LocationSwitchSheet.show(context, palette: templateModulePalette),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: CardRadius.pill,
              boxShadow: ShadowTokens.elev1,
            ),
            child: Row(
              children: [
                const TravelIcon(TravelIcon.place, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: spans),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(14, FontWeight.w500, color: _kAccent),
                  ),
                ),
                if (!searching)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(color: DesignColors.scaffold, shape: BoxShape.circle),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _kAccent),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildReviewStrip() {
    return Obx(() {
      final pending = _auth.staysEnabled && _auth.user.value?.stayStatus == 'PendingReview';
      if (!pending) return const SizedBox.shrink();
      return const SlimBar(
        tone: _kTone,
        margin: EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 0),
        leadingAsset: TravelIcon.note,
        title: 'Under review',
        subtitle: 'We will notify you',
      );
    });
  }

  Future<void> _postJob() async {
    final result = await Get.toNamed(AppRoutes.postJob);
    if (result == true) MyJobsController.invalidateList();
  }

  Widget _buildTiles() {
    const myStays = _OptionTile(
      label: 'My Stays',
      icon: TravelIcon.stay,
      start: TravelPalette.sunriseStart,
      end: TravelPalette.sunriseEnd,
      onTap: _openMyStays,
    );
    return Obx(() {
      if (!_auth.staysEnabled) return const SizedBox.shrink();
      final List<Widget> tiles;
      if (_auth.user.value?.stayStatus == 'Approved') {
        tiles = [
          myStays,
          if (_auth.jobsEnabled) ...[
            _OptionTile(
              label: 'Post a Job',
              icon: TravelIcon.money,
              start: TravelPalette.roseStart,
              end: TravelPalette.roseEnd,
              onTap: _postJob,
            ),
            _OptionTile(
              label: 'My Jobs',
              icon: TravelIcon.checkout,
              start: TravelPalette.duskStart,
              end: TravelPalette.duskEnd,
              onTap: () => Get.toNamed(AppRoutes.myJobs),
            ),
          ],
        ];
      } else {
        final draft = _auth.user.value?.stayStatus == 'Draft';
        tiles = [
          _OptionTile(
            label: draft ? 'Continue setup' : 'Add Stay',
            icon: draft ? TravelIcon.note : TravelIcon.stay,
            start: TravelPalette.skyStart,
            end: TravelPalette.skyEnd,
            onTap: StayFlow.start,
          ),
          myStays,
        ];
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 0),
        child: KeyedSubtree(key: TourKeys.staysLandingTiles, child: _tileRow(tiles)),
      );
    });
  }

  Widget _tileRow(List<Widget> tiles) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  Widget _buildTypeChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KeyedSubtree(
        key: TourKeys.staysLandingFilters,
        child: SizedBox(
          height: 30 + MediaQuery.textScalerOf(context).scale(17),
          child: Obx(() {
            final types = _types.types;
            final selected = _ctrl.selectedStayTypeId.value;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
              itemCount: types.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final String? id = i == 0 ? null : types[i - 1].id;
                final chip = PickChip(
                  label: i == 0 ? 'All' : types[i - 1].name,
                  selected: selected == id,
                  activeColor: _kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
                  onTap: () => _ctrl.setStayType(id),
                );
                return i < 8 ? EntranceOnce(index: i, offset: 0, dx: 60, child: chip) : chip;
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Stays near you',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeTokens.title,
            ),
          ),
          PressScale(
            child: GestureDetector(
              key: TourKeys.staysLandingSort,
              onTap: () => StayFilterSortSheet.show(context, controller: _ctrl),
              child: Obx(() {
                final meals = _ctrl.selectedMeals.value;
                final type = _ctrl.selectedStayTypeId.value;
                final sort = _ctrl.sortBy.value;
                final active = meals != null || type != null || sort != StayLandingController.defaultSort;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _kTone.tint : DesignColors.surface,
                    borderRadius: CardRadius.pill,
                    border: Border.all(color: active ? _kAccent : DesignColors.divider, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Filter & Sort', style: TypeTokens.style(13, FontWeight.w600, color: _kAccent)),
                      const SizedBox(width: 6),
                      const Icon(Icons.sort_rounded, size: 16, color: _kAccent),
                      if (active) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                );
              }),
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
        if (_ctrl.isLoading.value) return _buildSkeletonGrid();
        return SliverToBoxAdapter(child: _buildMessage(failed: _ctrl.loadFailed.value));
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 8, KitMetrics.gutter, 0),
        sliver: SliverGrid(
          gridDelegate: RailCard.gridDelegate(),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final item = items[i];
              Widget card = StayGridCard(
                key: ValueKey(item.id),
                thumbnailUrl: item.thumbnailUrl,
                tagLabel: item.tagLabel,
                title: item.title,
                locationLabel: item.locationLabel,
                facts: item.facts,
                priceCaption: item.priceCaption,
                priceValue: item.priceValue,
                priceUnit: item.priceUnit,
                isFeatured: item.isFeatured,
                onViewDetails: () => _viewDetails(item),
              );
              if (i < 10) card = KitCardEntrance(key: ValueKey(item.id), index: i, child: card);
              return i == 0 ? KeyedSubtree(key: TourKeys.staysLandingList, child: card) : card;
            },
            childCount: items.length,
            addAutomaticKeepAlives: false,
          ),
        ),
      );
    });
  }

  Widget _buildSkeletonGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 8, KitMetrics.gutter, 0),
      sliver: SliverGrid(
        gridDelegate: RailCard.gridDelegate(),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final cell = RailCard.skeleton();
            return i == 0 ? KeyedSubtree(key: TourKeys.staysLandingList, child: cell) : cell;
          },
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildMessage({required bool failed}) {
    return KeyedSubtree(
      key: TourKeys.staysLandingList,
      child: failed
          ? StateCard.error(
              kit: _kTone,
              title: "Couldn't load stays",
              message: 'Check your connection and try again',
              actionLabel: 'Retry',
              onAction: _ctrl.retry,
            )
          : const StateCard(
              kit: _kTone,
              asset: TravelIcon.stay,
              title: 'No stays found',
              message: 'Try other filters or a different location',
            ),
    );
  }

  Widget _buildFooter(double bottom) {
    return Obx(() {
      if (_ctrl.items.isEmpty) return SizedBox(height: bottom + 64);
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = const Center(child: KitDots(color: _kAccent));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextLink(label: "Couldn't load more. Tap to retry", onTap: _ctrl.retryLoadMore, tone: _kTone),
        );
      }
      return Padding(
        padding: EdgeInsets.only(top: 12, bottom: bottom + 64),
        child: SizedBox(height: 36, child: child),
      );
    });
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String icon;
  final Color start;
  final Color end;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.start,
    required this.end,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SectionTile(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [start, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: TravelIcon(icon, size: 36),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: TypeTokens.style(12, FontWeight.w700, color: DesignColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
