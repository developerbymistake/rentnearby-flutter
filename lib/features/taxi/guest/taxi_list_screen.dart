import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../controllers/location_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/location_search_sheet.dart';
import '../../../widgets/selectable_chip.dart';
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
        bias: _ctrl.from.value?.latLng ?? Get.find<LocationController>().userLocation.value,
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
            SliverToBoxAdapter(child: _buildPlaceRows()),
            SliverToBoxAdapter(child: _buildCategoryChips()),
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
      padding: EdgeInsets.fromLTRB(12, top + 8, 20, 16),
      child: Row(children: [
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
                  _ctrl.to.value != null ? 'Taxis for your route' : 'Local taxis near you',
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
    );
  }

  Widget _buildPlaceRows() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Obx(() {
        final f = _ctrl.from.value;
        final t = _ctrl.to.value;
        return Column(children: [
          _placeRow(
            icon: Iconsax.location,
            text: f != null ? 'From: ${f.name}' : 'From: Select start',
            isSet: f != null,
            onTap: () => _pick(isFrom: true),
          ),
          const SizedBox(height: 8),
          _placeRow(
            icon: Iconsax.search_normal,
            text: t != null ? 'To: ${t.name}' : 'To: Select destination',
            isSet: t != null,
            onTap: () => _pick(isFrom: false),
            onClear: t != null ? _ctrl.clearTo : null,
          ),
        ]);
      }),
    );
  }

  Widget _buildCategoryChips() {
    const options = TaxiOptionSets.categories;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 17 + MediaQuery.textScalerOf(context).scale(17),
        child: Obx(() {
          final selected = _ctrl.category.value;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: options.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final value = i == 0 ? null : options[i - 1].value;
              return SelectableChip(
                label: i == 0 ? 'All' : options[i - 1].label,
                selected: selected == value,
                activeColor: TaxiColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                onTap: () => _ctrl.setCategory(value),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _placeRow({
    required IconData icon,
    required String text,
    required bool isSet,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Material(
      color: TaxiColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: EdgeInsets.only(left: 14, right: onClear != null ? 8 : 14),
            child: Row(children: [
              Icon(icon, size: 18, color: TaxiColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSet ? AppColors.textDark : AppColors.textHint,
                    ),
                  ),
                ),
              ),
              if (onClear != null)
                InkResponse(
                  onTap: onClear,
                  radius: 22,
                  child: const SizedBox(
                    width: 36,
                    height: 44,
                    child: Icon(Iconsax.close_circle, size: 18, color: AppColors.textHint),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Iconsax.gps, size: 18, color: TaxiColors.accentDark),
              if (onClear != null) const SizedBox(width: 6),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) return _buildShimmer();
        if (_ctrl.from.value == null) {
          return SliverToBoxAdapter(
            child: _buildMessage(
              icon: Iconsax.location,
              title: 'Pick where you start',
              subtitle: 'Tap From to choose a place',
            ),
          );
        }
        final failed = _ctrl.loadFailed.value;
        final String hint;
        if (_ctrl.category.value != null) {
          hint = 'Try another vehicle type';
        } else if (_ctrl.to.value != null) {
          hint = 'Try another destination';
        } else {
          hint = 'Set To to see route taxis';
        }
        return SliverToBoxAdapter(
          child: _buildMessage(
            icon: failed ? Iconsax.cloud_cross : Iconsax.car,
            title: failed ? "Couldn't load taxis" : 'No taxis yet',
            subtitle: failed ? 'Check your connection and try again' : hint,
            onRetry: failed ? _ctrl.retry : null,
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList.separated(
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const TaxiCardSkeleton(),
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
            textAlign: TextAlign.center,
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
