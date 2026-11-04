import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_category.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../widgets/trip_city_sheet.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_spot_row.dart';
import 'trip_details_sheet.dart';

class TripSpotsScreen extends StatefulWidget {
  const TripSpotsScreen({super.key});

  @override
  State<TripSpotsScreen> createState() => _TripSpotsScreenState();
}

class _TripSpotsScreenState extends State<TripSpotsScreen> {
  late final TripCityModel _city;
  late final bool _adding;
  late final Set<String> _existingIds;
  late final TripSpotsController _ctrl;
  late final TripPlanController _plan;
  final _scroll = ScrollController();
  bool _picking = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map;
    _city = args['city'] as TripCityModel;
    _adding = args['adding'] == true;
    _existingIds = (args['existingIds'] as Set<String>?) ?? const <String>{};
    final tag = '${_city.cityKey}';
    _ctrl = Get.isRegistered<TripSpotsController>(tag: tag)
        ? Get.find<TripSpotsController>(tag: tag)
        : Get.put(TripSpotsController(_city.cityKey, existingIds: _existingIds), tag: tag);
    _plan = TripPlanController.to;
    _plan.openPages++;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    final tag = '${_city.cityKey}';
    if (Get.isRegistered<TripSpotsController>(tag: tag) && identical(Get.find<TripSpotsController>(tag: tag), _ctrl)) {
      Get.delete<TripSpotsController>(tag: tag);
    }
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _ctrl.loadMore();
  }

  Future<void> _changeCity() async {
    if (_picking) return;
    _picking = true;
    try {
      final picked = await TripCitySheet.pick(context);
      if (picked == null || !mounted || picked.cityKey == _city.cityKey) return;
      Get.offNamed(AppRoutes.tripSpots, arguments: {'city': picked}, preventDuplicates: false);
    } finally {
      _picking = false;
    }
  }

  Future<void> _planMyDays() async {
    if (_starting) return;
    final chosen = _ctrl.chosen;
    if (chosen.isEmpty) return;
    _starting = true;
    if (_adding) {
      _plan.addSpots(chosen.where((s) => !_existingIds.contains(s.id)).toList());
      Get.back();
      return;
    }
    final settings = await TripDetailsSheet.collect(
      context,
      initial: const TripSettings(),
      dayCount: 1,
      spotCount: chosen.length,
    );
    if (!mounted) {
      _starting = false;
      return;
    }
    unawaited(_plan.startFromSelection(_city, chosen, settings: settings));
    Get.offNamed(AppRoutes.tripPlan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildChips(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _city.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Obx(() {
                  final total = _ctrl.total.value;
                  final loaded = !_ctrl.isLoading.value &&
                      !_ctrl.loadFailed.value &&
                      !_ctrl.plannerOff.value &&
                      !_ctrl.isNotReady &&
                      total > 0;
                  return Text(
                    loaded ? '$total ${total == 1 ? 'place' : 'places'} to visit' : 'Places to visit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (!_adding)
            TextButton(
              onPressed: _changeCity,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              child: const Text(
                'Change city',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return Obx(() {
      final cats = _ctrl.categories;
      if (_ctrl.isLoading.value || _ctrl.plannerOff.value || cats.length <= 1) return const SizedBox.shrink();
      final current = _ctrl.filter.value;
      return SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          children: [
            _chip(TripStrings.allCategories, current == null, () => _ctrl.setFilter(null)),
            for (final cat in cats) _chip(TripSpotCategory.label(cat), current == cat, () => _ctrl.setFilter(cat)),
          ],
        ),
      );
    });
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SelectableChip(
          label: label,
          selected: selected,
          onTap: onTap,
          activeColor: TripColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
        ),
      );

  Widget _buildBody() {
    return Obx(() {
      if (_ctrl.plannerOff.value) {
        return _message(const EmptyStateView(
          icon: Iconsax.routing_2,
          title: TripStrings.plannerOff,
          subtitle: TripStrings.plannerOffSubtitle,
          palette: TripColors.palette,
        ));
      }
      final items = _ctrl.items;
      if (items.isEmpty && _ctrl.isLoading.value) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, _) => const TripSpotRowSkeleton(),
        );
      }
      if (_ctrl.loadFailed.value && items.isEmpty) {
        return _message(EmptyStateView(
          icon: Iconsax.cloud_cross,
          title: TripStrings.placesFailed,
          subtitle: TripStrings.checkConnection,
          onRetry: _ctrl.load,
          palette: TripColors.palette,
        ));
      }
      if (_ctrl.isNotReady) {
        return _message(EmptyStateView(
          icon: Iconsax.map_1,
          title: TripStrings.notReadyTitle,
          subtitle: TripStrings.notReadySubtitle(_city.name),
          palette: TripColors.palette,
        ));
      }
      final visible = _ctrl.visible;
      final loadingMore = _ctrl.isLoadingMore.value;
      if (visible.isEmpty && !loadingMore) {
        return _message(const EmptyStateView(
          icon: Iconsax.location,
          title: TripStrings.noPlaces,
          subtitle: '',
          palette: TripColors.palette,
        ));
      }
      final selected = _ctrl.selected.toSet();
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: visible.length + (loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == visible.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: TripColors.accent),
                ),
              ),
            );
          }
          final s = visible[i];
          final existing = _existingIds.contains(s.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TripSpotRow(
              key: ValueKey(s.id),
              spot: s,
              selected: existing || selected.contains(s.id),
              onToggle: existing ? null : () => _ctrl.toggle(s.id),
            ),
          );
        },
      );
    });
  }

  Widget _message(Widget child) => ListView(children: [child]);

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      final n = _ctrl.selected.length;
      if (n == 0 || _ctrl.plannerOff.value) return const SizedBox.shrink();
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: GradientButton(
          label: '$n ${n == 1 ? 'spot' : 'spots'} · ${TripStrings.planMyDays}',
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _planMyDays,
        ),
      );
    });
  }
}
