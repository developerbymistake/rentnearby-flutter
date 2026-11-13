import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'trip_update_ask_sheet.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_navigation.dart';
import '../trip_strings_fin_a1.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcc_a1.dart';
import '../trip_strings_mcc_a2.dart';
import 'trip_leg_impact_dialog.dart';

class TripLegMenuSheet {
  static Future<void> show(BuildContext context, int legIndex) => _open(context, legIndex, false);

  static Future<void> changeDays(BuildContext context, int legIndex) => _open(context, legIndex, true);

  static Future<void> _open(BuildContext context, int legIndex, bool editDays) async {
    final c = TripPlanController.to;
    if (c.isReadOnly || c.needsUpdate.value || c.plan.value?.legAt(legIndex) == null) return;
    await SheetFrame.show<void>(context, builder: (_) => _LegMenuBody(legIndex: legIndex, editDays: editDays));
  }

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

  static int? lastReadyLeg() {
    final plan = TripPlanController.to.plan.value;
    if (plan == null) return null;
    for (var k = plan.legCount; k >= 1; k--) {
      final l = plan.legAt(k);
      if (l != null && !l.notReady) return k;
    }
    return null;
  }

  static String? blockText(TripLegEditBlock b, String city, {bool? up}) => switch (b) {
        TripLegEditBlock.none => null,
        TripLegEditBlock.edge => up == true ? TripStringsMcaA3.firstCity : TripStringsMcaA3.lastCity,
        TripLegEditBlock.bookings => up == null ? TripStringsMcaA3.cancelBookingsFirst(city) : TripStringsMcaA3.bookingsBlock,
        TripLegEditBlock.running => TripStringsMcaA3.runningBlock,
        TripLegEditBlock.readOnly => TripStringsMcaA3.readOnlyBlock,
        TripLegEditBlock.noDays => TripStringsMcaA3.noDaysLeft,
        TripLegEditBlock.maxLegs => TripStringsMcaA3.maxCities,
        TripLegEditBlock.offline => TripStringsMcaA3.connectToAddCity,
        TripLegEditBlock.onlyLeg || TripLegEditBlock.duplicate => null,
      };
}

class _LegMenuBody extends StatefulWidget {
  const _LegMenuBody({required this.legIndex, this.editDays = false});

  final int legIndex;
  final bool editDays;

  @override
  State<_LegMenuBody> createState() => _LegMenuBodyState();
}

class _LegMenuBodyState extends State<_LegMenuBody> {
  final _c = TripPlanController.to;
  bool _editDays = false;
  int _days = 1;
  bool _busy = false;

  int get _leg => widget.legIndex;

  @override
  void initState() {
    super.initState();
    final n = _c.plan.value?.legDayCount(_leg) ?? 1;
    _days = n;
    _editDays = widget.editDays && _daysEditable(n);
  }

  bool _daysEditable(int n) => !_c.isReadOnly && _c.minDaysForLeg(_leg) <= n;

  String _impactBody(LegImpact impact) {
    if (impact.openCount + impact.bookedCount == 0) return '';
    return TripStringsMccA2.impactBody(impact.bookedCount, impact.openCount);
  }

  Future<bool> _cancelRows(LegImpact impact) async {
    setState(() => _busy = true);
    final r = await _c.cancelLegRows(impact);
    if (mounted) setState(() => _busy = false);
    TripLegMenuSheet.toastCancelled(impact, r);
    return r.ok;
  }

  void _close() => Navigator.pop(context);

  Future<void> _move(bool up) async {
    final city = _c.plan.value?.legAt(_leg)?.cityName ?? '';
    final b = _c.moveLeg(_leg, up);
    final text = TripLegMenuSheet.blockText(b, city, up: up);
    if (text != null) {
      AppToast.warning(text);
      return;
    }
    _close();
  }

  Future<void> _saveDays() async {
    final p = _c.plan.value;
    final current = p?.legDayCount(_leg) ?? _days;
    final city = p?.legAt(_leg)?.cityName ?? '';
    if (_days != current) {
      final impact = _c.legShrinkImpact(_leg, _days);
      if (!impact.isEmpty || impact.laterKeepDates) {
        await _saveDaysWithImpact(impact, city);
        return;
      }
    }
    final text = TripLegMenuSheet.blockText(_c.canSetLegDays(_leg, _days), city);
    if (text != null) {
      AppToast.warning(text);
      return;
    }
    if (!await _c.setLegDays(_leg, _days)) return;
    if (mounted) _close();
    TripUpdateAskSheet.afterDaysEdit();
  }

  Future<void> _saveDaysWithImpact(LegImpact impact, String city) async {
    final later = impact.laterKeepDates;
    final laterNames = impact.laterCities.join(', ');
    final body = [
      _impactBody(impact),
      if (later && laterNames.isNotEmpty) TripStringsMccA2.laterKept(laterNames),
    ].where((s) => s.isNotEmpty).join('\n');
    final days = _days;
    final choice = await TripLegImpactDialog.show(
      context,
      title: TripStringsMccA2.changeDaysQ(city),
      body: body,
      impact: impact,
      applyLabel: TripStringsMccA2.cancelAndChange,
      keepLabel: later ? null : TripStringsMccA2.changeKeepBookings,
      backLabel: TripStringsMccA2.keepDays,
      offline: _c.offline.value,
    );
    if (choice == null || choice == TripLegImpactChoice.back || !mounted) return;
    if (choice == TripLegImpactChoice.cancelAndApply && !await _cancelRows(impact)) return;
    final text = TripLegMenuSheet.blockText(_c.canSetLegDays(_leg, days, keepBookings: true), city);
    if (text != null) {
      AppToast.warning(text);
      return;
    }
    if (!await _c.setLegDays(_leg, days, keepBookings: true)) return;
    if (choice == TripLegImpactChoice.keepBookings) AppToast.info(TripStringsMccA2.bookingsKept);
    if (mounted) _close();
    TripUpdateAskSheet.afterDaysEdit();
  }

  List<String> _laterBookedCities(TripPlan p) {
    final legs = <int>{};
    for (final e in _c.enquiryList) {
      if (!e.isOpen && !e.isBooked) continue;
      final days = e.isTaxi ? e.days : [?e.day];
      for (final d in days) {
        final k = p.legIndexOf(d);
        if (k > _leg) legs.add(k);
      }
    }
    final names = [for (final k in legs.toList()..sort()) ?p.legAt(k)?.cityName];
    if (names.isNotEmpty) return names;
    return [for (var k = _leg + 1; k <= p.legCount; k++) ?p.legAt(k)?.cityName];
  }

  bool _laterDayRowsOpen(TripPlan p) {
    for (var k = _leg + 1; k <= p.legCount; k++) {
      for (final d in _c.legDays(k)) {
        if (_c.enquiriesForNight(d).any((e) => e.isOpen) || _c.taxiEnquiriesForDay(d).any((e) => e.isOpen)) return true;
      }
    }
    return false;
  }

  Future<void> _remove() async {
    final p = _c.plan.value;
    final leg = p?.legAt(_leg);
    if (p == null || leg == null) return;
    final block = _c.canRemoveLeg(_leg);
    final blocked = TripLegMenuSheet.blockText(block, leg.cityName);
    if (block != TripLegEditBlock.none) {
      if (blocked != null) AppToast.warning(blocked);
      return;
    }
    final n = p.legDayCount(_leg);
    final mode = _c.removeLegMode(_leg);
    String body;
    if (mode == TripLegRemoveMode.shift) {
      body = TripStringsMcaA3.removeShiftBody(n);
    } else if (_leg == 1) {
      final start = _c.settings.startDate;
      body = start == null
          ? TripStringsMcaA3.removeShiftBody(n)
          : TripStringsMcaA3.removeStartBody(DateTime(start.year, start.month, start.day + n));
    } else {
      body = TripStringsMcaA3.removeKeepBody(
        _laterBookedCities(p).join(', '),
        p.legStart(_leg),
        p.legEnd(_leg),
        p.legAt(_leg - 1)?.cityName ?? '',
      );
    }
    final impact = _c.legRemoveImpact(_leg);
    if (!impact.isEmpty) {
      final carsOnly = mode == TripLegRemoveMode.keepLaterDates && !_laterDayRowsOpen(p);
      await _removeWithImpact(impact, leg.cityName, mode == TripLegRemoveMode.shift || carsOnly ? null : body);
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
    if (ok != true || !mounted) return;
    final b = _c.removeLeg(_leg);
    final text = TripLegMenuSheet.blockText(b, leg.cityName);
    if (text != null) {
      AppToast.warning(text);
      return;
    }
    _close();
  }

  Future<void> _removeWithImpact(LegImpact impact, String city, String? keepLine) async {
    final body = [_impactBody(impact), ?keepLine].where((s) => s.isNotEmpty).join('\n');
    final choice = await TripLegImpactDialog.show(
      context,
      title: TripStringsMccA2.removeQ(city),
      body: body,
      impact: impact,
      applyLabel: TripStringsMccA2.cancelAndRemove,
      keepLabel: impact.carsBlockKeep ? null : TripStringsMccA2.removeKeepBookings,
      backLabel: TripStringsMccA2.keepCity,
      offline: _c.offline.value,
    );
    if (choice == null || choice == TripLegImpactChoice.back || !mounted) return;
    if (choice == TripLegImpactChoice.cancelAndApply && !await _cancelRows(impact)) return;
    final b = _c.removeLeg(_leg, keepBookings: true);
    final text = TripLegMenuSheet.blockText(b, city);
    if (text != null) {
      AppToast.warning(text);
      return;
    }
    if (choice == TripLegImpactChoice.keepBookings) AppToast.info(TripStringsMccA2.bookingsKept);
    if (mounted) _close();
  }

  Widget _row({
    required Object icon,
    required String label,
    String? trailing,
    bool danger = false,
    bool divider = true,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final tone = ListingTone.indigo;
    final fg = danger ? TripLook.error : Ink3D.title;
    return Tap3D(
      onTap: onTap,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : Alpha.v45,
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: Ink3D.line)) : null),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: danger ? TripLook.errorSurface : tone.tint, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: icon is String
                      ? Art3D(asset: icon, size: 44, shadowBlur: 3, shadowOffset: const Offset(2, 3))
                      : Icon(icon as IconData, size: 26, color: danger ? TripLook.error : tone.text),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, fg)),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                Flexible(
                  child: Text(trailing,
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(12, FontWeight.w600, Ink3D.grey)),
                )
              else
                Icon(Icons.chevron_right_rounded, size: 20, color: danger ? TripLook.error : Ink3D.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    final tone = ListingTone.indigo;
    final tip = icon == Icons.add_rounded ? 'Increase' : 'Decrease';
    return Tooltip(
      message: tip,
      excludeFromSemantics: true,
      child: Tap3D(
        onTap: onTap,
        label: tip,
        child: Opacity(
          opacity: onTap == null ? Alpha.v45 : 1,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: tone.gradient, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: DesignColors.surface),
          ),
        ),
      ),
    );
  }

  Widget _daysEditor(TripPlan p) {
    final max = _c.maxDaysForLeg(_leg);
    final needed = (p.legSpotCount(_leg) / TripConstants.maxSpotsPerDay).ceil();
    final min = _c.minDaysForLeg(_leg) > needed ? _c.minDaysForLeg(_leg) : (needed < 1 ? 1 : needed);
    final current = p.legDayCount(_leg);
    final fewer = _days < current && p.legSpotCount(_leg) > 0;
    final blocked = !fewer && _days >= current && _c.growthBlockedByBookings(_leg);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _stepButton(Icons.remove_rounded, _days > min ? () => setState(() => _days--) : null),
              Expanded(
                child: Text(TripStringsMcaA3.days(_days),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(17, FontWeight.w700, ListingTone.indigo.text)),
              ),
              _stepButton(Icons.add_rounded, _days < max ? () => setState(() => _days++) : null),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              fewer
                  ? TripStringsMcaA3.fewerDays
                  : (blocked ? TripStringsFinA1.growBlocked : TripStringsMcaA3.daysLeftNote(max)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Ink3D.text(12, FontWeight.w500, fewer || blocked ? TripLook.warningText : Ink3D.grey)),
          const SizedBox(height: 8),
          GradientPillButton(
            tone: ListingTone.indigo,
            label: TripStringsMcaA3.save,
            height: 44,
            onTap: _days == current || _busy ? null : _saveDays,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.plan.value;
      _c.enquiryList.length;
      final leg = p?.legAt(_leg);
      if (p == null || leg == null) {
        return SheetFrame(tone: ListingTone.indigo, title: TripStringsMcaA3.removeCity, child: const SizedBox(height: 24));
      }
      final a = p.legStart(_leg);
      final b = p.legEnd(_leg);
      final n = p.legDayCount(_leg);
      final editable = _daysEditable(n) && !_busy;
      final upBlock = _c.canMoveLeg(_leg, true);
      final downBlock = _c.canMoveLeg(_leg, false);
      final removeBlock = _c.canRemoveLeg(_leg);
      return SheetFrame(
        tone: ListingTone.indigo,
        art: ListingArt.mountain,
        size: SheetSize.confirm,
        title: leg.cityName,
        subtitle: TripStringsMcaA3.dayRangeWithDates(a, b, _c.dateOf(a), _c.dateOf(b)),
        child: Container(
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: Ink3D.softShadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          _row(
            icon: ListingArt.roundPushpin,
            divider: false,
            label: TripStringsMcaA3.addPlaces,
            onTap: () {
              _close();
              TripLegMenuSheet.addPlaces(_leg);
            },
          ),
          _row(
            icon: ListingArt.calendar,
            label: TripStringsMcaA3.changeDays,
            trailing: _busy
                ? TripStringsMccA2.cancelling
                : (_daysEditable(n) ? TripStringsMcaA3.days(n) : TripStringsMcaA3.runningBlock),
            onTap: editable
                ? () => setState(() {
                      _editDays = !_editDays;
                      _days = n;
                    })
                : null,
          ),
          if (_editDays && editable) _daysEditor(p),
          _row(
            icon: Icons.arrow_upward_rounded,
            label: TripStringsMcaA3.moveUp,
            trailing: TripLegMenuSheet.blockText(upBlock, leg.cityName, up: true),
            onTap: upBlock == TripLegEditBlock.none && !_busy ? () => _move(true) : null,
          ),
          _row(
            icon: Icons.arrow_downward_rounded,
            label: TripStringsMcaA3.moveDown,
            trailing: TripLegMenuSheet.blockText(downBlock, leg.cityName, up: false),
            onTap: downBlock == TripLegEditBlock.none && !_busy ? () => _move(false) : null,
          ),
          _row(
            icon: Icons.close_rounded,
            label: TripStringsMcaA3.removeCity,
            danger: true,
            trailing: TripLegMenuSheet.blockText(removeBlock, leg.cityName),
            onTap: (removeBlock == TripLegEditBlock.none || removeBlock == TripLegEditBlock.bookings) && !_busy
                ? _remove
                : null,
          ),
            ],
          ),
        ),
      );
    });
  }
}
