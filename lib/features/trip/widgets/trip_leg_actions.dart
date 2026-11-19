import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_dayplan.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcc_a1.dart';
import '../trip_strings_mcc_a2.dart';
import 'trip_leg_impact_dialog.dart';

class TripLegActions {
  TripLegActions._();

  static bool _removing = false;

  static void toastCancelled(LegImpact impact, LegCancelResult r) {
    if (!r.ok) {
      AppToast.error(TripStringsMccA1.cancelFailed(r.failed));
    } else if (impact.bookedCount > 0) {
      AppToast.success(TripStringsMccA1.bookingsCancelled(impact.bookedCount));
    } else if (impact.openCount > 0) {
      AppToast.success(TripStringsMccA1.enquiriesWithdrawn(impact.openCount));
    }
  }

  static TripCityModel? cityOf(int legIndex) {
    final c = TripPlanController.to;
    final leg = c.plan.value?.legAt(legIndex);
    if (leg == null) return null;
    final picked = c.picked;
    if (picked != null && picked.cityKey == leg.cityKey) return picked;
    return TripCityModel(
      cityKey: leg.cityKey,
      name: leg.cityName,
      latitude: leg.latitude,
      longitude: leg.longitude,
      status: leg.notReady ? TripCityStatus.notReady : TripCityStatus.ready,
    );
  }

  static Future<void> addPlaces(int legIndex, {int? pickDay, String? replaceSpotId}) async {
    final c = TripPlanController.to;
    final plan = c.plan.value;
    final leg = plan?.legAt(legIndex);
    final city = cityOf(legIndex) ?? (leg == null && legIndex == 1 ? c.picked : null);
    if (plan == null || city == null) return;
    Worker? watch;
    if (leg != null && leg.notReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tag = '${city.cityKey}';
        if (!Get.isRegistered<TripSpotsController>(tag: tag)) return;
        final spots = Get.find<TripSpotsController>(tag: tag);
        void check() {
          if (spots.items.isNotEmpty && spots.status.value == TripSpotStatus.ready) c.markLegReady(legIndex);
        }

        check();
        watch = ever(spots.items, (_) => check());
      });
    }
    await TripNavigation.openSpots(city,
        tripId: c.trip.value?.id, existingIds: plan.spotIds, legIndex: legIndex, pickDay: pickDay, replaceSpotId: replaceSpotId);
    watch?.dispose();
    final now = c.plan.value;
    if ((now?.legAt(legIndex)?.notReady ?? false) && (now?.legSpotCount(legIndex) ?? 0) > 0) c.markLegReady(legIndex);
  }

  static String? blockText(TripLegEditBlock b, String city, {bool? locked}) => switch (b) {
        TripLegEditBlock.none => null,
        TripLegEditBlock.edge => TripStringsDayplan.tooFewDays,
        TripLegEditBlock.readOnly when locked ?? _lockedNow => TripStringsDayplan.lockedShort,
        TripLegEditBlock.bookings => TripStringsMcaA3.cancelBookingsFirst(city),
        TripLegEditBlock.running => TripStringsMcaA3.runningBlock,
        TripLegEditBlock.readOnly => TripStringsMcaA3.readOnlyBlock,
        TripLegEditBlock.noDays => TripStringsMcaA3.noDaysLeft,
        TripLegEditBlock.maxLegs => TripStringsMcaA3.maxCities,
        TripLegEditBlock.offline => TripStringsMcaA3.connectToAddCity,
        TripLegEditBlock.onlyLeg || TripLegEditBlock.duplicate || TripLegEditBlock.otherState => null,
      };

  static bool get _lockedNow => Get.isRegistered<TripPlanController>() && TripPlanController.to.isPlanLocked;

  static String _impactBody(LegImpact impact) {
    if (impact.openCount + impact.bookedCount == 0) return '';
    return TripStringsMccA2.impactBody(impact.bookedCount, impact.openCount);
  }

  static Future<bool> _cancelRows(LegImpact impact) async {
    final r = await TripPlanController.to.cancelLegRows(impact);
    toastCancelled(impact, r);
    return r.ok;
  }

  static List<String> _laterBookedCities(TripPlanController c, TripPlan p, int leg) {
    final legs = <int>{};
    for (final e in c.enquiryList) {
      if (!e.isOpen && !e.isBooked) continue;
      final days = e.isTaxi ? e.days : [?e.day];
      for (final d in days) {
        final k = p.legIndexOf(d);
        if (k > leg) legs.add(k);
      }
    }
    final names = [for (final k in legs.toList()..sort()) ?p.legAt(k)?.cityName];
    if (names.isNotEmpty) return names;
    return [for (var k = leg + 1; k <= p.legCount; k++) ?p.legAt(k)?.cityName];
  }

  static bool _laterDayRowsOpen(TripPlanController c, TripPlan p, int leg) {
    for (var k = leg + 1; k <= p.legCount; k++) {
      for (final d in c.legDays(k)) {
        if (c.enquiriesForNight(d).any((e) => e.isOpen) || c.taxiEnquiriesForDay(d).any((e) => e.isOpen)) return true;
      }
    }
    return false;
  }

  static Future<void> removeCity(BuildContext context, int legIndex) async {
    final c = TripPlanController.to;
    if (_removing || c.isReadOnly || c.needsUpdate.value || c.plan.value?.legAt(legIndex) == null) return;
    if (c.isPlanLocked) {
      AppToast.warning(c.planLockMessage);
      return;
    }
    _removing = true;
    try {
      await _remove(context, c, legIndex);
    } finally {
      _removing = false;
    }
  }

  static bool _gone(TripPlanController c, int legIndex, int key) => c.plan.value?.legAt(legIndex)?.cityKey != key;

  static Future<void> _remove(BuildContext context, TripPlanController c, int legIndex) async {
    final p = c.plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null) return;
    final block = c.canRemoveLeg(legIndex);
    if (block != TripLegEditBlock.none) {
      final blocked = blockText(block, leg.cityName);
      if (blocked != null) AppToast.warning(blocked);
      return;
    }
    final n = p.legDayCount(legIndex);
    final mode = c.removeLegMode(legIndex);
    String body;
    if (mode == TripLegRemoveMode.shift) {
      body = TripStringsMcaA3.removeShiftBody(n);
    } else if (legIndex == 1) {
      final start = c.settings.startDate;
      body = start == null
          ? TripStringsMcaA3.removeShiftBody(n)
          : TripStringsMcaA3.removeStartBody(DateTime(start.year, start.month, start.day + n));
    } else {
      body = TripStringsMcaA3.removeKeepBody(
        _laterBookedCities(c, p, legIndex).join(', '),
        p.legStart(legIndex),
        p.legEnd(legIndex),
        p.legAt(legIndex - 1)?.cityName ?? '',
      );
    }
    final impact = c.legRemoveImpact(legIndex);
    if (!impact.isEmpty) {
      final carsOnly = mode == TripLegRemoveMode.keepLaterDates && !_laterDayRowsOpen(c, p, legIndex);
      await _removeWithImpact(context, c, legIndex, leg.cityKey, impact, leg.cityName, mode == TripLegRemoveMode.shift || carsOnly ? null : body);
      return;
    }
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: ListingArt.mountain,
        title: TripStringsMcaA3.removeCityQ(leg.cityName),
        body: body,
        secondaryLabel: TripStringsMcaA3.keep,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStringsMcaA3.remove,
        primaryDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (ok != true || !context.mounted || _gone(c, legIndex, leg.cityKey)) return;
    final text = blockText(c.removeLeg(legIndex), leg.cityName);
    if (text != null) AppToast.warning(text);
  }

  static Future<void> _removeWithImpact(
    BuildContext context,
    TripPlanController c,
    int legIndex,
    int key,
    LegImpact impact,
    String city,
    String? keepLine,
  ) async {
    final body = [_impactBody(impact), ?keepLine].where((s) => s.isNotEmpty).join('\n');
    final choice = await TripLegImpactDialog.show(
      context,
      title: TripStringsMccA2.removeQ(city),
      body: body,
      impact: impact,
      applyLabel: TripStringsMccA2.cancelAndRemove,
      keepLabel: impact.carsBlockKeep ? null : TripStringsMccA2.removeKeepBookings,
      backLabel: TripStringsMccA2.keepCity,
      offline: c.offline.value,
    );
    if (choice == null || choice == TripLegImpactChoice.back || !context.mounted || _gone(c, legIndex, key)) return;
    if (choice == TripLegImpactChoice.cancelAndApply && !await _cancelRows(impact)) return;
    if (_gone(c, legIndex, key)) return;
    final text = blockText(c.removeLeg(legIndex, keepBookings: true), city);
    if (text != null) {
      AppToast.warning(text);
      return;
    }
    if (choice == TripLegImpactChoice.keepBookings) AppToast.info(TripStringsMccA2.bookingsKept);
  }
}
