import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../config/module_palette.dart';
import '../../../models/browse_item.dart';
import '../../../services/top_route_observer.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../taxi/journeys/journey_actions.dart';
import '../../taxi/journeys/journeys_controller.dart';
import '../../taxi/taxi_option_sets.dart';
import '../../taxi/ways/trip_strings_journey_card.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../../taxi/ways/widgets/travel_confirm_sheet.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcb_k2.dart';
import '../utils/trip_format.dart';
import '../utils/trip_travel_rules.dart';
import '../utils/trip_wizard_rules.dart';
import 'trip_going_home_row.dart';
import 'trip_journey_strip.dart';
import 'trip_own_travel_sheet.dart';
import 'trip_sheet_frame.dart';

enum _JourneyMenu { openJourney, changeWay, arrangeMyself, remove }

class _Look {
  final Color fill;
  final Color edge;
  final Color bar;
  final Color tone;

  const _Look(this.fill, this.edge, this.bar, this.tone);

  static const grey = _Look(Colors.white, AppColors.divider, AppColors.textHint, AppColors.textLight);
  static const amber = _Look(TripStatusColors.waitingSurface, TripStatusColors.waiting, TripStatusColors.waiting, AppColors.warningText);
  static const red = _Look(TripStatusColors.failedSurface, TripStatusColors.failed, TripStatusColors.failed, TripStatusColors.failed);
  static const green = _Look(TripStatusColors.bothSurface, TripStatusColors.both, TripStatusColors.both, AppColors.successText);
  static const orange = _Look(TripColors.surface, TripColors.accent, TripColors.accentDark, TripColors.accentDark);

  static _Look of(TripStepState? s) => switch (s) {
        TripStepState.done => green,
        TripStepState.waiting => amber,
        TripStepState.attention => red,
        _ => grey,
      };
}

class TripJourneyCard extends StatelessWidget {
  const TripJourneyCard({super.key, this.role, this.legIndex}) : assert((role == null) != (legIndex == null));

  final TripStepRole? role;
  final int? legIndex;

  static final RxSet<String> _keptBoth = <String>{}.obs;

  static TripStepKey? keyOf({TripStepRole? role, int? legIndex}) =>
      TripStepKey.parse(role != null ? role.name : 'travel:$legIndex');

  static TripStepInfo? infoOf(TripPlanController c, {TripStepRole? role, int? legIndex}) {
    final k = keyOf(role: role, legIndex: legIndex);
    return k == null ? null : c.stepInfo(k);
  }

  static TripJourney? journeyOf(TripPlanController c, {TripStepRole? role, int? legIndex}) =>
      role != null ? c.journeyFor(role) : (legIndex == null ? null : c.segmentJourney(legIndex));

  static List<TripEnquiryModel> rowsOf(TripPlanController c, TripJourney j, {int? legIndex}) =>
      legIndex != null ? c.segmentRows(legIndex) : TripTravelRules.liveRowsOf(j.id, c.enquiryList);

  static bool canActOn(TripPlanController c, TripJourney j, {TripStepRole? role, int? legIndex}) {
    if (c.isReadOnly || c.needsUpdate.value) return false;
    final k = legIndex;
    if (k != null) {
      final day = c.plan.value?.legStart(k) ?? 1;
      return c.canEditDay(day) && c.travelStateOf(k) != TripTravelState.dateChanged;
    }
    return role != null && c.stepCanAsk(role);
  }

  static void setCarOwn({TripStepRole? role, int? legIndex, required int car, required bool own}) =>
      TripPlanController.to.setOwnCar(role, legIndex, car, own);

  static void _refreshLinked(String journeyId) {
    final saved = JourneysController.ensure().journeys.firstWhereOrNull((x) => x.id == journeyId);
    if (saved != null && Get.isRegistered<TripPlanController>()) TripPlanController.to.refreshLinkedJourney(saved);
  }

  static Future<void> useBackup(TripJourney j, int car, String taxiId) async {
    await JourneysController.ensure().replaceDriver(j.id, car, taxiId);
    _refreshLinked(j.id);
  }

  static Future<void> findAnotherCar(BuildContext context, TripJourney j, int car) async {
    final saved = JourneysController.ensure().journeys.firstWhereOrNull((x) => x.id == j.id);
    final leg = saved?.legs.firstWhereOrNull((l) => l.legIndex == car);
    if (saved == null || leg == null) {
      await TripNavigation.openJourney(j.id);
      return;
    }
    await JourneyActions.changeDriver(context, saved, leg);
    _refreshLinked(j.id);
  }

  static Future<bool> _closeRows(Iterable<TripEnquiryModel> rows) async {
    final enq = TripEnquiryController.to;
    for (final e in rows) {
      if (!TripTravelRules.isLive(e)) continue;
      final ok = TripTravelRules.bookedStatuses.contains(e.status)
          ? await enq.cancel(e.id)
          : (e.isWithdrawable ? await enq.withdraw(e.id) : true);
      if (!ok) return false;
    }
    return true;
  }

  static Future<void> cancelCarBooking(BuildContext context, {TripStepRole? role, int? legIndex, required int car}) async {
    final c = TripPlanController.to;
    final j = journeyOf(c, role: role, legIndex: legIndex);
    if (j == null || c.isReadOnly) return;
    final rows = [
      for (final e in rowsOf(c, j, legIndex: legIndex))
        if (e.context.journeyLegIndex == car && TripTravelRules.isLive(e)) e,
    ];
    final booked = TripTravelRules.carBooking(car, rows);
    if (booked == null) return;
    final driver = TripJourneyStrip.driverOf(j.legs.firstWhereOrNull((l) => l.legIndex == car)?.driverName ?? '');
    final ok = await TravelConfirmSheet.show(
      context,
      title: TripStringsJourneyCard.cancelBookingQ(driver),
      body: TripStringsJourneyCard.cancelBookingBody,
      confirm: TripStringsJourneyCard.cancelBooking,
    );
    if (!ok) return;
    if (!await _closeRows([booked])) {
      AppToast.warning(TripStringsJourneyCard.carClosedFailed);
      return;
    }
    unawaited(c.refreshEnquiries());
  }

  static Future<void> arrangeCar(BuildContext context, {TripStepRole? role, int? legIndex, required int car}) async {
    final c = TripPlanController.to;
    final j = journeyOf(c, role: role, legIndex: legIndex);
    if (j == null || c.isReadOnly) return;
    final rows = [
      for (final e in rowsOf(c, j, legIndex: legIndex))
        if (e.context.journeyLegIndex == car && TripTravelRules.isLive(e)) e,
    ];
    final booked = TripTravelRules.carBooking(car, rows);
    if (booked != null) {
      final driver = TripJourneyStrip.driverOf(j.legs.firstWhereOrNull((l) => l.legIndex == car)?.driverName ?? '');
      final ok = await TravelConfirmSheet.show(
        context,
        title: TripStringsJourneyCard.cancelBookingQ(driver),
        body: TripStringsJourneyCard.cancelBookingBody,
        confirm: TripStringsJourneyCard.cancelBooking,
      );
      if (!ok) return;
    }
    if (!await _closeRows(rows)) {
      AppToast.warning(TripStringsJourneyCard.carClosedFailed);
      return;
    }
    c.setOwnCar(role, legIndex, car, true);
  }

  static Future<bool> arrangeMyself(BuildContext context, {TripStepRole? role, int? legIndex}) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return false;
    final j = journeyOf(c, role: role, legIndex: legIndex);
    final rows = j == null ? const <TripEnquiryModel>[] : [
      for (final e in rowsOf(c, j, legIndex: legIndex))
        if (TripTravelRules.isLive(e) && (e.isWithdrawable || TripTravelRules.bookedStatuses.contains(e.status))) e,
    ];
    var kept = <int>{};
    if (j != null && rows.isNotEmpty) {
      final cars = [
        for (final l in j.legs)
          _ArrangeCar(
            car: l.legIndex,
            driver: TripJourneyStrip.driverOf(l.driverName),
            booked: TripTravelRules.carBooking(l.legIndex, rows) != null,
          ),
      ];
      final picked = await TripSheetFrame.show<Set<int>>(context, _ArrangeBody(cars: cars));
      if (picked == null || !context.mounted) return false;
      kept = picked;
    }
    Future<bool> close() async {
      final ok = await _closeRows([
        for (final e in rows)
          if (!(kept.contains(e.context.journeyLegIndex) && TripTravelRules.bookedStatuses.contains(e.status))) e,
      ]);
      if (!ok) AppToast.warning(TripStringsJourneyCard.carClosedFailed);
      return ok;
    }

    if (kept.isEmpty) {
      final before = rows.isEmpty ? null : close;
      if (legIndex != null) return TripOwnTravelSheet.show(context, legIndex, beforeSave: before);
      if (role != null) return TripOwnTravelSheet.showForRole(context, role, beforeSave: before);
      return false;
    }
    if (!await close()) return false;
    for (final l in j!.legs) {
      if (!kept.contains(l.legIndex)) c.setOwnCar(role, legIndex, l.legIndex, true);
    }
    return true;
  }

  static Future<void> pickStart(BuildContext context) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return;
    final p = await LocationSwitchSheet.pick(context, palette: ModulePalette.trip, title: TripStringsJourneyCard.pickStart);
    if (p == null) return;
    final moved = await c.setStartFrom(TripStartFrom(name: p.name, lat: p.latitude, lon: p.longitude));
    if (moved && context.mounted) await askSearchAgain(context);
  }

  static Future<void> askSearchAgain(BuildContext context) async {
    final c = TripPlanController.to;
    final city = c.startFrom?.name ?? '';
    final again = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          TripStringsJourneyCard.startChanged,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          TripStringsJourneyCard.searchFromAgain(city),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsJourneyCard.later,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsJourneyCard.searchAgain,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark),
            ),
          ),
        ],
      ),
    );
    if (again != true) return;
    final first = TripStepRole.values.firstWhere(
      (r) => c.journeyFor(r)?.startChanged == true,
      orElse: () => TripStepRole.gettingThere,
    );
    final onStep = TopRouteObserver.top.value == AppRoutes.tripStep;
    TripNavigation.openWays(first, fromStep: onStep ? keyOf(role: first)?.id : null);
  }

  Future<void> _find(BuildContext context) async {
    final from = keyOf(role: role, legIndex: legIndex)?.id;
    final k = legIndex;
    if (k != null) {
      await TripNavigation.openSegmentWays(k, fromStep: from);
    } else {
      await TripNavigation.openWays(role!, fromStep: from);
    }
  }

  Future<void> _ask(BuildContext context, String id) async {
    final c = TripPlanController.to;
    await c.flushPendingSave();
    final saved = JourneysController.ensure().byId(id);
    if (saved == null || saved.legs.isEmpty || !context.mounted) {
      await TripNavigation.openJourney(id);
      return;
    }
    if (await JourneyActions.ask(context, saved)) unawaited(c.refreshEnquiries());
  }

  Future<void> _openJourney(String id) async {
    await TripPlanController.to.flushPendingSave();
    await TripNavigation.openJourney(id);
  }

  Future<void> _remove(BuildContext context) async {
    final c = TripPlanController.to;
    final k = legIndex;
    if (k == null) return;
    final a = c.plan.value?.legAt(k)?.arrival;
    if (a == null) return;
    if (a.isOwn) {
      c.clearTravel(k);
      return;
    }
    final impact = c.travelImpact(k);
    if (impact.hasBooked) {
      if (!await TravelConfirmSheet.removeTravel(context, impact.bookedRows)) return;
      await c.removeTravel(k, cancelBooked: true);
      return;
    }
    await c.removeTravel(k);
  }

  void _undoOwn() {
    final c = TripPlanController.to;
    final k = legIndex;
    if (k != null) {
      c.clearTravel(k);
    } else {
      c.resetStep(role!);
    }
  }

  void _editOwn(BuildContext context) {
    final k = legIndex;
    if (k != null) {
      TripOwnTravelSheet.show(context, k);
    } else {
      TripOwnTravelSheet.showForRole(context, role!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.trip.value;
      c.enquiryList.length;
      c.travelGaps.length;
      c.netOff;
      c.taxiTabOff.value;
      _keptBoth.length;
      if (p == null) return const SizedBox.shrink();
      final k = legIndex;
      final leg = k == null ? null : p.legAt(k);
      if (k != null && (leg == null || k < 2)) return const SizedBox.shrink();
      final info = infoOf(c, role: role, legIndex: k);
      final readOnly = c.isReadOnly || c.needsUpdate.value || (k != null && !c.canEditDay(p.legStart(k)));
      final j = journeyOf(c, role: role, legIndex: k);
      final a = leg?.arrival;
      final stepStatus = role == null ? null : c.stepOf(role!).status;
      final own = info?.state == TripStepState.own ||
          info?.state == TripStepState.skipped ||
          (a != null && a.isOwn) ||
          stepStatus == TripStepStatus.own ||
          stepStatus == TripStepStatus.skipped;
      final Widget body;
      if (own) {
        body = _own(context, c, info, a, readOnly);
      } else if (k != null && a != null && a.isJourney && j == null && (c.offline.value || !(c.trip.value?.journeysKnown ?? false))) {
        body = _snapshot(leg!, a, p.legStart(k));
      } else if (k != null && c.travelStateOf(k) == TripTravelState.gap) {
        body = _gap(context, c, leg!, p.legStart(k), readOnly);
      } else if (j == null) {
        body = _notPlanned(context, c, info, readOnly);
      } else {
        body = _journey(context, c, info, j, readOnly);
      }
      return Semantics(
        container: true,
        label: TripStringsMcbA2.travelSemantics(_destination(c), info?.line ?? ''),
        child: body,
      );
    });
  }

  String _destination(TripPlanController c) {
    final k = legIndex;
    if (k != null) return c.plan.value?.legAt(k)?.cityName ?? '';
    return role == TripStepRole.gettingThere ? c.cityName : c.homeEndName;
  }

  String _caption(TripPlanController c) {
    final k = legIndex;
    if (k != null) {
      final day = c.plan.value?.legStart(k) ?? 1;
      return TripStringsMcaA3.travelToLine(_destination(c), day, c.dateOf(day));
    }
    final start = role == TripStepRole.gettingThere ? (c.startFrom?.name ?? '') : c.homeEndName;
    final city = role == TripStepRole.gettingThere ? c.cityName : c.lastCityName;
    final route = role == TripStepRole.gettingThere ? TripStringsMcaA3.fromTo(start, city) : TripStringsMcaA3.fromTo(city, start);
    final date = c.stepDate(role!);
    return date == null ? route : '$route · ${TripFormat.shortDate(date)}';
  }

  Widget _frame(_Look look, Widget child) => Container(
        decoration: BoxDecoration(
          color: look.fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: look.edge.withValues(alpha: 0.55)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(14, 10, 4, 10), child: child),
              Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: look.bar)),
            ],
          ),
        ),
      );

  Widget _icon(IconData icon, Color color) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: color),
      );

  Widget _texts({String? caption, required String title, String? subtitle, required Color subColor, Color? titleColor}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null)
            Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textLight)),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: titleColor ?? AppColors.textDark)),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: subColor)),
        ],
      );

  Widget _header({required Widget icon, required Widget texts, Widget? trailing}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [icon, const SizedBox(width: 10), Expanded(child: texts), trailing ?? const SizedBox(width: 6)],
      );

  Widget _buttons(List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 6),
      child: LayoutBuilder(builder: (context, box) {
        if (items.length == 1) return items.first;
        if (box.maxWidth < 340) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 8), items[i]],
          ]);
        }
        return Row(children: [
          for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: items[i])],
        ]);
      }),
    );
  }

  Widget _primary(String label, VoidCallback? onTap, {Color color = TaxiColors.accentDark}) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textLight,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  Widget _secondary(String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _text(String label, VoidCallback onTap, {Color color = TripColors.accentDark}) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _menu(BuildContext context, List<_JourneyMenu> actions, {String? journeyId}) {
    if (actions.isEmpty) return const SizedBox(width: 6);
    String label(_JourneyMenu a) => switch (a) {
          _JourneyMenu.openJourney => TripStringsJourneyCard.openJourney,
          _JourneyMenu.changeWay => TripStringsJourneyCard.changeWay,
          _JourneyMenu.arrangeMyself => TripStringsJourneyCard.arrangeMyself,
          _JourneyMenu.remove => TripStringsJourneyCard.removeTravel,
        };
    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<_JourneyMenu>(
        icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMedium),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 160),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (v) {
          switch (v) {
            case _JourneyMenu.openJourney:
              if (journeyId != null) _openJourney(journeyId);
            case _JourneyMenu.changeWay:
              _find(context);
            case _JourneyMenu.arrangeMyself:
              arrangeMyself(context, role: role, legIndex: legIndex);
            case _JourneyMenu.remove:
              _remove(context);
          }
        },
        itemBuilder: (_) => [
          for (final a in actions)
            PopupMenuItem(
              value: a,
              child: Text(label(a),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, color: a == _JourneyMenu.remove ? AppColors.error : AppColors.textDark)),
            ),
        ],
      ),
    );
  }

  Widget _startBlock(BuildContext context) => Material(
        color: TripColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => pickStart(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(children: [
                const Icon(Iconsax.location, size: 18, color: TripColors.accentDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    TripPlanController.to.startFrom?.name ?? TripStringsJourneyCard.startNotSet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                ),
                const Text(
                  TripStringsJourneyCard.change,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _notPlanned(BuildContext context, TripPlanController c, TripStepInfo? info, bool readOnly) {
    final k = legIndex;
    final buttons = <Widget>[];
    String? detail;
    var startMissing = false;
    if (k != null) {
      final block = readOnly ? TravelFindBlock.readOnly : c.findWayBlock(k);
      switch (block) {
        case TravelFindBlock.taxiOff:
          detail = TripStringsJourneyCard.noTaxiHere;
        case TravelFindBlock.tooFarAhead:
          detail = TripStringsMcbA2.tooFarAhead;
        case TravelFindBlock.offline:
          detail = TripStringsMcbA2.connectToFind;
        default:
          break;
      }
      if (!readOnly && block != TravelFindBlock.taxiOff) {
        buttons.add(_primary(
          TripStringsJourneyCard.findTaxi,
          block == TravelFindBlock.none ? () => _find(context) : null,
        ));
      }
    } else {
      final r = role;
      startMissing = r == TripStepRole.comingBack ? c.steps.endOf(r!) == null : c.startFrom == null;
      final off = c.netOff;
      if (off && !readOnly) detail = TripStringsMcbA2.connectToFind;
      if (!readOnly) {
        buttons.add(startMissing
            ? _primary(TripStringsJourneyCard.pickStart, () => pickStart(context), color: TripColors.accentDark)
            : _primary(TripStringsJourneyCard.findTaxi, off ? null : () => _find(context)));
      }
    }
    if (!readOnly) {
      buttons.add(_secondary(TripStringsJourneyCard.arrangeMyself, () => arrangeMyself(context, role: role, legIndex: k)));
    }
    return _frame(
      _Look.of(info?.state),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _header(
          icon: _icon(Iconsax.car, AppColors.textLight),
          texts: _texts(title: _caption(c), subtitle: detail, subColor: AppColors.textLight),
        ),
        if (k == null && !readOnly) ...[
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.only(right: 6), child: _startBlock(context)),
        ],
        if (!readOnly && c.travelPeopleCapped) _hint(TripStringsMcbA2.bigGroup, AppColors.textLight),
        _buttons(buttons),
      ]),
    );
  }

  Widget _hint(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 6, right: 6, left: 42),
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _gap(BuildContext context, TripPlanController c, TripCityLeg leg, int day, bool readOnly) {
    final hub = c.travelGaps[legIndex] ?? leg.cityName;
    return _frame(
      _Look.orange,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _header(
          icon: _icon(Iconsax.driving, TripColors.accentDark),
          texts: _texts(
            caption: _caption(c),
            title: TripStringsMcbA2.noDriverFound,
            subtitle: TripStringsMcbA2.reachHub(hub),
            subColor: TripColors.accentDark,
          ),
        ),
        if (!readOnly)
          _buttons([
            _secondary(TripStringsMcbA2.searchAgain, () => _find(context)),
            _primary(
              TripStringsMcbA2.getThereMyself,
              () => TripOwnTravelSheet.show(context, legIndex!, initialHow: TripTravelHow.train, hubName: hub),
              color: TripColors.accentDark,
            ),
          ]),
      ]),
    );
  }

  Widget _own(BuildContext context, TripPlanController c, TripStepInfo? info, TripTravel? a, bool readOnly) {
    final String title;
    String? sub;
    String? phone;
    IconData icon = Iconsax.routing;
    if (a != null && a.isOwn) {
      final how = a.how == null ? null : TripOwnTravelSheet.howLabel(a.how!);
      title = TripStringsJourneyCard.ownLine(how);
      final raw = a.ownPhone;
      phone = raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;
      final hub = a.hubName;
      sub = [
        if (a.leavesAt != null) TripStringsMcaA3.ownTravelLine(how, a.leavesAt),
        a.ownName ?? a.note ?? (hub != null && hub.isNotEmpty ? TripStringsMcbA2.reachHub(hub) : null),
      ].whereType<String>().join(' · ');
      icon = TripOwnTravelSheet.howIcon(a.how);
    } else {
      title = TripStringsJourneyCard.arrangeMyself;
      sub = role == null ? null : c.stepOf(role!).note;
    }
    return _frame(
      _Look.grey,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _header(
          icon: _icon(icon, AppColors.textLight),
          texts: _texts(caption: _caption(c), title: title, subtitle: sub, subColor: AppColors.textLight),
        ),
        if (!readOnly || phone != null)
          Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
            if (phone != null)
              TextButton.icon(
                onPressed: () => ContactLauncher.call(phone!),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Iconsax.call, size: 16, color: TripColors.accentDark),
                label: const Text(TripStringsJourneyCard.call,
                    maxLines: 1,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
              ),
            if (!readOnly) ...[
              _text(TripStringsJourneyCard.edit, () => _editOwn(context)),
              _text(TripStringsJourneyCard.undo, _undoOwn),
            ],
          ]),
      ]),
    );
  }

  Widget _snapshot(TripCityLeg leg, TripTravel a, int day) {
    final total = a.listedTotal;
    final cars = a.cars ?? 1;
    return _frame(
      _Look.grey,
      _header(
        icon: _icon(Iconsax.car, AppColors.textLight),
        texts: _texts(
          caption: _caption(TripPlanController.to),
          title: total != null && total > 0 ? TripStringsMcbA2.carsAbout(cars, BrowseItem.inr(total)) : TripStringsMcaA3.travelTo(leg.cityName),
          subtitle: TripStringsMcbA2.connectToFind,
          subColor: AppColors.textLight,
        ),
      ),
    );
  }

  Widget _journey(BuildContext context, TripPlanController c, TripStepInfo? info, TripJourney j, bool readOnly) {
    final k = legIndex;
    final state = info?.state;
    final look = _Look.of(state);
    final rows = rowsOf(c, j, legIndex: k);
    final cars = j.legs.isEmpty ? (j.cars > 0 ? j.cars : 1) : j.legs.length;
    final total = TripJourneyStrip.totalOf(j);
    final title = total != null && total > 0
        ? TripStringsMcbA2.carsAbout(cars, BrowseItem.inr(total))
        : TripStringsMcaA3.fromTo(j.fromName, j.toName);
    final dateMoved = k != null ? c.travelStateOf(k) == TripTravelState.dateChanged : j.dateChanged;
    final startMoved = k == null && j.startChanged;
    final asked = rows.isNotEmpty || j.isAsked;
    final canAct = !readOnly && canActOn(c, j, role: role, legIndex: k);
    final buttons = <Widget>[];
    if (!readOnly) {
      if (dateMoved || startMoved) {
        buttons.add(_primary(TripStringsJourneyCard.searchAgain, () => _find(context), color: TripColors.accentDark));
      } else if (state != TripStepState.done) {
        if (!asked && canAct) {
          buttons.add(_secondary(TripStringsJourneyCard.changeWay, () => _find(context)));
          buttons.add(_primary(TripStringsJourneyCard.askDrivers(cars), () => _ask(context, j.id)));
        } else if (asked && canAct && (info?.cars.any((l) => l.state == TripCarState.notAsked) ?? false)) {
          buttons.add(_secondary(TripStringsJourneyCard.seeReplies, () => _openJourney(j.id)));
          buttons.add(_primary(TripStringsJourneyCard.askDrivers(cars), () => _ask(context, j.id)));
        } else if (asked) {
          buttons.add(_secondary(TripStringsJourneyCard.changeWay, () => _find(context)));
          buttons.add(_primary(TripStringsJourneyCard.seeReplies, () => _openJourney(j.id)));
        }
      }
    }
    final actions = [
      _JourneyMenu.openJourney,
      if (!readOnly) ...[
        _JourneyMenu.changeWay,
        _JourneyMenu.arrangeMyself,
        if (k != null) _JourneyMenu.remove,
      ],
    ];
    final hint = !readOnly && k != null ? _localTaxiHint(context, c, j, c.plan.value?.legStart(k) ?? 1) : null;
    return _frame(
      look,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _header(
          icon: _icon(Iconsax.car, look == _Look.grey ? AppColors.textLight : look.tone),
          texts: _texts(
            caption: _caption(c),
            title: title,
            subColor: look == _Look.grey ? AppColors.textLight : look.tone,
          ),
          trailing: _menu(context, actions, journeyId: j.id),
        ),
        if (!readOnly && !asked && c.travelPeopleCapped) _hint(TripStringsMcbA2.bigGroup, AppColors.textLight),
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 6),
          child: TripJourneyStrip(key: ValueKey('cars-${role?.name ?? k}-${j.id}'), role: role, legIndex: k),
        ),
        ?hint,
        _buttons(buttons),
      ]),
    );
  }

  Widget? _localTaxiHint(BuildContext context, TripPlanController c, TripJourney j, int day) {
    final key = '${c.trip.value?.id}:$legIndex:${j.id}';
    if (_keptBoth.contains(key) || !c.hasLocalTaxiOn(day)) return null;
    return Container(
      margin: const EdgeInsets.only(top: 10, right: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Iconsax.info_circle, size: 15, color: AppColors.warningText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(TripStringsMcbA2.alsoLocalTaxi(day),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
          ),
        ]),
        Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
          _text(TripStringsMcbA2.keepBoth, () => _keptBoth.add(key), color: AppColors.textMedium),
          _text(TripStringsMcbA2.cancelLocalTaxi, () => _cancelLocalTaxi(context, c, day), color: AppColors.error),
        ]),
      ]),
    );
  }

  Future<void> _cancelLocalTaxi(BuildContext context, TripPlanController c, int day) async {
    final ok = await TravelConfirmSheet.show(
      context,
      title: TripStringsMcbK2.removeDayTitle(day),
      body: TripStringsMcbK2.removeDayBody,
      confirm: TripStringsMcbK2.removeDay,
    );
    if (!ok) return;
    await c.cancelLocalTaxiTravelDay(day);
  }
}

class _ArrangeCar {
  final int car;
  final String driver;
  final bool booked;

  const _ArrangeCar({required this.car, required this.driver, required this.booked});
}

class _ArrangeBody extends StatefulWidget {
  const _ArrangeBody({required this.cars});

  final List<_ArrangeCar> cars;

  @override
  State<_ArrangeBody> createState() => _ArrangeBodyState();
}

class _ArrangeBodyState extends State<_ArrangeBody> {
  late final Set<int> _keep = {for (final c in widget.cars) if (c.booked) c.car};

  Widget _choice(String label, bool on, VoidCallback onTap, Color color) => ChoiceChip(
        label: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : color)),
        selected: on,
        onSelected: (_) => onTap(),
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );

  @override
  Widget build(BuildContext context) {
    final anyBooked = widget.cars.any((c) => c.booked);
    return TripSheetFrame(
      title: TripStringsJourneyCard.arrangeTitle,
      description: TripStringsJourneyCard.arrangeBody,
      footer: anyBooked
          ? const Text(TripStringsJourneyCard.keptCarsNote,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35))
          : null,
      children: [
        for (final c in widget.cars)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  TripStringsJourneyCard.carDriver(c.car, c.driver),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              if (c.booked) ...[
                _choice(TripStringsJourneyCard.keep, _keep.contains(c.car), () => setState(() => _keep.add(c.car)), TripStatusColors.both),
                const SizedBox(width: 6),
                _choice(TripStringsJourneyCard.cancel, !_keep.contains(c.car), () => setState(() => _keep.remove(c.car)),
                    TripStatusColors.failed),
              ] else
                Text(TripStringsJourneyCard.carAsked,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLight)),
            ]),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, Set<int>.from(_keep)),
          style: ElevatedButton.styleFrom(
            backgroundColor: TripColors.accentDark,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(TripStringsJourneyCard.continueLabel,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
