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
import '../trip_strings_v2_create.dart';
import '../trip_strings_mca_a2.dart';
import '../trip_strings_spots_x.dart';
import '../utils/trip_spot_picks.dart';
import '../utils/trip_days_rules.dart';
import '../widgets/trip_city_sheet.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_spot_detail_sheet.dart';
import '../widgets/trip_spot_row.dart';
import '../widgets/trip_spots_extras.dart';
import '../widgets/trip_spots_map_view.dart';

class TripSpotsScreen extends StatefulWidget {
  const TripSpotsScreen({super.key});

  @override
  State<TripSpotsScreen> createState() => _TripSpotsScreenState();
}

class _TripSpotsScreenState extends State<TripSpotsScreen> {
  late final TripCityModel _city;
  late final List<TripCityModel> _chain;
  late final int _index;
  late final List<TripDraftLeg> _draftLegs;
  late final bool _adding;
  late final bool _newLeg;
  late final int? _legIndex;
  late final int? _pickDay;
  late final String? _replaceId;
  late final Set<String> _existingIds;
  late final TripSpotsController _ctrl;
  late final TripPlanController _plan;
  final _scroll = ScrollController();
  bool _starting = false;
  Worker? _draftWorker;

  bool get _intoTrip => _adding || _newLeg;
  bool get _creating => !_intoTrip;
  int get _days {
    final n = TripDaysRules.autoTotal(_visits(), TripPace.relaxed);
    return n < _chain.length ? _chain.length : n;
  }
  bool get _isLast => _index >= _chain.length - 1;
  TripCityModel? get _next => _isLast ? null : _chain[_index + 1];

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
    final cities = args['cities'];
    final chain = <TripCityModel>[
      if (cities is List) ...cities.whereType<TripCityModel>() else ...[_city, ?next],
    ];
    final at = chain.indexWhere((c) => c.cityKey == _city.cityKey);
    if (at < 0) chain.insert(0, _city);
    _chain = _intoTrip ? [_city] : chain;
    _index = _intoTrip ? 0 : (at < 0 ? 0 : at);
    final legs = args['draftLegs'];
    final legacy = args['draftIds'];
    _draftLegs = [
      if (legs is List) ...legs.whereType<TripDraftLeg>(),
      if (legs is! List && legacy is List) TripDraftLeg(_city, legacy.whereType<String>().toList()),
    ];
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
    if (_creating) {
      _syncLimit();
      final seed = _draftLegs.firstWhereOrNull((l) => l.city.cityKey == _city.cityKey)?.ids ?? const <String>[];
      for (final id in seed) {
        if (_ctrl.selected.length >= TripConstants.maxSpots || _ctrl.atLimit) break;
        _ctrl.selected.add(id);
      }
      _draftWorker = ever(_ctrl.selected, (_) {
        _syncLimit();
        if (!_starting) TripNewDraft.save(_legsNow());
      });
    } else {
      _syncLimit();
    }
  }

  List<int> _counts() => [for (final c in _chain) c.cityKey == _city.cityKey ? _ctrl.selected.length : _idsOf(c).length];

  List<List<int>> _visits() => [
        for (final c in _chain)
          () {
            final byId = {for (final x in _chosenOf(c)) x.id: x.visitMinutes};
            return [for (final id in _idsOf(c)) byId[id] ?? TripConstants.defaultVisitMinutes];
          }(),
      ];

  void _syncLimit() {
    if (_pickDay != null) return;
    if (_newLeg) {
      _ctrl.limit.value = TripConstants.maxSpotsPerDay;
    } else if (_adding) {
      _ctrl.limit.value = _plan.addCapacity(_legIndex ?? _plan.legCount);
    } else {
      _ctrl.limit.value = TripDaysRules.limitForAuto(_visits(), _index, TripPace.relaxed);
    }
  }

  List<String> _idsOfSaved(TripCityModel c) {
    final saved = TripNewDraft.read()?.legs ?? _draftLegs;
    return saved.firstWhereOrNull((l) => l.city.cityKey == c.cityKey)?.ids ?? const <String>[];
  }

  List<String> _idsOf(TripCityModel c) {
    if (c.cityKey == _city.cityKey) return _ctrl.selected.toList();
    final tag = '${c.cityKey}';
    if (Get.isRegistered<TripSpotsController>(tag: tag)) return Get.find<TripSpotsController>(tag: tag).selected.toList();
    return _idsOfSaved(c);
  }

  List<TripDraftLeg> _legsNow() => [for (final c in _chain) TripDraftLeg(c, _idsOf(c))];

  List<TripSpotModel> _chosenOf(TripCityModel c) {
    if (c.cityKey == _city.cityKey) return _ctrl.chosen;
    final tag = '${c.cityKey}';
    return Get.isRegistered<TripSpotsController>(tag: tag) ? Get.find<TripSpotsController>(tag: tag).chosen : const [];
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

  bool get _pickFull {
    final day = _pickDay;
    final p = _plan.plan.value;
    if (day == null || p == null) return false;
    final replaceId = _replaceId;
    if (replaceId != null && p.spotById(replaceId) != null) return false;
    return !TripDaysRules.canAddOnDay(p, day);
  }

  void _pickOne(TripSpotModel spot) {
    final day = _pickDay;
    final p = _plan.plan.value;
    if (day == null || p == null || _starting) return;
    final replaceId = _replaceId;
    final replacing = replaceId != null && p.spotById(replaceId) != null;
    if (!replacing && p.spotCount >= TripConstants.maxSpots) {
      AppToast.warning(TripStringsMcaA2.maxPlaces);
      return;
    }
    if (!replacing && !TripDaysRules.canAddOnDay(p, day)) {
      AppToast.warning(TripStringsV2Create.dayFullMove);
      return;
    }
    _starting = true;
    final leg = p.legIndexOf(day);
    if (replacing) _plan.removeSpot(replaceId, keepEmptyDays: true);
    _plan.addSpots([spot], legIndex: leg, day: day);
    Get.back();
  }

  VoidCallback? _toggleFor(TripSpotModel s) {
    if (_existingIds.contains(s.id)) return null;
    return _pickDay != null ? () => _pickOne(s) : () => _toggle(s.id);
  }

  bool _lockedFor(TripSpotModel s) =>
      !_existingIds.contains(s.id) && !_ctrl.selected.contains(s.id) && (_pickDay != null ? _pickFull : _ctrl.atLimit);

  void _openDetail(TripSpotModel s) {
    final on = _existingIds.contains(s.id) || _ctrl.selected.contains(s.id);
    TripSpotDetailSheet.show(context, spot: s, selected: on, locked: _lockedFor(s), onToggle: _toggleFor(s));
  }

  void _applyBundle(TripQuickStart b) {
    final added = _ctrl.addBundle(b);
    if (added.isEmpty) {
      AppToast.warning(_limitText);
      return;
    }
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(TripStringsSpotsX.bundleAdded(added.length)),
      action: SnackBarAction(label: TripStringsSpotsX.undo, onPressed: () => _ctrl.removeAdded(added)),
    ));
  }

  Widget _buildOffline() => Obx(() => _ctrl.offline.value && !_ctrl.isLoading.value
      ? TripOfflineBanner(onTap: _ctrl.load)
      : const SizedBox.shrink());

  Widget _buildViewSwitch() => Obx(() {
        final show = !_ctrl.plannerOff.value &&
            !_ctrl.isLoading.value &&
            !_ctrl.isNotReady &&
            !(_ctrl.loadFailed.value && _ctrl.items.isEmpty) &&
            _ctrl.items.isNotEmpty;
        if (!show) return const SizedBox.shrink();
        return TripSpotsViewSwitch(map: _ctrl.mapMode.value, onChanged: (v) => _ctrl.mapMode.value = v);
      });

  void _toggle(String id) {
    if (_ctrl.toggle(id)) return;
    if (_ctrl.atLimit) AppToast.warning(_limitText);
  }

  String get _limitText => _creating
      ? TripStringsV2Create.limitReached
      : _newLeg
          ? TripStringsV2Create.dayFull
          : TripStringsV2Create.legFull;

  // A city in the chain may stay without places while another one has some.
  bool _canContinue(int selected) =>
      selected > 0 ||
      (!_intoTrip && (!_isLast || _chain.any((c) => c.cityKey != _city.cityKey && _idsOf(c).isNotEmpty)));

  Future<void> _planMyDays() async {
    if (_starting) return;
    if (_ctrl.selected.isEmpty && !_canContinue(0)) return;
    _starting = true;
    if (_creating && _isLast) {
      for (final c in _chain) {
        final tag = '${c.cityKey}';
        if (Get.isRegistered<TripSpotsController>(tag: tag)) {
          await Get.find<TripSpotsController>(tag: tag).ensureSelectedLoaded();
        }
      }
    } else {
      await _ctrl.ensureSelectedLoaded();
    }
    if (!mounted) return;
    final chosen = _ctrl.chosen;
    if (_newLeg) {
      await _addLeg(chosen);
      return;
    }
    if (_adding) {
      _plan.addSpots(chosen.where((s) => !_existingIds.contains(s.id)).toList(), legIndex: _legIndex);
      Get.back();
      return;
    }
    final next = _next;
    if (next != null) {
      TripNewDraft.save(_legsNow());
      await Get.toNamed(
        AppRoutes.tripSpots,
        arguments: {'city': next, 'cities': _chain, 'draftLegs': _legsNow()},
        preventDuplicates: false,
      );
      _starting = false;
      if (mounted) {
        _syncLimit();
        setState(() {});
      }
      return;
    }
    final selections = [
      for (final c in _chain) (city: c, spots: _chosenOf(c)),
    ];
    TripNewDraft.save(_legsNow());
    unawaited(_plan.startFromSelections(selections));
    Get.offNamedUntil(
      AppRoutes.tripPlan,
      (r) => r.settings.name != AppRoutes.tripSpots,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildCityChips(),
          _buildOffline(),
          _buildChips(),
          _buildViewSwitch(),
          _buildLimitNotice(),
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
    var n = (p?.dayAt(day)?.spots.length ?? 0) - (replaced == null ? 0 : 1);
    if (n < 0) n = 0;
    return TripStringsV2Create.pickHeading(day, n);
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
                else if (_creating)
                  Obx(() => Text(
                        _chain.length > 1
                            ? TripStringsV2Create.spotsHeader(_index + 1, _chain.length, _days)
                            : TripStringsV2Create.spotsHeaderOne(_days),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ))
                else
                  Obx(() {
                    final total = _ctrl.total.value;
                    final loaded = !_ctrl.isLoading.value &&
                        !_ctrl.loadFailed.value &&
                        !_ctrl.plannerOff.value &&
                        !_ctrl.isNotReady &&
                        total > 0;
                    return Text(
                      loaded ? TripStringsV2Create.placesLine(total) : 'Places to visit',
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
        ],
      ),
    );
  }

  void _backTo(int index) {
    var left = _index - index;
    if (left <= 0) return;
    Get.until((_) {
      if (left == 0) return true;
      left--;
      return false;
    });
  }

  Widget _buildCityChips() {
    if (!_creating || _chain.length < 2) return const SizedBox.shrink();
    return Obx(() {
      _ctrl.selected.length;
      return SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          itemCount: _chain.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = _chain[i];
            final current = i == _index;
            final done = !current && _idsOf(c).isNotEmpty;
            return InkWell(
              onTap: i < _index ? () => _backTo(i) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: current ? TripColors.accent : (done ? TripColors.surface : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: current || done ? TripColors.accent : AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: current ? Colors.white : (done ? TripColors.accent : AppColors.neutralChip),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: current ? TripColors.accentDark : AppColors.textHint,
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      done ? TripStringsV2Create.doneCity(c.name, _idsOf(c).length) : c.name,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: current ? Colors.white : (done ? TripColors.accentDark : AppColors.textHint),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
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
          subtitle: _ctrl.loadError.value.isEmpty ? TripStrings.checkConnection : _ctrl.loadError.value,
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
      if (_ctrl.mapMode.value) {
        return TripSpotsMapView(controller: _ctrl, onOpen: _openDetail);
      }
      final visible = _ctrl.visible;
      final loadingMore = _ctrl.isLoadingMore.value;
      final filter = _ctrl.filter.value;
      if (visible.isEmpty && !loadingMore) {
        if (filter != null) {
          return _message(EmptyStateView(
            icon: Iconsax.location,
            title: TripStringsSpotsX.noneIn(TripSpotCategory.label(filter)),
            subtitle: '',
            onRetry: () => _ctrl.setFilter(null),
            retryLabel: TripStringsSpotsX.showAll,
            palette: TripColors.palette,
          ));
        }
        return _message(const EmptyStateView(
          icon: Iconsax.location,
          title: TripStrings.noPlaces,
          subtitle: '',
          palette: TripColors.palette,
        ));
      }
      final selected = _ctrl.selected.toSet();
      final atLimit = _ctrl.atLimit;
      final pickFull = _pickFull;
      final sug = _ctrl.suggestion.value;
      final count = _ctrl.items.length;
      final few = !_ctrl.hasMore.value && count <= 3;
      final mustSee = filter == null && !few ? _ctrl.mustSee : const <TripSpotModel>[];
      final quick = filter == null && !few && _pickDay == null && selected.length < 3
          ? _ctrl.quickStarts.where((b) => TripSpotPicks.bundleAdds(b, selected, 3).isNotEmpty).toList()
          : const <TripQuickStart>[];
      final heads = <Widget>[
        if (few && filter == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              TripStringsSpotsX.fewPlaces(count),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
          ),
        if (quick.isNotEmpty) TripQuickStartRail(bundles: quick, onTap: _applyBundle),
        if (mustSee.isNotEmpty)
          TripMustSeeRail(
            city: _city.name,
            spots: mustSee,
            selected: {...selected, ..._existingIds},
            lockedOf: (s) => !_existingIds.contains(s.id) && !selected.contains(s.id) && (_pickDay != null ? pickFull : atLimit),
            toggleOf: _toggleFor,
          ),
      ];
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: heads.length + visible.length + (loadingMore ? 1 : 0),
        itemBuilder: (_, k) {
          if (k < heads.length) return heads[k];
          final i = k - heads.length;
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
          final card = TripSpotRow(
            key: ValueKey(s.id),
            spot: s,
            selected: existing || selected.contains(s.id),
            locked: !existing && !selected.contains(s.id) && (_pickDay != null ? pickFull : atLimit),
            onToggle: existing ? null : (_pickDay != null ? () => _pickOne(s) : () => _toggle(s.id)),
          );
          if (sug != null && sug.forId == s.id && _pickDay == null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  card,
                  const SizedBox(height: 6),
                  TripSuggestionCard(
                    text: TripSpotPicks.nearbyText(s, sug.nearby),
                    onAdd: () {
                      _ctrl.dismissSuggestion();
                      _toggle(sug.nearby.spot.id);
                    },
                    onDismiss: _ctrl.dismissSuggestion,
                  ),
                ],
              ),
            );
          }
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: card);
        },
      );
    });
  }

  Widget _message(Widget child) => ListView(children: [child]);

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      final n = _ctrl.selected.length;
      if (_ctrl.plannerOff.value) return const SizedBox.shrink();
      if (_pickDay != null) {
        if (!_pickFull) return const SizedBox.shrink();
        return _barFrame(context, const [
          Text(
            TripStringsV2Create.dayFullMove,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.warningText),
          ),
        ]);
      }
      final nextName = _next?.name;
      final children = <Widget>[];
      final route = _ctrl.route;
      if (route != null) {
        children
          ..add(TripSpotsRouteStrip(route: route))
          ..add(const SizedBox(height: 6));
      }
      if (_creating) {
        final total = _counts().fold<int>(0, (a, b) => a + b);
        final parts = <(String, int)>[
          for (final c in _chain)
            if (c.cityKey == _city.cityKey || _idsOf(c).isNotEmpty) (c.name, _idsOf(c).length),
        ];
        children.add(Text.rich(
          TextSpan(children: [
            TextSpan(
              text: TripStringsV2Create.barCities(parts),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            TextSpan(text: TripStringsV2Create.barTotal(total)),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textMedium),
        ));
      }
      if (_creating && n == 0 && !_canContinue(0)) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 6));
        children.add(const Text(
          TripStringsV2Create.pickOnePlace,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ));
      }
      if (_canContinue(n)) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 10));
        children.add(GradientButton(
          label: _creating
              ? (nextName == null ? TripStringsV2Create.makeMyPlan : TripStringsV2Create.next(nextName))
              : TripStringsMcaA2.spotsAddToTrip(n),
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _planMyDays,
        ));
      }
      if (children.isEmpty) return const SizedBox.shrink();
      return _barFrame(context, children);
    });
  }

  Widget _barFrame(BuildContext context, List<Widget> children) => Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  Widget _buildLimitNotice() {
    return Obx(() {
      if (_pickDay != null || _ctrl.plannerOff.value || !_ctrl.atLimit) return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 0), child: _limitNotice());
    });
  }

  Widget _limitNotice() {
    final tripFull = _counts().fold<int>(0, (a, b) => a + b) >= TripConstants.maxSpots;
    final atMax = _creating && !tripFull;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tripFull ? TripStringsMcaA2.maxPlaces : atMax ? TripStringsV2Create.maxDaysReached : _limitText,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
        ],
      ),
    );
  }
}
