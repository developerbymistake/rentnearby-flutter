import 'package:flutter/material.dart';

import '../../../utils/app_toast.dart';
import '../controllers/trip_plan_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings_mca_a2.dart';
import '../trip_strings_v2_create.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_days_rules.dart';
import '../utils/trip_spots_cache.dart';
import '../widgets/trip_spot_detail_sheet.dart';
import '../widgets/trip_undo_snack.dart';
import 'discovery_api.dart';

typedef TripAddSpots = bool Function(List<TripSpotModel> spots, {int? legIndex, int? day});
typedef TripRemoveForUndo = TripSpotRemoval? Function(String id);
typedef TripUndoRemove = bool Function(TripSpotRemoval r);
typedef TripSpotSheet = void Function(BuildContext context, TripSpotModel spot, {required bool selected, required bool locked, VoidCallback? onToggle, int? cityKey, String? version, required bool partial, required bool revalidate});

class TripMapSpotActions {
  final TripPlan? Function() plan;
  final int Function() selectedDay;
  final TripAddSpots addSpots;
  final TripRemoveForUndo removeForUndo;
  final TripUndoRemove undoRemove;
  final TripPlanController? owner;
  final BuildContext Function() context;
  final List<TripSpotModel>? Function(int cityKey) cachedSpots;
  final String? Function(int cityKey) cachedVersion;
  final String? Function(int cityKey) cityName;
  final TripSpotSheet sheet;
  final _memo = <int, ({String version, Map<String, TripSpotModel> byId})>{};

  TripMapSpotActions({
    required this.plan,
    required this.selectedDay,
    required this.addSpots,
    required this.removeForUndo,
    required this.undoRemove,
    this.owner,
    required this.context,
    List<TripSpotModel>? Function(int cityKey)? cachedSpots,
    String? Function(int cityKey)? cachedVersion,
    String? Function(int cityKey)? cityName,
    TripSpotSheet? sheet,
  })  : cachedSpots = cachedSpots ?? TripSpotsCache.load,
        cachedVersion = cachedVersion ?? TripSpotsCache.versionOf,
        cityName = cityName ?? _catalogName,
        sheet = sheet ?? _showSheet;

  factory TripMapSpotActions.of(TripPlanController c, {required BuildContext Function() context}) => TripMapSpotActions(
        plan: () => c.plan.value,
        selectedDay: () => c.selectedMapDay.value,
        addSpots: c.addSpots,
        removeForUndo: c.removeSpotForUndo,
        undoRemove: c.undoRemove,
        owner: c,
        context: context,
      );

  static String? _catalogName(int cityKey) {
    for (final c in TripCityCatalog.to.search('')) {
      if (c.cityKey == cityKey) return c.name;
    }
    return null;
  }

  static void _showSheet(BuildContext context, TripSpotModel spot,
          {required bool selected, required bool locked, VoidCallback? onToggle, int? cityKey, String? version, required bool partial, required bool revalidate}) =>
      TripSpotDetailSheet.show(context,
          spot: spot, selected: selected, locked: locked, onToggle: onToggle, cityKey: cityKey, version: version, partial: partial, revalidate: revalidate);

  int? _legOf(TripPlan p, DiscoverySpot s) {
    final key = s.cityKey;
    if (key != null && key > 0) return p.legIndexOfCity(key);
    return p.isMultiCity ? null : 1;
  }

  int? plannedDayOf(String spotId) => plan()?.dayOfSpot(spotId);

  int? targetDayFor(DiscoverySpot s) {
    final p = plan();
    if (p == null || p.days.isEmpty) return null;
    final leg = _legOf(p, s);
    if (leg == null) return null;
    final picked = selectedDay();
    if (picked != TripPlanController.mapAll && p.dayAt(picked) != null && p.legIndexOf(picked) == leg) return picked;
    final start = p.legStart(leg);
    return start >= 1 ? start : null;
  }

  ({TripSpotModel model, bool partial}) modelFor(DiscoverySpot s) {
    final full = _cached(s);
    if (full != null) return (model: full, partial: false);
    final ref = plan()?.spotById(s.id);
    return (
      model: TripSpotModel.fromJson({
        'id': s.id,
        'name': s.name,
        'latitude': s.lat,
        'longitude': s.lon,
        'category': s.category,
        'rank': s.rank,
        'imageUrl': s.thumbUrl ?? ref?.imageUrl,
        'visitMinutes': ?(s.visitMinutes ?? ref?.visitMinutes),
      }),
      partial: true,
    );
  }

  TripSpotModel? _cached(DiscoverySpot s) {
    final key = s.cityKey;
    if (key == null || key <= 0) return null;
    final version = cachedVersion(key) ?? '';
    var memo = _memo[key];
    if (memo == null || memo.version != version) {
      final items = cachedSpots(key);
      if (items == null) return null;
      memo = (version: version, byId: {for (final m in items) m.id: m});
      _memo[key] = memo;
    }
    return memo.byId[s.id];
  }

  String? lineFor(DiscoverySpot s) {
    final d = _cached(s)?.description?.trim();
    if (d != null && d.isNotEmpty) return d;
    final key = s.cityKey;
    if (key == null || key <= 0) return null;
    final name = cityName(key)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final p = plan();
    final leg = p?.legAt(p.legIndexOfCity(key) ?? 0);
    final legName = leg?.cityName.trim();
    return legName == null || legName.isEmpty ? null : legName;
  }

  bool add(DiscoverySpot s) {
    final p = plan();
    final day = targetDayFor(s);
    if (p == null || day == null || p.dayOfSpot(s.id) != null) return false;
    if (p.dayAt(day) == null) return false;
    if (p.spotCount >= TripConstants.maxSpots) {
      AppToast.warning(TripStringsMcaA2.maxPlaces);
      return false;
    }
    if (TripDaysRules.isDayFull(p, day)) {
      AppToast.warning(TripStringsV2Create.dayFullMove);
      return false;
    }
    return addSpots([modelFor(s).model], legIndex: p.legIndexOf(day), day: day);
  }

  bool remove(DiscoverySpot s) {
    final p = plan();
    if (p == null || p.dayOfSpot(s.id) == null) return false;
    final r = removeForUndo(s.id);
    if (r == null) return false;
    TripUndoSnack.show(ScaffoldMessenger.maybeOf(context()), TripStringsV2Plan.placeRemoved, plan: owner, onUndo: () {
      if (!undoRemove(r)) AppToast.warning(TripStringsV2Plan.undoGone);
    });
    return true;
  }

  void details(DiscoverySpot s) {
    final planned = plannedDayOf(s.id) != null;
    final target = targetDayFor(s);
    final m = modelFor(s);
    final key = s.cityKey;
    sheet(
      context(),
      m.model,
      selected: planned,
      locked: !planned && target == null,
      onToggle: planned ? () => remove(s) : (target == null ? null : () => add(s)),
      cityKey: key,
      version: key == null ? null : cachedVersion(key) ?? '',
      partial: m.partial,
      revalidate: true,
    );
  }
}
