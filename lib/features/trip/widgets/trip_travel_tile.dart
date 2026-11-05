import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/taxi_option_sets.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../../taxi/ways/widgets/travel_confirm_sheet.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../screens/trip_details_sheet.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcb_a1.dart';
import '../trip_strings_mcb_k2.dart';
import '../utils/trip_format.dart';
import '../utils/trip_travel_rules.dart';
import 'trip_journey_strip.dart';
import 'trip_own_travel_sheet.dart';

enum _TravelAction { edit, openJourney, searchAgain, arrangeMyself, remove }

class _Look {
  final Color fill;
  final Color edge;
  final Color bar;
  final Color tone;

  const _Look(this.fill, this.edge, this.bar, this.tone);

  static const grey = _Look(Colors.white, AppColors.divider, AppColors.textHint, AppColors.textLight);
  static const amber = _Look(TripStatusColors.waitingSurface, TripStatusColors.waiting, TripStatusColors.waiting, AppColors.warningText);
  static const blue = _Look(TripStatusColors.bookedSurface, TripStatusColors.booked, TripStatusColors.booked, TripStatusColors.booked);
  static const green = _Look(TripStatusColors.bothSurface, TripStatusColors.both, TripStatusColors.both, AppColors.successText);
  static const orange = _Look(TripColors.surface, TripColors.accent, TripColors.accentDark, TripColors.accentDark);

  static _Look of(TripTravelState s) => switch (s) {
        TripTravelState.notPlanned || TripTravelState.saved => grey,
        TripTravelState.gap => orange,
        TripTravelState.own || TripTravelState.booked => blue,
        TripTravelState.confirmed => green,
        _ => amber,
      };
}

class TripTravelTile extends StatelessWidget {
  const TripTravelTile({super.key, required this.legIndex});

  final int legIndex;

  static final RxSet<String> _keptBoth = <String>{}.obs;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.trip.value;
      c.enquiryList.length;
      c.travelGaps.length;
      c.offline.value;
      c.taxiTabOff.value;
      _keptBoth.length;
      final leg = p?.legAt(legIndex);
      if (p == null || leg == null || legIndex < 2) return const SizedBox.shrink();
      final day = p.legStart(legIndex);
      final readOnly = c.isReadOnly || c.needsUpdate.value || !c.canEditDay(day);
      final a = leg.arrival;
      final state = c.travelStateOf(legIndex);
      final journey = c.segmentJourney(legIndex);
      final Widget body;
      if (a != null && a.isOwn) {
        body = _own(context, a, readOnly);
      } else if (a != null && a.isJourney && journey == null && c.offline.value) {
        body = _snapshot(context, leg, a, day);
      } else if (state == TripTravelState.gap) {
        body = _gap(context, leg, day, readOnly);
      } else if (journey == null || a == null || !a.isJourney) {
        body = _notPlanned(context, leg, day, readOnly);
      } else {
        body = _journey(context, leg, a, journey, state, day, readOnly);
      }
      return Semantics(
        container: true,
        label: TripStringsMcbA2.travelSemantics(leg.cityName, TripStringsMcbA1.stateLabel(state)),
        child: body,
      );
    });
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: subColor)),
        ],
      );

  Widget _pill(String text, _Look look) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: look == _Look.grey ? AppColors.divider : look.bar.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: look.tone)),
      );

  Widget _header({
    required Widget icon,
    required Widget texts,
    String? pill,
    _Look look = _Look.grey,
    Widget? trailing,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(child: texts),
          if (pill != null) ...[
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Padding(padding: const EdgeInsets.only(top: 2), child: _pill(pill, look)),
            ),
          ],
          trailing ?? const SizedBox(width: 6),
        ],
      );

  Widget _buttons(List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 6),
      child: LayoutBuilder(builder: (context, box) {
        if (items.length == 1) return Align(alignment: Alignment.centerRight, child: items.first);
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

  Widget _primary(String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) => ElevatedButton(
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

  String _caption(TripCityLeg leg, int day) =>
      TripStringsMcaA3.travelToLine(leg.cityName, day, TripPlanController.to.dateOf(day));

  Future<void> _find(BuildContext context) async {
    final c = TripPlanController.to;
    if (c.findWayBlock(legIndex) == TravelFindBlock.noDates) {
      await TripDetailsSheet.edit(context);
      return;
    }
    await TripNavigation.openSegmentWays(legIndex);
  }

  Future<void> _remove(BuildContext context) async {
    final c = TripPlanController.to;
    final a = c.plan.value?.legAt(legIndex)?.arrival;
    if (a == null) return;
    if (a.isOwn) {
      c.clearTravel(legIndex);
      return;
    }
    final impact = c.travelImpact(legIndex);
    if (impact.hasBooked) {
      if (!await TravelConfirmSheet.removeTravel(context, impact.bookedRows)) return;
      await c.removeTravel(legIndex, cancelBooked: true);
      return;
    }
    await c.removeTravel(legIndex);
  }

  Future<void> _openJourney(String id) async {
    await TripPlanController.to.flushPendingSave();
    await TripNavigation.openJourney(id);
  }

  void _onMenu(BuildContext context, _TravelAction v, String? journeyId) {
    switch (v) {
      case _TravelAction.edit:
      case _TravelAction.arrangeMyself:
        TripOwnTravelSheet.show(context, legIndex);
      case _TravelAction.openJourney:
        if (journeyId != null) _openJourney(journeyId);
      case _TravelAction.searchAgain:
        _find(context);
      case _TravelAction.remove:
        _remove(context);
    }
  }

  Widget _menu(BuildContext context, List<_TravelAction> actions, {String? journeyId}) {
    if (actions.isEmpty) return const SizedBox(width: 6);
    String label(_TravelAction a) => switch (a) {
          _TravelAction.edit => TripStringsMcaA3.edit,
          _TravelAction.openJourney => TripStringsMcbA2.openJourney,
          _TravelAction.searchAgain => TripStringsMcbA2.searchAgain,
          _TravelAction.arrangeMyself => TripStringsMcaA3.arrangeMyself,
          _TravelAction.remove => TripStringsMcbA2.removeTravel,
        };
    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<_TravelAction>(
        icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMedium),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 160),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (v) => _onMenu(context, v, journeyId),
        itemBuilder: (_) => [
          for (final a in actions)
            PopupMenuItem(
              value: a,
              child: Text(label(a),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: a == _TravelAction.remove ? AppColors.error : AppColors.textDark)),
            ),
        ],
      ),
    );
  }

  Widget _notPlanned(BuildContext context, TripCityLeg leg, int day, bool readOnly) {
    final c = TripPlanController.to;
    final block = readOnly ? TravelFindBlock.readOnly : c.findWayBlock(legIndex);
    final String detail = switch (block) {
      TravelFindBlock.noDates => TripStringsMcbA2.addDatesFirst,
      TravelFindBlock.tooFarAhead => TripStringsMcbA2.tooFarAhead,
      TravelFindBlock.taxiOff => TripStringsMcbA2.taxiOff,
      TravelFindBlock.offline => TripStringsMcbA2.connectToFind,
      _ => TripStringsMcaA3.notPlannedYet,
    };
    final buttons = <Widget>[];
    if (!readOnly) {
      if (block == TravelFindBlock.noDates) {
        buttons.add(_primary(TripStringsMcbA2.addDates, () => TripDetailsSheet.edit(context)));
      } else if (block != TravelFindBlock.taxiOff) {
        buttons.add(_primary(
          TripStringsMcbA2.findAWay,
          block == TravelFindBlock.none ? () => _find(context) : null,
          color: TaxiColors.accentDark,
        ));
      }
      buttons.add(_secondary(TripStringsMcaA3.arrangeMyself, () => TripOwnTravelSheet.show(context, legIndex)));
    }
    return _frame(
      _Look.grey,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _header(
          icon: _icon(Iconsax.car, AppColors.textLight),
          texts: _texts(title: _caption(leg, day), subtitle: detail, subColor: AppColors.textLight),
        ),
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

  Widget _gap(BuildContext context, TripCityLeg leg, int day, bool readOnly) {
    final c = TripPlanController.to;
    final hub = c.travelGaps[legIndex] ?? leg.cityName;
    return _frame(
      _Look.orange,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _header(
          icon: _icon(Iconsax.driving, TripColors.accentDark),
          texts: _texts(
            caption: _caption(leg, day),
            title: TripStringsMcbA2.noDriverFound,
            subtitle: TripStringsMcbA2.reachHub(hub),
            subColor: TripColors.accentDark,
          ),
          pill: TripStringsMcbA2.gapTag,
          look: _Look.orange,
        ),
        if (!readOnly)
          _buttons([
            _secondary(TripStringsMcbA2.searchAgain, () => _find(context)),
            _primary(
              TripStringsMcbA2.getThereMyself,
              () => TripOwnTravelSheet.show(context, legIndex, initialHow: TripTravelHow.train, hubName: hub),
            ),
          ]),
      ]),
    );
  }

  Widget _own(BuildContext context, TripTravel a, bool readOnly) {
    final how = a.how == null ? null : TripOwnTravelSheet.howLabel(a.how!);
    final raw = a.ownPhone;
    final phone = raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;
    final hub = a.hubName;
    final sub = a.ownName ?? a.note ?? (hub != null && hub.isNotEmpty ? TripStringsMcbA2.reachHub(hub) : null);
    return _frame(
      _Look.blue,
      Row(
        children: [
          _icon(TripOwnTravelSheet.howIcon(a.how), TripStatusColors.booked),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: readOnly ? null : () => TripOwnTravelSheet.show(context, legIndex),
              child: _texts(title: TripStringsMcaA3.ownTravelLine(how, a.leavesAt), subtitle: sub, subColor: TripStatusColors.booked),
            ),
          ),
          if (phone != null)
            TextButton.icon(
              onPressed: () => ContactLauncher.call(phone),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
              icon: const Icon(Iconsax.call, size: 16, color: TripStatusColors.booked),
              label: const Text(TripStringsMcaA3.call,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripStatusColors.booked)),
            ),
          if (!readOnly) _menu(context, const [_TravelAction.edit, _TravelAction.remove]),
        ],
      ),
    );
  }

  Widget _snapshot(BuildContext context, TripCityLeg leg, TripTravel a, int day) {
    final total = a.listedTotal;
    final cars = a.cars ?? 1;
    return _frame(
      _Look.grey,
      _header(
        icon: _icon(Iconsax.car, AppColors.textLight),
        texts: _texts(
          caption: _caption(leg, day),
          title: total != null && total > 0 ? TripStringsMcbA2.carsAbout(cars, BrowseItem.inr(total)) : TripStringsMcaA3.travelTo(leg.cityName),
          subtitle: TripStringsMcbA2.connectToFind,
          subColor: AppColors.textLight,
        ),
      ),
    );
  }

  Widget _journey(
    BuildContext context,
    TripCityLeg leg,
    TripTravel a,
    TripJourney j,
    TripTravelState state,
    int day,
    bool readOnly,
  ) {
    final c = TripPlanController.to;
    final rows = c.segmentRows(legIndex);
    final look = _Look.of(state);
    final cars = j.legs.isEmpty ? (a.cars ?? 1) : j.legs.length;
    final total = TripJourneyStrip.totalOf(j) ?? a.listedTotal;
    final date = c.travelDateOf(legIndex);
    String title;
    String? sub;
    Color subColor = look.tone;
    Color? titleColor;
    String? pill;
    final buttons = <Widget>[];
    var expanded = false;
    switch (state) {
      case TripTravelState.saved:
        title = total != null && total > 0 ? TripStringsMcbA2.carsAbout(cars, BrowseItem.inr(total)) : TripStringsMcaA3.travelTo(leg.cityName);
        sub = TripStringsMcbA2.savedNotAsked;
        subColor = AppColors.textLight;
        if (!readOnly) buttons.add(_primary(TripStringsMcbA2.askDrivers, () => _openJourney(j.id), color: TripStatusColors.booked));
      case TripTravelState.asked:
        title = TripStringsMcbA2.askedAnswered(TripTravelRules.answeredCount(j), cars);
        sub = [
          for (final l in j.legs)
            if (l.isAsked)
              l.lastKnownStatus == TripTravelRules.freeStatus
                  ? TripStringsMcbA2.nameFree(TripJourneyStrip.firstName(l.driverName))
                  : TripStringsMcbA2.nameWaiting(TripJourneyStrip.firstName(l.driverName)),
        ].join(' · ');
        pill = TripStringsMcbA2.waiting;
      case TripTravelState.free:
        title = TripStringsMcbA2.freeNames([
          for (final l in j.legs)
            if (l.lastKnownStatus == TripTravelRules.freeStatus && !TripTravelRules.carBooked(j, l.legIndex, rows))
              [TripJourneyStrip.firstName(l.driverName), if (TripJourneyStrip.fareOf(l) != null) BrowseItem.inr(TripJourneyStrip.fareOf(l)!)]
                  .join(' '),
        ].join(', '));
        pill = TripStringsMcbA2.free;
        expanded = true;
      case TripTravelState.partlyBooked:
        final booked = j.legs.where((l) => TripTravelRules.carBooked(j, l.legIndex, rows)).length;
        title = TripStringsMcbA2.partlyBooked(booked, cars);
        pill = TripStringsMcbA2.waiting;
        expanded = true;
      case TripTravelState.booked:
        title = TripStringsMcbA2.bookedByYouCars(cars);
        sub = TripStringsMcbA2.driversConfirmNext;
        pill = TripStringsMcbA2.booked;
      case TripTravelState.confirmed:
        title = TripStringsMcbA2.confirmedByBoth;
        sub = j.legs.map((l) => TripJourneyStrip.firstName(l.driverName)).join(' · ');
        pill = TripStringsMcbA2.ready;
      case TripTravelState.driverUnavailable:
        final out = j.legs.where((l) => !l.driverAvailable && !TripTravelRules.carBooked(j, l.legIndex, rows)).toList();
        title = TripStringsMcbA2.driversUnavailable(out.isEmpty ? 1 : out.length);
        final backup = out.isEmpty ? null : out.first.backupName;
        sub = backup != null && backup.isNotEmpty ? TripStringsMcbA2.replaceWith(backup) : null;
        subColor = TripStatusColors.failed;
        pill = TripStringsMcbA2.replaceTag;
        expanded = true;
        if (!readOnly) buttons.add(_primary(TripStringsMcbA2.replaceDriver, () => _openJourney(j.id)));
      case TripTravelState.dateChanged:
        title = TripStringsMcbA2.travelDateChanged;
        sub = date == null ? null : TripStringsMcbA2.searchAgainFor(TripFormat.shortDate(date));
        pill = TripStringsMcbA2.checkTag;
        if (!readOnly) buttons.add(_primary(TripStringsMcbA2.searchAgain, () => _find(context)));
      case TripTravelState.carMissing:
        final missing = j.legs.where((l) => TripTravelRules.carMissing(j, l.legIndex, rows)).toList();
        title = TripStringsMcbA2.carNoDriverTitle(missing.isEmpty ? 1 : missing.first.legIndex);
        titleColor = TripStatusColors.failed;
        sub = TripStringsMcbA2.askBackup;
        pill = TripStringsMcbA2.noDriver;
        expanded = true;
        if (!readOnly) buttons.add(_primary(TripStringsMcbA2.askBackup, () => _openJourney(j.id)));
      default:
        title = TripStringsMcaA3.travelTo(leg.cityName);
    }
    final actions = [
      _TravelAction.openJourney,
      if (!readOnly) ...[_TravelAction.searchAgain, _TravelAction.arrangeMyself, _TravelAction.remove],
    ];
    final hint = !readOnly ? _localTaxiHint(context, c, a, day) : null;
    return _frame(
      look,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _header(
          icon: _icon(Iconsax.car, look == _Look.grey ? AppColors.textLight : look.tone),
          texts: _texts(caption: _caption(leg, day), title: title, subtitle: sub, subColor: subColor, titleColor: titleColor),
          pill: pill,
          look: look,
          trailing: _menu(context, actions, journeyId: j.id),
        ),
        if (!readOnly && state == TripTravelState.saved && c.travelPeopleCapped)
          _hint(TripStringsMcbA2.bigGroup, AppColors.textLight),
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 6),
          child: _JourneyCars(
            key: ValueKey('cars-$legIndex-${j.id}'),
            legIndex: legIndex,
            initiallyOpen: expanded,
            showToggle: state != TripTravelState.saved && state != TripTravelState.dateChanged,
          ),
        ),
        ?hint,
        _buttons(buttons),
      ]),
    );
  }

  Widget? _localTaxiHint(BuildContext context, TripPlanController c, TripTravel a, int day) {
    final key = '${c.trip.value?.id}:$legIndex:${a.journeyId}';
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
          TextButton(
            onPressed: () => _keptBoth.add(key),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text(TripStringsMcbA2.keepBoth,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => _cancelLocalTaxi(context, c, day),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text(TripStringsMcbA2.cancelLocalTaxi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
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

class _JourneyCars extends StatefulWidget {
  const _JourneyCars({super.key, required this.legIndex, required this.initiallyOpen, required this.showToggle});

  final int legIndex;
  final bool initiallyOpen;
  final bool showToggle;

  @override
  State<_JourneyCars> createState() => _JourneyCarsState();
}

class _JourneyCarsState extends State<_JourneyCars> {
  late bool _open = widget.initiallyOpen;

  @override
  void didUpdateWidget(covariant _JourneyCars old) {
    super.didUpdateWidget(old);
    if (widget.initiallyOpen && !old.initiallyOpen) _open = true;
  }

  @override
  Widget build(BuildContext context) {
    final open = _open && widget.showToggle;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: TripJourneyStrip(legIndex: widget.legIndex, dense: !open),
      ),
      if (widget.showToggle)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 6)),
            icon: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: AppColors.textMedium),
            label: Text(open ? TripStringsMcbA2.hideCars : TripStringsMcbA2.showCars,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
          ),
        ),
    ]);
  }
}
