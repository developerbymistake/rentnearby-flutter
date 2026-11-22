import 'package:bakhli/design/design.dart';
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
import 'discovery_api.dart';

typedef TripAddSpots = bool Function(List<TripSpotModel> spots, {int? legIndex, int? day});
typedef TripRemoveSpot = void Function(String id, {bool keepEmptyDays});
typedef TripInsertSpot = void Function(TripSpotRef spot, int day, int index);
typedef TripSpotSheet = void Function(BuildContext context, TripSpotModel spot, {required bool selected, required bool locked, VoidCallback? onToggle, int? cityKey, String? version, required bool partial});

class TripMapSpotActions {
  final TripPlan? Function() plan;
  final int Function() selectedDay;
  final TripAddSpots addSpots;
  final TripRemoveSpot removeSpot;
  final TripInsertSpot insertSpotAt;
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
    required this.removeSpot,
    required this.insertSpotAt,
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
        removeSpot: c.removeSpot,
        insertSpotAt: c.insertSpotAt,
        context: context,
      );

  static String? _catalogName(int cityKey) {
    for (final c in TripCityCatalog.to.search('')) {
      if (c.cityKey == cityKey) return c.name;
    }
    return null;
  }

  static void _showSheet(BuildContext context, TripSpotModel spot,
          {required bool selected, required bool locked, VoidCallback? onToggle, int? cityKey, String? version, required bool partial}) =>
      TripSpotDetailSheet.show(context, spot: spot, selected: selected, locked: locked, onToggle: onToggle, cityKey: cityKey, version: version, partial: partial);

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
        if (ref != null) 'visitMinutes': ref.visitMinutes,
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
    if (p.spotCount >= TripConstants.maxSpots) {
      AppToast.warning(TripStringsMcaA2.maxPlaces);
      return false;
    }
    if (!TripDaysRules.canAddOnDay(p, day)) {
      AppToast.warning(TripStringsV2Create.dayFullMove);
      return false;
    }
    return addSpots([modelFor(s).model], legIndex: p.legIndexOf(day), day: day);
  }

  bool remove(DiscoverySpot s) {
    final p = plan();
    final day = p?.dayOfSpot(s.id);
    final d = day == null ? null : p?.dayAt(day);
    if (p == null || day == null || d == null) return false;
    final index = d.spots.indexWhere((x) => x.id == s.id);
    if (index < 0) return false;
    final ref = d.spots[index];
    removeSpot(s.id, keepEmptyDays: true);
    if (plan()?.dayOfSpot(s.id) != null) return false;
    showRemovedUndo(context(), () => insertSpotAt(ref, day, index));
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
    );
  }

  static void showRemovedUndo(BuildContext context, VoidCallback undo) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(
        content: const Text(TripStringsV2Plan.placeRemoved, style: TextStyle(fontFamily: FitnessAppTheme.fontName)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: TripStringsV2Plan.undo, onPressed: undo),
      ),
    );
  }
}
