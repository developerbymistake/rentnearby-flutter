import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_shadows.dart';
import '../../../config/app_tabs.dart';
import '../../../config/module_palette.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../../navigation/tour_keys.dart';
import '../../../screens/explore_location_search_mixin.dart';
import '../../../widgets/add_listing_shortcut_button.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/listing_grid_card.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../../widgets/selectable_chip.dart';
import '../../jobs/controllers/my_jobs_controller.dart';
import '../setup/stay_option_sets.dart';
import '../setup/stay_flow.dart';
import '../stay_types_controller.dart';
import 'stay_filter_sort_sheet.dart';
import 'stay_landing_controller.dart';
import 'stay_navigation.dart';

const _kGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 190,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  mainAxisExtent: ListingGridCard.height,
);

const _kAccent = StayColors.accent;
const _kAccentDark = StayColors.accentDark;
const _kGradient = StayColors.gradient;
const _kMapGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.accentLight, AppColors.accent],
);
const _kMineGradient = AppColors.warningGradient;

void _openMyStays() => Get.toNamed(AppRoutes.myStays);

class StayLandingScreen extends StatefulWidget {
  const StayLandingScreen({super.key});

  @override
  State<StayLandingScreen> createState() => _StayLandingScreenState();
}

class _StayLandingScreenState extends State<StayLandingScreen> with ExploreLocationSearchMixin<StayLandingScreen> {
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
  ModulePalette get searchPalette => StayColors.palette;

  void _viewDetails(BrowseItem item) => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': item.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _kAccent,
            onRefresh: _ctrl.pullRefresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: _buildReviewStrip()),
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
                key: TourKeys.staysLandingMapPill,
                label: 'Map view',
                icon: Icons.map_outlined,
                gradient: _kGradient,
                onTap: StayNavigation.openMap,
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
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _kGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
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
                              Get.find<TabConfigController>().displayNameForIndex(AppTabs.stays, 'Stays'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                            )),
                        const SizedBox(height: 2),
                        Text(
                          'Find stays near you',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  KeyedSubtree(key: TourKeys.staysLandingSearch, child: _buildSearchButton()),
                ],
              ),
              const SizedBox(height: 18),
              KeyedSubtree(key: TourKeys.staysLandingLocation, child: _buildCityDropdown()),
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
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kAccentDark),
                )
              : active
                  ? const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 15, color: _kAccentDark),
                        SizedBox(width: 5),
                        Text(
                          'Search',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: _kAccentDark),
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
                  child: Icon(Icons.chevron_right_rounded, size: 14, color: _kAccentDark.withValues(alpha: 0.6)),
                ),
              ),
              TextSpan(text: cityName),
            ];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: searching ? null : () => LocationSwitchSheet.show(context, palette: StayColors.palette),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.premium(_kAccent, alpha: 0.16, blur: 16, offset: const Offset(0, 6)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 17, color: _kAccentDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spans),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _kAccentDark),
                ),
              ),
              if (!searching)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: AppColors.neutralChip, shape: BoxShape.circle),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _kAccentDark),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildReviewStrip() {
    return Obx(() {
      final pending = _auth.staysEnabled && _auth.user.value?.stayStatus == 'PendingReview';
      if (!pending) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kAccent.withValues(alpha: 0.35)),
          ),
          child: const Row(
            children: [
              Icon(Iconsax.clock, size: 20, color: _kAccentDark),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Under review',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _kAccentDark)),
                    Text('We will notify you',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textMedium)),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      icon: Iconsax.house_2,
      gradient: _kMineGradient,
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
              icon: Iconsax.briefcase,
              gradient: _kGradient,
              onTap: _postJob,
            ),
            _OptionTile(
              label: 'My Jobs',
              icon: Iconsax.task_square,
              gradient: _kMapGradient,
              onTap: () => Get.toNamed(AppRoutes.myJobs),
            ),
          ],
        ];
      } else {
        final draft = _auth.user.value?.stayStatus == 'Draft';
        tiles = [
          _OptionTile(
            label: draft ? 'Continue setup' : 'Add Stay',
            icon: draft ? Iconsax.edit_2 : Iconsax.add,
            gradient: _kGradient,
            onTap: StayFlow.start,
          ),
          myStays,
        ];
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: KeyedSubtree(key: TourKeys.staysLandingTiles, child: _tileRow(tiles)),
      );
    });
  }

  Widget _tileRow(List<Widget> tiles) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  Widget _buildTypeChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: KeyedSubtree(
        key: TourKeys.staysLandingFilters,
        child: SizedBox(
          height: 17 + MediaQuery.textScalerOf(context).scale(17),
          child: Obx(() {
            final types = _types.types;
            final selected = _ctrl.selectedStayTypeId.value;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: types.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final String? id = i == 0 ? null : types[i - 1].id;
                return SelectableChip(
                  label: i == 0 ? 'All' : types[i - 1].name,
                  selected: selected == id,
                  activeColor: _kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Stays near you',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
          GestureDetector(
            key: TourKeys.staysLandingSort,
            onTap: () => StayFilterSortSheet.show(context, controller: _ctrl),
            child: Obx(() {
              final meals = _ctrl.selectedMeals.value;
              final type = _ctrl.selectedStayTypeId.value;
              final sort = _ctrl.sortBy.value;
              final active = meals != null || type != null || sort != StayLandingController.defaultSort;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? _kAccent.withValues(alpha: 0.10) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? _kAccent : AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 14, color: _kAccentDark),
                    const SizedBox(width: 5),
                    const Text(
                      'Filter & Sort',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: _kAccentDark),
                    ),
                    if (active) ...[
                      const SizedBox(width: 5),
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
                isPlot: false,
                accent: _kAccent,
                accentDark: _kAccentDark,
                isFeatured: item.isFeatured,
                onViewDetails: () => _viewDetails(item),
              );
              return i == 0 ? KeyedSubtree(key: TourKeys.staysLandingList, child: card) : card;
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: Column(
          children: [
            Icon(failed ? Icons.cloud_off_rounded : Icons.search_off_rounded, size: 40, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(
              failed ? "Couldn't load stays" : 'No stays found',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
            const SizedBox(height: 4),
            Text(
              failed ? 'Check your connection and try again' : 'Try other filters or a different location',
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
                  gradient: _kGradient,
                  shadowColor: _kAccent,
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
        child = const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextButton(
            onPressed: _ctrl.retryLoadMore,
            child: const Text(
              "Couldn't load more. Tap to retry",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: _kAccentDark),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
          boxShadow: AppShadows.premium(_kAccent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
              ),
              child: Icon(icon, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
