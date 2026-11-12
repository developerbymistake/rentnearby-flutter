import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/location_controller.dart';
import '../../../../controllers/tab_config_controller.dart';
import '../../../../navigation/tour_keys.dart';
import '../../../jobs/controllers/my_jobs_controller.dart';
import '../../../nearby/controllers/nearby_centre_controller.dart';
import '../../../nearby/nearby_strings.dart';
import '../../../nearby/widgets/nearby_featured_slot.dart';
import '../../../nearby/widgets/nearby_header_strip.dart';
import '../../../nearby/widgets/nearby_label_text.dart';
import '../../../nearby/widgets/nearby_state_views.dart';
import '../../../../screens/explore_location_search_mixin.dart';
import '../../../../widgets/location_switch_sheet.dart';
import '../../setup/stay_flow.dart';
import '../../stay_types_controller.dart';
import '../stay_filter_sort_sheet.dart';
import '../stay_navigation.dart';
import 'stay_feed_item.dart';
import 'stay_landing_controller_v2.dart';

const _kAccent = DesignColors.primary;
const _kSections = 4;
const _kTone = KitTone.stay;

void _openMyStays() => Get.toNamed(AppRoutes.myStays);

class StayLandingScreenV2 extends StatefulWidget {
  const StayLandingScreenV2({super.key});

  @override
  State<StayLandingScreenV2> createState() => _StayLandingScreenV2State();
}

class _StayLandingScreenV2State extends State<StayLandingScreenV2> with ExploreLocationSearchMixin<StayLandingScreenV2> {
  late final StayLandingControllerV2 _ctrl;
  final _auth = Get.find<AuthController>();
  final _types = StayTypesController.ensure();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<StayLandingControllerV2>(tag: StayLandingControllerV2.tag)
        ? Get.find<StayLandingControllerV2>(tag: StayLandingControllerV2.tag)
        : Get.put(StayLandingControllerV2(), tag: StayLandingControllerV2.tag);
    _types.ensureLoaded();
    _ctrl.refreshOwnerStatus();
  }

  @override
  void dispose() {
    Get.delete<StayLandingControllerV2>(tag: StayLandingControllerV2.tag);
    super.dispose();
  }

  @override
  get searchPalette => templateModulePalette;

  void _viewDetails(StayFeedItem s) => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id});

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
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    _ctrl.onScrollMetrics(n.metrics);
                    return false;
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(child: _section(0, _buildHeader())),
                      SliverToBoxAdapter(child: _section(1, _buildReviewStrip())),
                      SliverToBoxAdapter(child: _section(2, _buildTiles())),
                      SliverToBoxAdapter(child: _section(3, _buildTypeChips())),
                      SliverToBoxAdapter(child: _buildListHeader()),
                      SliverToBoxAdapter(child: _buildFeatured()),
                      _buildBody(),
                      SliverToBoxAdapter(child: _buildFooter(bottom)),
                    ],
                  ),
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

  Widget _buildHeader() {
    return Obx(() => ModuleHeader(
          tone: _kTone,
          tabRoot: true,
          animate: false,
          title: Get.find<TabConfigController>().displayNameForIndex(AppTabs.stays, 'Stays'),
          subtitle: (_ctrl.header.value?.farAway ?? false) ? 'Find the nearest stays' : 'Find stays near you',
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
                return PickChip(
                  label: i == 0 ? 'All' : types[i - 1].name,
                  selected: selected == id,
                  activeColor: _kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
                  onTap: () => _ctrl.setStayType(id),
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
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  final centre = NearbyCentreController.to;
                  centre.centreVersion.value;
                  final pin = centre.hasPin ? centre.pinLabel : null;
                  final far = _ctrl.header.value?.farAway ?? false;
                  final title = pin == null
                      ? (far ? NearbyStrings.staysNearest : NearbyStrings.staysNear)
                      : (far ? NearbyStrings.staysNearestToPlace(pin) : NearbyStrings.staysNearPlace(pin));
                  return Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.title);
                }),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(),
            ],
          ),
          Obx(() {
            final centre = NearbyCentreController.to;
            centre.centreVersion.value;
            return NearbyHeaderStrip(header: _ctrl.header.value, hasPin: centre.hasPin);
          }),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PressScale(
      child: GestureDetector(
        key: TourKeys.staysLandingSort,
        onTap: () => StayFilterSortSheet.show(context, controller: _ctrl),
        child: Obx(() {
          final active = _ctrl.selectedMeals.value != null ||
              _ctrl.selectedStayTypeId.value != null ||
              _ctrl.sortBy.value != StayLandingControllerV2.defaultSort;
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
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle)),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _card(StayFeedItem s) {
    final b = s.item;
    return StayGridCard(
      key: ValueKey(b.id),
      thumbnailUrl: b.thumbnailUrl,
      tagLabel: b.tagLabel,
      title: b.title,
      locationLabel: b.locationLabel,
      facts: b.facts,
      priceCaption: b.priceCaption,
      priceValue: b.priceValue,
      priceUnit: b.priceUnit,
      isFeatured: b.isFeatured,
      onViewDetails: () => _viewDetails(s),
    );
  }

  Widget _tile(StayFeedItem s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: StayGridCard.heightOf(context), child: _card(s)),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: NearbyLabelText(distance: s.distance),
              ),
            ),
          ),
        ],
      );

  double _labelHeight(BuildContext context) => 12 + MediaQuery.textScalerOf(context).scale(14) * 6;

  Widget _buildFeatured() {
    return Obx(() {
      final f = _ctrl.featured.toList();
      return NearbyFeaturedSlot<StayFeedItem>(
        items: f,
        builder: (context, s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: RailCard.width,
              height: StayGridCard.heightOf(context) + _labelHeight(context),
              child: _tile(s),
            ),
          ),
        ),
      );
    });
  }

  bool get _filtered => _ctrl.selectedMeals.value != null || _ctrl.selectedStayTypeId.value != null;

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.sorted(_ctrl.items.toList());
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) return _buildSkeletonGrid();
        if (_ctrl.loadFailed.value) {
          return SliverToBoxAdapter(
            child: KeyedSubtree(key: TourKeys.staysLandingList, child: NearbyError(onRetry: _ctrl.retry)),
          );
        }
        if (_ctrl.featured.isEmpty) {
          return SliverToBoxAdapter(
            child: KeyedSubtree(
              key: TourKeys.staysLandingList,
              child: _filtered
                  ? const NearbyEmpty(title: 'No stays found', body: 'Try other filters or a different location')
                  : const NearbyEmpty(title: NearbyStrings.staysEmptyTitle, body: NearbyStrings.staysEmptyBody),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 8, KitMetrics.gutter, 0),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: RailCard.gridMaxExtent,
            mainAxisExtent: StayGridCard.heightOf(context) + _labelHeight(context),
            mainAxisSpacing: RailCard.gridSpacing,
            crossAxisSpacing: RailCard.gridSpacing,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final tile = _tile(items[i]);
              return i == 0 ? KeyedSubtree(key: TourKeys.staysLandingList, child: tile) : tile;
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

  Widget _buildFooter(double bottom) {
    return Obx(() {
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = const Center(child: KitDots(color: _kAccent));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextLink(label: "Couldn't load more. Tap to retry", onTap: _ctrl.loadNextPage, tone: _kTone),
        );
      } else if (_ctrl.isThin) {
        child = const NearbyThin();
      }
      return Padding(
        padding: EdgeInsets.only(top: 12, bottom: bottom + 64),
        child: child,
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
