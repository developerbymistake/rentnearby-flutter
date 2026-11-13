import 'package:bakhli/design/design.dart';
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
import 'stay_card_actions.dart';
import 'stay_feed_item.dart';
import 'stay_landing_controller_v2.dart';

const _kSections = 4;
// WideCard price row overflows past this scale on 300 dp phones.
const _kCardMaxScale = 1.6;
const _kTone = KitTone.stay;
const _kStickers = [ListingArt.key, ListingArt.bed, ListingArt.hotel];
const _kTypeArt = [ListingArt.bed, ListingArt.hotel, ListingArt.beach, ListingArt.tent, ListingArt.camping, ListingArt.key];

ListingTone get _page => ListingTone.forest;
List<ListingTone> get _typeTones => [ListingTone.cA, ListingTone.cB, ListingTone.cC, ListingTone.cF, ListingTone.cD];

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
    final top = MediaQuery.paddingOf(context).top;
    return TabEntrance(
      tab: AppTabs.stays,
      child: Scaffold(
        backgroundColor: ListingPalette.forest.page,
        body: KitStatusBar(
          lightIcons: false,
          child: StaggerHost(
            count: _kSections,
            child: Stack(
              children: [
                RefreshIndicator(
                  color: _page.g2,
                  edgeOffset: top,
                  onRefresh: _ctrl.pullRefresh,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      _ctrl.onScrollMetrics(n.metrics);
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      slivers: [
                        SliverToBoxAdapter(child: SizedBox(height: top)),
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
                  top: 0,
                  height: top,
                  child: ColoredBox(color: ListingPalette.forest.page),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: OverlayInsets.pillBottom(context),
                  child: Center(
                    child: EntranceOnce(
                      index: 3,
                      offset: 24,
                      child: MapPill3D(key: TourKeys.staysLandingMapPill, tone: _page, label: 'Map view', onTap: StayNavigation.openMap),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(
          () => ModuleTitleBar(
            tone: _page,
            art: ListingArt.hotel,
            title: Get.find<TabConfigController>().displayNameForIndex(AppTabs.stays, 'Stays'),
            subtitle: (_ctrl.header.value?.farAway ?? false) ? 'Find the nearest stays' : 'Find stays near you',
          ),
        ),
        _buildSearchPill(),
      ],
    );
  }

  Widget _buildSearchPill() {
    final loc = Get.find<LocationController>();
    return Obx(() {
      final active = isSearchActive;
      final resolving = searchResolving;
      final district = loc.effectiveDistrict;
      final searchLabel = loc.searchPinLabel.value;
      final searching = searchLabel != null;
      final String value;
      if (district == null) {
        value = '';
      } else if (searching) {
        value = searchLabel;
      } else {
        final cityName = loc.browsingCity.value?.name ?? loc.autoCity.value?.name ?? 'Current';
        value = '${district.name} › $cityName';
      }
      final Widget? buttonChild = resolving
          ? const KitDots(color: DesignColors.onPrimary, size: 6)
          : active
          ? const Icon(Icons.close_rounded, color: DesignColors.onPrimary, size: 26)
          : null;
      return KeyedSubtree(
        key: TourKeys.staysLandingLocation,
        child: SearchPill(
          tone: _page,
          label: district == null ? null : 'City',
          value: value,
          leadingArt: district == null ? null : ListingArt.roundPushpin,
          buttonArt: ListingArt.compass,
          buttonKey: TourKeys.staysLandingSearch,
          buttonChild: buttonChild,
          buttonSemantics: active ? 'Cancel' : 'Search',
          onTap: district == null || searching ? null : () => LocationSwitchSheet.show(context, palette: templateModulePalette),
          onButtonTap: resolving ? () {} : () => onSearchToggleTap(context),
        ),
      );
    });
  }

  Widget _buildReviewStrip() {
    return Obx(() {
      final pending = _auth.staysEnabled && _auth.user.value?.stayStatus == 'PendingReview';
      if (!pending) return const SizedBox.shrink();
      return WideCard(kind: WideKind.slim, tone: ListingTone.cF, art: ListingArt.clipboard, title: 'Under review', subtitle: 'We will notify you');
    });
  }

  Future<void> _postJob() async {
    final result = await Get.toNamed(AppRoutes.postJob);
    if (result == true) MyJobsController.invalidateList();
  }

  Widget _tile({required String title, required String sub, required String art, required ListingTone tone, required VoidCallback onTap, bool plus = false, double width = 160}) =>
      MealsCardV(width: width, tone: tone, art: art, title: title, description: sub, goIcon: plus ? Icons.add : Icons.arrow_forward, onTap: onTap, semanticsLabel: title);

  Widget _buildTiles() {
    return Obx(() {
      if (!_auth.staysEnabled) return const SizedBox.shrink();
      final List<Widget> tiles;
      final w2 = ((MediaQuery.sizeOf(context).width - 20) / 2).clamp(120.0, 160.0);
      if (_auth.user.value?.stayStatus == 'Approved') {
        tiles = [
          _tile(title: 'My Stays', sub: 'Your listings', art: ListingArt.hotel, tone: ListingTone.cE, onTap: _openMyStays),
          if (_auth.jobsEnabled) ...[
            _tile(title: 'Post a Job', sub: 'Hire staff', art: ListingArt.clipboard, tone: ListingTone.cA, onTap: _postJob, plus: true),
            _tile(title: 'My Jobs', sub: 'Your job posts', art: ListingArt.luggage, tone: ListingTone.cD, onTap: () => Get.toNamed(AppRoutes.myJobs)),
          ],
        ];
      } else {
        final draft = _auth.user.value?.stayStatus == 'Draft';
        tiles = [
          _tile(
            title: draft ? 'Continue setup' : 'Add Stay',
            sub: draft ? 'Finish your stay' : 'List your stay',
            art: draft ? ListingArt.clipboard : ListingArt.hotel,
            tone: ListingTone.cE,
            onTap: StayFlow.start,
            plus: !draft,
            width: w2,
          ),
          _tile(title: 'My Stays', sub: 'Your listings', art: ListingArt.bed, tone: ListingTone.cA, onTap: _openMyStays, width: w2),
        ];
      }
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: KeyedSubtree(
          key: TourKeys.staysLandingTiles,
          child: MealsRail(children: tiles),
        ),
      );
    });
  }

  Widget _buildTypeChips() {
    return KeyedSubtree(
      key: TourKeys.staysLandingFilters,
      child: Obx(() {
        final types = _types.types;
        final selected = _ctrl.selectedStayTypeId.value;
        return ChipCPRow(
          children: [
            for (var i = 0; i <= types.length; i++)
              () {
                final String? id = i == 0 ? null : types[i - 1].id;
                return ChipCP(
                  tone: i == 0 ? ListingTone.cE : _typeTones[(i - 1) % _typeTones.length],
                  art: i == 0 ? ListingArt.sunrise : _kTypeArt[(i - 1) % _kTypeArt.length],
                  label: i == 0 ? 'All' : types[i - 1].name,
                  off: selected != id,
                  onTap: () => _ctrl.setStayType(id),
                );
              }(),
          ],
        );
      }),
    );
  }

  Widget _buildListHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(() {
          final centre = NearbyCentreController.to;
          centre.centreVersion.value;
          final pin = centre.hasPin ? centre.pinLabel : null;
          final far = _ctrl.header.value?.farAway ?? false;
          final title = pin == null ? (far ? NearbyStrings.staysNearest : NearbyStrings.staysNear) : (far ? NearbyStrings.staysNearestToPlace(pin) : NearbyStrings.staysNearPlace(pin));
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: Ink3D.text(18, FontWeight.w600, Ink3D.body, letterSpacing: 0.4, height: 1.3)),
                ),
                _buildFilterButton(),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Obx(() {
            final centre = NearbyCentreController.to;
            centre.centreVersion.value;
            return NearbyHeaderStrip(header: _ctrl.header.value, hasPin: centre.hasPin);
          }),
        ),
      ],
    );
  }

  Widget _buildFilterButton() {
    return KeyedSubtree(
      key: TourKeys.staysLandingSort,
      child: Obx(() {
        final active = _ctrl.selectedMeals.value != null || _ctrl.selectedStayTypeId.value != null || _ctrl.sortBy.value != StayLandingControllerV2.defaultSort;
        return ListingFilterChip(
          tone: _page,
          label: 'Filter & Sort',
          icon: Icons.sort_rounded,
          dot: active,
          onTap: () => StayFilterSortSheet.show(context, controller: _ctrl),
        );
      }),
    );
  }

  Widget _card(StayFeedItem s, ListingTone tone, int index) {
    final b = s.item;
    final url = b.thumbnailUrl;
    return MediaQuery.withClampedTextScaling(
      key: ValueKey(b.id),
      maxScaleFactor: _kCardMaxScale,
      child: Obx(() => WideCard(
        tone: tone,
        kind: WideKind.photo,
        photo: url == null || url.isEmpty
            ? null
            : SizedBox.expand(
                child: KitPhoto(url: url, width: double.infinity, height: double.infinity),
              ),
        sticker: _kStickers[index % _kStickers.length],
        badge: b.isFeatured ? 'Featured' : null,
        tag: b.tagLabel,
        title: b.title,
        subtitle: b.locationLabel,
        chips: [for (final f in b.facts.take(3)) f.label],
        priceCaption: b.priceCaption,
        number: b.priceValue,
        unit: b.priceUnit,
        label: NearbyLabelText.textFor(s.distance),
        labelNote: s.distance.isFar ? NearbyStrings.byRoad : null,
        actions: stayContactActions(context, s.id),
        onTap: () => _viewDetails(s),
      )),
    );
  }

  Widget _buildFeatured() {
    return Obx(() {
      final f = _ctrl.featured.toList();
      return NearbyFeaturedSlot<StayFeedItem>(items: f, builder: (context, s) => _card(s, _page, f.indexOf(s)));
    });
  }

  bool get _filtered => _ctrl.selectedMeals.value != null || _ctrl.selectedStayTypeId.value != null;

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.sorted(_ctrl.items.toList());
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) return _buildSkeleton();
        if (_ctrl.loadFailed.value) {
          return SliverToBoxAdapter(
            child: KeyedSubtree(
              key: TourKeys.staysLandingList,
              child: NearbyError(onRetry: _ctrl.retry, tone: ListingTone.forest),
            ),
          );
        }
        if (_ctrl.featured.isEmpty) {
          return SliverToBoxAdapter(
            child: KeyedSubtree(
              key: TourKeys.staysLandingList,
              child: _filtered
                  ? NearbyEmpty(title: 'No stays found', body: 'Try other filters or a different location', tone: ListingTone.forest)
                  : NearbyEmpty(title: NearbyStrings.staysEmptyTitle, body: NearbyStrings.staysEmptyBody, tone: ListingTone.forest),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final card = _card(items[i], ListingTone.list(_page, i), i);
            return i == 0 ? KeyedSubtree(key: TourKeys.staysLandingList, child: card) : card;
          },
          childCount: items.length,
          addAutomaticKeepAlives: false,
        ),
      );
    });
  }

  Widget _buildSkeleton() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((_, i) {
        const cell = WideCardSkeleton(kind: WideKind.photo);
        return i == 0 ? KeyedSubtree(key: TourKeys.staysLandingList, child: cell) : cell;
      }, childCount: 4),
    );
  }

  Widget _buildFooter(double bottom) {
    return Obx(() {
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = Center(child: KitDots(color: _page.g2));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextLink(label: "Couldn't load more. Tap to retry", onTap: _ctrl.loadNextPage, tone: _kTone),
        );
      } else if (_ctrl.isThin) {
        child = const NearbyThin();
      }
      return Padding(
        padding: EdgeInsets.only(top: 12, bottom: bottom + 64 + (_ctrl.items.isEmpty || _ctrl.isThin ? 96 : 0)),
        child: child,
      );
    });
  }
}
