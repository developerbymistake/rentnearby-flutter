import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_fin_a1.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcc_a1.dart';
import '../trip_strings_mcc_a2.dart';
import 'trip_leg_impact_dialog.dart';
import 'trip_sheet_frame.dart';

class TripLegMenuSheet {
  static Future<void> show(BuildContext context, int legIndex) => _open(context, legIndex, false);

  static Future<void> changeDays(BuildContext context, int legIndex) => _open(context, legIndex, true);

  static Future<void> _open(BuildContext context, int legIndex, bool editDays) async {
    final c = TripPlanController.to;
    if (c.isReadOnly || c.needsUpdate.value || c.plan.value?.legAt(legIndex) == null) return;
    await TripSheetFrame.show<void>(context, _LegMenuBody(legIndex: legIndex, editDays: editDays));
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

  static Future<void> addPlaces(int legIndex) async {
    final c = TripPlanController.to;
    final plan = c.plan.value;
    final leg = plan?.legAt(legIndex);
    final city = cityOf(legIndex);
    if (plan == null || leg == null || city == null) return;
    Worker? watch;
    if (leg.notReady) {
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
    await TripNavigation.openSpots(city, tripId: c.trip.value?.id, existingIds: plan.spotIds, legIndex: legIndex);
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
    final dropped = _c.legDaysImpact(_leg, _days).droppedDaysWithBookings;
    if (dropped.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(TripStringsA4.removesDays(dropped),
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17)),
          content: const Text(TripStringsA4.removesDaysBody,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: const Text(TripStringsMcaA3.keep,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: const Text(TripStringsMcaA3.save,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.error)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final text = TripLegMenuSheet.blockText(_c.canSetLegDays(_leg, _days), city);
    if (text != null) {
      AppToast.warning(text);
      return;
    }
    if (!await _c.setLegDays(_leg, _days)) return;
    if (mounted) _close();
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(TripStringsMcaA3.removeCityQ(leg.cityName),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text(body, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStringsMcaA3.remove,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStringsMcaA3.keep,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight)),
          ),
        ],
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
    required IconData icon,
    required String label,
    String? trailing,
    Color color = AppColors.textDark,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final fg = enabled ? color : AppColors.textHint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(trailing,
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 20, color: onTap == null ? AppColors.textHint : TripColors.accentDark),
          style: IconButton.styleFrom(
            side: BorderSide(color: onTap == null ? AppColors.divider : TripColors.accent.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _daysEditor(TripPlan p) {
    final max = _c.maxDaysForLeg(_leg);
    final min = _c.minDaysForLeg(_leg);
    final current = p.legDayCount(_leg);
    final fewer = _days < current && p.legSpotCount(_leg) > 0;
    final blocked = !fewer && _days >= current && _c.growthBlockedByBookings(_leg);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(14)),
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
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
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
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: fewer || blocked ? AppColors.warningText : AppColors.textLight)),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _days == current || _busy ? null : _saveDays,
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: Text(TripStringsMcaA3.save,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: _days == current ? AppColors.textHint : TripColors.accentDark)),
            ),
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
        return const TripSheetFrame(title: TripStringsMcaA3.removeCity, children: [SizedBox(height: 24)]);
      }
      final a = p.legStart(_leg);
      final b = p.legEnd(_leg);
      final n = p.legDayCount(_leg);
      final editable = _daysEditable(n) && !_busy;
      final upBlock = _c.canMoveLeg(_leg, true);
      final downBlock = _c.canMoveLeg(_leg, false);
      final removeBlock = _c.canRemoveLeg(_leg);
      return TripSheetFrame(
        title: leg.cityName,
        description: TripStringsMcaA3.dayRangeWithDates(a, b, _c.dateOf(a), _c.dateOf(b)),
        children: [
          _row(
            icon: Iconsax.add_circle,
            label: TripStringsMcaA3.addPlaces,
            onTap: () {
              _close();
              TripLegMenuSheet.addPlaces(_leg);
            },
          ),
          _row(
            icon: Iconsax.calendar_edit,
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
            icon: Iconsax.arrow_up_3,
            label: TripStringsMcaA3.moveUp,
            trailing: TripLegMenuSheet.blockText(upBlock, leg.cityName, up: true),
            onTap: upBlock == TripLegEditBlock.none && !_busy ? () => _move(true) : null,
          ),
          _row(
            icon: Iconsax.arrow_down,
            label: TripStringsMcaA3.moveDown,
            trailing: TripLegMenuSheet.blockText(downBlock, leg.cityName, up: false),
            onTap: downBlock == TripLegEditBlock.none && !_busy ? () => _move(false) : null,
          ),
          _row(
            icon: Iconsax.trash,
            label: TripStringsMcaA3.removeCity,
            color: AppColors.error,
            trailing: TripLegMenuSheet.blockText(removeBlock, leg.cityName),
            onTap: (removeBlock == TripLegEditBlock.none || removeBlock == TripLegEditBlock.bookings) && !_busy
                ? _remove
                : null,
          ),
        ],
      );
    });
  }
}
