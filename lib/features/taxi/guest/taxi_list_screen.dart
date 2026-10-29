import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_shadows.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
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
        palette: TaxiColors.palette,
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
            SliverToBoxAdapter(child: _buildReviewStrip()),
            SliverToBoxAdapter(child: _buildTiles()),
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
    final subtitle = Obx(() => Text(
          _ctrl.to.value != null ? 'Taxis for your route' : 'Local taxis near you',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ));
    const titleStyle = TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white);
    return Container(
      decoration: const BoxDecoration(
        gradient: TaxiColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(widget.root ? 20 : 12, top + (widget.root ? 16 : 8), 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (!widget.root) ...[
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 2),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                widget.root
                    ? Obx(() => Text(
                          Get.find<TabConfigController>().displayNameForIndex(AppTabs.taxi, 'Taxi'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ))
                    : const Text('Taxi', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                const SizedBox(height: 2),
                subtitle,
              ]),
            ),
          ]),
          SizedBox(height: widget.root ? 18 : 12),
          Padding(
            padding: EdgeInsets.only(left: widget.root ? 0 : 8),
            child: _buildSelectors(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return Obx(() {
      final f = _ctrl.from.value;
      final t = _ctrl.to.value;
      return Column(children: [
        _selector(
          label: 'From',
          icon: Icons.my_location_rounded,
          value: f?.name,
          placeholder: 'Pick a city',
          onTap: () => _pick(isFrom: true),
          trailing: _ctrl.fromIsCurrent.value || f == null && _ctrl.isLoading.value
              ? null
              : _trailingButton(Iconsax.gps, _ctrl.useCurrentFrom),
        ),
        const SizedBox(height: 10),
        _selector(
          label: 'To',
          icon: Icons.location_on_outlined,
          value: t?.name,
          placeholder: 'Anywhere / pick a city',
          onTap: () => _pick(isFrom: false),
          trailing: t != null ? _trailingButton(Iconsax.close_circle, _ctrl.clearTo) : null,
        ),
      ]);
    });
  }

  Widget _trailingButton(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 36,
        height: 40,
        child: Icon(icon, size: 18, color: TaxiColors.accentDark),
      ),
    );
  }

  Widget _selector({
    required String label,
    required IconData icon,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isSet = value != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: EdgeInsets.only(left: 14, right: trailing != null ? 4 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.16, blur: 16, offset: const Offset(0, 6)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: TaxiColors.accentDark),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
                    ),
                    Text(
                      value ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: isSet ? FontWeight.w700 : FontWeight.w500,
                        color: isSet ? TaxiColors.accentDark : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            trailing ??
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: AppColors.neutralChip, shape: BoxShape.circle),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: TaxiColors.accentDark),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStrip() {
    return Obx(() {
      final pending = _auth.taxisEnabled && _auth.user.value?.taxiStatus == 'PendingReview';
      if (!pending) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: TaxiColors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TaxiColors.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Iconsax.clock, size: 20, color: TaxiColors.accentDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Under review',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
                    const Text('Your taxi is being checked',
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

  Widget _buildTiles() {
    return Obx(() {
      final enabled = _auth.taxisEnabled;
      if (!widget.root || !enabled) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _OptionTile(
                label: 'My Taxi',
                icon: Iconsax.car,
                gradient: AppColors.warningGradient,
                onTap: () => Get.toNamed(AppRoutes.myTaxi),
              ),
            ),
            const SizedBox(width: 10),
            const Spacer(),
            const SizedBox(width: 10),
            const Spacer(),
          ],
        ),
      );
    });
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Obx(() => Text(
            _ctrl.to.value != null ? 'Route taxis' : 'Taxis near you',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
          )),
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
              subtitle: 'Tap From to choose a city',
            ),
          );
        }
        final failed = _ctrl.loadFailed.value;
        final hint = _ctrl.to.value != null ? 'Try another city' : 'Pick a To city for route taxis';
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
          boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
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
