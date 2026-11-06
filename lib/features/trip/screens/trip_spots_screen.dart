import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_wizard.dart';
import '../trip_strings_mca_a2.dart';
import '../utils/trip_format.dart';
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
  late final TripCityModel? _next;
  late final bool _adding;
  late final bool _newLeg;
  late final int? _legIndex;
  late final int? _pickDay;
  late final String? _replaceId;
  late final Set<String> _existingIds;
  late final TripSpotsController _ctrl;
  late final TripPlanController _plan;
  final _scroll = ScrollController();
  bool _picking = false;
  bool _starting = false;
  Worker? _draftWorker;

  bool get _intoTrip => _adding || _newLeg;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map;
    _city = args['city'] as TripCityModel;
    _newLeg = args['newLeg'] == true;
    _adding = !_newLeg && args['adding'] == true;
    _legIndex = args['legIndex'] as int?;
    _pickDay = _adding ? args['pickDay'] as int? : null;
    _replaceId = _pickDay == null ? null : args['replaceSpotId'] as String?;
    _existingIds = (args['existingIds'] as Set<String>?) ?? const <String>{};
    _plan = TripPlanController.to;
    final next = args['next'] as TripCityModel?;
    _next = _intoTrip || next?.cityKey == _city.cityKey ? null : next;
    final other = _intoTrip ? _plan.spotCount - _existingIds.length : 0;
    final tag = '${_city.cityKey}';
    _ctrl = Get.isRegistered<TripSpotsController>(tag: tag)
        ? Get.find<TripSpotsController>(tag: tag)
        : Get.put(
            TripSpotsController(_city.cityKey, existingIds: _existingIds, otherSpots: other < 0 ? 0 : other),
            tag: tag,
          );
    _plan.openPages++;
    _scroll.addListener(_onScroll);
    if (!_intoTrip) {
      final draft = args['draftIds'];
      if (draft is List) {
        for (final id in draft.whereType<String>()) {
          if (_ctrl.selected.length >= TripConstants.maxSpots) break;
          _ctrl.selected.add(id);
        }
      }
      _draftWorker = ever(_ctrl.selected, (_) {
        if (!_starting) TripNewDraft.save(_city, _next, _ctrl.selected);
      });
    }
    if (_newLeg) WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingNext());
  }

  void _consumePendingNext() {
    if (!Get.isRegistered<TripPlanController>() || !identical(Get.find<TripPlanController>(), _plan)) return;
    if (_plan.pendingNextCity.value?.cityKey == _city.cityKey) _plan.pendingNextCity.value = null;
  }

  @override
  void dispose() {
    _draftWorker?.dispose();
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
      if (picked == null || !mounted) return;
      if (picked.city.cityKey == _city.cityKey && picked.next?.cityKey == _next?.cityKey) return;
      Get.offNamed(
        AppRoutes.tripSpots,
        arguments: {'city': picked.city, 'next': picked.next},
        preventDuplicates: false,
      );
    } finally {
      _picking = false;
    }
  }

  Future<void> _addLeg(List<TripSpotModel> chosen) async {
    final block = await _plan.addLeg(_city, chosen);
    if (!mounted) return;
    switch (block) {
      case TripLegEditBlock.none:
        Get.back();
        return;
      case TripLegEditBlock.maxLegs ||
            TripLegEditBlock.noDays ||
            TripLegEditBlock.duplicate ||
            TripLegEditBlock.offline ||
            TripLegEditBlock.bookings:
        break;
      default:
        AppToast.warning(TripStringsMcaA2.cantChangeTrip);
    }
    _starting = false;
  }

  Future<void> _pickOne(TripSpotModel spot) async {
    final day = _pickDay;
    final p = _plan.plan.value;
    if (day == null || p == null || _starting) return;
    final replaceId = _replaceId;
    final replacing = replaceId != null && p.spotById(replaceId) != null;
    if (!replacing && p.spotCount >= TripConstants.maxSpots) {
      AppToast.warning(TripStringsMcaA2.maxPlaces);
      return;
    }
    final over = _plan.pickLoadMinutes(spot, day, replaceId: replacing ? replaceId : null) - _plan.dayLimitMinutes;
    if (over > 0) {
      _starting = true;
      final ok = await _confirmOver(over);
      _starting = false;
      if (!ok || !mounted) return;
    }
    _starting = true;
    final leg = p.legIndexOf(day);
    if (replacing) _plan.removeSpot(replaceId, keepEmptyDays: true);
    _plan.addSpots([spot], legIndex: leg, day: day);
    Get.back();
  }

  Future<bool> _confirmOver(int over) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(TripStringsWizard.overLimitTitle,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text(TripStringsWizard.overLimitBody(TripFormat.duration(over)),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStringsWizard.pickAnother,
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStringsWizard.addAnyway,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _planMyDays() async {
    if (_starting) return;
    final chosen = _ctrl.chosen;
    if (chosen.isEmpty) return;
    _starting = true;
    if (_newLeg) {
      await _addLeg(chosen);
      return;
    }
    if (_adding) {
      _plan.addSpots(chosen.where((s) => !_existingIds.contains(s.id)).toList(), legIndex: _legIndex);
      Get.back();
      return;
    }
    final settings = await TripDetailsSheet.collect(
      context,
      initial: TripNewDraft.settingsFor(_city) ?? const TripSettings(),
      dayCount: 1,
      spotCount: chosen.length,
    );
    if (!mounted) {
      _starting = false;
      return;
    }
    TripNewDraft.save(_city, _next, chosen.map((s) => s.id), settings: settings);
    unawaited(_plan.startFromSelection(_city, chosen, settings: settings, queuedNext: _next));
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

  String _pickHeading(int day) {
    final p = _plan.plan.value;
    final replaceId = _replaceId;
    final replaced = replaceId == null ? null : p?.spotById(replaceId);
    var left = _plan.dayMinutesLeft(day) + (replaced?.visitMinutes ?? 0);
    if (left < 0) left = 0;
    return '${TripStringsWizard.pickOneFor(day)} · ${TripStringsWizard.timeLeftToday(TripFormat.duration(left))}';
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
                if (_pickDay case final day?)
                  Text(
                    _pickHeading(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  )
                else
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
                if (_next case final next?) ...[
                  const SizedBox(height: 6),
                  _nextChip(next),
                ],
              ],
            ),
          ),
          if (!_intoTrip)
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

  Widget _nextChip(TripCityModel next) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.routing_2, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                TripStringsMcaA2.nextCity(next.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      );

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
              onToggle: existing ? null : (_pickDay != null ? () => _pickOne(s) : () => _ctrl.toggle(s.id)),
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
      if (n == 0 || _ctrl.plannerOff.value || _pickDay != null) return const SizedBox.shrink();
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: GradientButton(
          label: _newLeg ? TripStringsMcaA2.spotsAddToTrip(n) : '$n ${n == 1 ? 'spot' : 'spots'} · ${TripStrings.planMyDays}',
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _planMyDays,
        ),
      );
    });
  }
}
