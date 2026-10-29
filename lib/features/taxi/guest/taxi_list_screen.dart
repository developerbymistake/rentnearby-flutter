import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/place_result_model.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/location_search_sheet.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'taxi_card.dart';
import 'taxi_list_controller.dart';
import 'taxi_navigation.dart';

class TaxiListScreen extends StatefulWidget {
  const TaxiListScreen({super.key});

  @override
  State<TaxiListScreen> createState() => _TaxiListScreenState();
}

class _TaxiListScreenState extends State<TaxiListScreen> {
  late final TaxiListController _ctrl;
  final _scroll = ScrollController();
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<TaxiListController>(tag: TaxiListController.tag)
        ? Get.find<TaxiListController>(tag: TaxiListController.tag)
        : Get.put(TaxiListController(), tag: TaxiListController.tag);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    Get.delete<TaxiListController>(tag: TaxiListController.tag);
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
      final picked = await LocationSearchSheet.show(
        context,
        bias: Get.find<LocationController>().effectiveSearchCenter,
      );
      if (picked == null || !mounted) return;
      if (picked.name.trim().isEmpty) {
        AppToast.warning('Pick a place from the list');
        return;
      }
      final other = isFrom ? _ctrl.to.value : _ctrl.from.value;
      if (_ctrl.isTooClose(picked, other)) {
        AppToast.warning('From and To must be different places');
        return;
      }
      if (isFrom) {
        _ctrl.setFrom(picked);
      } else {
        _ctrl.setTo(picked);
      }
    } finally {
      _picking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        color: TaxiColors.accent,
        onRefresh: _ctrl.pullRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildRouteCard()),
            SliverToBoxAdapter(child: _buildListHeader()),
            _buildBody(),
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: TaxiColors.gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                  'Taxi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Obx(() => Text(
                      _ctrl.isSearch ? 'Taxis for your route' : 'Local taxis near you',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    )),
              ]),
            ),
          ]),
          Obx(() => _ctrl.isSearch
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(left: 8, top: 14),
                  child: _buildDistrictPill(),
                )),
        ],
      ),
    );
  }

  Widget _buildDistrictPill() {
    final loc = Get.find<LocationController>();
    return Obx(() {
      final district = loc.effectiveDistrict;
      final cityName = loc.effectiveCity?.name ?? 'Current';
      final searchLabel = loc.searchPinLabel.value;
      final searching = searchLabel != null;
      final List<InlineSpan> spans = searching || district == null
          ? [TextSpan(text: searchLabel ?? 'Pick a district')]
          : [
              TextSpan(text: district.name),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded, size: 14, color: TaxiColors.accentDark.withValues(alpha: 0.6)),
                ),
              ),
              TextSpan(text: cityName),
            ];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: searching ? null : () => LocationSwitchSheet.show(context),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.16, blur: 16, offset: const Offset(0, 6)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 17, color: TaxiColors.accentDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spans),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
                ),
              ),
              if (!searching)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: TaxiColors.accentDark),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRouteCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.08, blur: 14, offset: const Offset(0, 5)),
        ),
        child: Obx(() => Column(children: [
              _endpointRow(
                label: 'From',
                placeholder: 'Pick where you start',
                icon: Icons.trip_origin_rounded,
                place: _ctrl.from.value,
                onTap: () => _pick(isFrom: true),
                onClear: _ctrl.clearFrom,
              ),
              const Divider(height: 1, indent: 48, color: AppColors.divider),
              _endpointRow(
                label: 'To',
                placeholder: 'Pick where you go',
                icon: Icons.location_on_rounded,
                place: _ctrl.to.value,
                onTap: () => _pick(isFrom: false),
                onClear: _ctrl.clearTo,
              ),
            ])),
      ),
    );
  }

  Widget _endpointRow({
    required String label,
    required String placeholder,
    required IconData icon,
    required PlaceResult? place,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final set = place != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Icon(icon, size: 18, color: TaxiColors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
              Text(
                place != null ? place.name : placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: set ? FontWeight.w600 : FontWeight.w400,
                  color: set ? AppColors.textDark : AppColors.textHint,
                ),
              ),
              if (place != null && place.subtitle.isNotEmpty)
                Text(place.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
            ]),
          ),
          if (set)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Iconsax.search_normal, size: 18, color: AppColors.textHint),
            ),
        ]),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _ctrl.isSearch ? 'Taxis for this route' : 'Taxis near you',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            if (_ctrl.hasOneEndpoint)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Pick both From and To to search a route',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                ),
              ),
          ])),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.noDistrict.value) {
          return SliverToBoxAdapter(
            child: _buildMessage(
              icon: Icons.location_off_outlined,
              title: 'Pick a district',
              subtitle: 'Choose where to find taxis',
            ),
          );
        }
        if (_ctrl.isLoading.value) return _buildShimmer();
        final failed = _ctrl.loadFailed.value;
        return SliverToBoxAdapter(
          child: _buildMessage(
            icon: failed ? Icons.cloud_off_rounded : Iconsax.car,
            title: failed ? "Couldn't load taxis" : 'No taxis here yet',
            subtitle: failed ? 'Check your connection and try again' : 'Try another city or route',
            onRetry: failed ? _ctrl.retry : null,
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = items[i];
            return TaxiCard(key: ValueKey(t.id), item: t, onOpen: () => _open(t));
          },
        ),
      );
    });
  }

  Widget _buildShimmer() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      sliver: SliverList.separated(
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 170,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: GradientButton(
                label: 'Retry',
                height: 42,
                gradient: TaxiColors.gradient,
                shadowColor: TaxiColors.accent,
                onPressed: onRetry,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Obx(() {
      if (_ctrl.items.isEmpty) return const SizedBox(height: 32);
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = Center(child: CircularProgressIndicator(strokeWidth: 2, color: TaxiColors.accent));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextButton(
            onPressed: _ctrl.retryLoadMore,
            child: Text(
              "Couldn't load more. Tap to retry",
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TaxiColors.accentDark),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        child: SizedBox(height: 36, child: child),
      );
    });
  }
}
