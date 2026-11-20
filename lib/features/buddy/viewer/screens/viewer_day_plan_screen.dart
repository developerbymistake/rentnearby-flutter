import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../trip/models/trip_spot_category.dart';
import '../../../trip/widgets/trip_ui.dart';
import '../../buddy_navigation.dart';
import '../../ledger/data/ledger_api.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_page.dart';
import '../controllers/viewer_trip_controller.dart';
import '../data/trip_viewer_api.dart';
import '../models/viewer_models.dart';
import '../viewer_look.dart';
import '../viewer_rules.dart';
import '../viewer_strings.dart';

class ViewerDayPlanScreen extends StatefulWidget {
  const ViewerDayPlanScreen({super.key, required this.tripId, this.day, this.api, this.ledger});

  final String tripId;
  final int? day;
  final TripViewerApi? api;
  final LedgerApi? ledger;

  @override
  State<ViewerDayPlanScreen> createState() => _ViewerDayPlanScreenState();
}

class _ViewerDayPlanScreenState extends State<ViewerDayPlanScreen> {
  late final ViewerTripController _c;
  bool _own = false;
  bool _scrolled = false;
  bool _redirected = false;
  final Map<int, GlobalKey> _dayKeys = {};

  @override
  void initState() {
    super.initState();
    final existing = ViewerTripController.maybeOf(widget.tripId);
    if (existing != null) {
      _c = existing;
      if (_c.dayTotals.isEmpty) _c.loadDayTotals();
    } else {
      _own = true;
      _c = Get.put(ViewerTripController(widget.tripId, api: widget.api, ledger: widget.ledger), tag: widget.tripId);
    }
  }

  @override
  void dispose() {
    if (_own && identical(ViewerTripController.maybeOf(widget.tripId), _c)) Get.delete<ViewerTripController>(tag: widget.tripId, force: true);
    super.dispose();
  }

  void _scrollToDay() {
    final d = widget.day;
    if (_scrolled || d == null) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _dayKeys[d]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
    });
  }

  void _leave() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => BuddyNavigation.openTripView(widget.tripId, replace: true));
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final s = _c.state.value;
        final t = _c.trip.value;
        if (s == ViewerTripState.notOnTrip || s == ViewerTripState.deleted || s == ViewerTripState.owner) _leave();
        if (t == null) {
          return BuddyPage(
            title: ViewerStrings.overviewTitle,
            body: s == ViewerTripState.failed
                ? StateCard3D(
                    tone: BuddyLook.indigo,
                    art: BuddyArt.antenna,
                    title: BuddySharedStrings.couldNotLoad,
                    message: BuddySharedStrings.couldNotLoadLine,
                    actionLabel: BuddySharedStrings.retry,
                    onAction: _c.load,
                    layout: StateLayout.tall,
                  )
                : Padding(padding: DS.all(40), child: const Center(child: CircularProgressIndicator())),
          );
        }
        _scrollToDay();
        final totals = Map<int, int>.of(_c.dayTotals);
        final dates = BuddyFormat.dateRange(t.startDate, t.endDate);
        return BuddyPage(
          title: t.title,
          subtitle: ViewerStrings.dayPlanLine(t.dayCount, dates, t.owner.name),
          trailing: [TripHeaderAction(key: const ValueKey('viewer_map'), label: ViewerStrings.map, onTap: () => BuddyNavigation.openDayMap(t.tripId))],
          body: Padding(
            padding: EdgeInsets.only(bottom: DS.s(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final leg in _legsOf(t))
                  _LegSection(
                    trip: t,
                    leg: leg,
                    days: [for (final d in t.days) if (d.leg == leg.index) d],
                    totals: totals,
                    keyOf: (day) => _dayKeys.putIfAbsent(day, GlobalKey.new),
                  ),
              ],
            ),
          ),
        );
      });

  static List<ViewerLeg> _legsOf(ViewerTrip t) {
    if (t.legs.isNotEmpty) return t.legs;
    if (t.days.isEmpty) return const [];
    return [
      ViewerLeg(
        index: 1,
        cityName: t.legCities.isEmpty ? t.title : t.legCities.first,
        firstDay: t.days.first.day,
        lastDay: t.days.last.day,
        nights: t.dayCount,
        spotCount: t.spotCount,
      ),
    ];
  }
}

class _LegSection extends StatelessWidget {
  const _LegSection({required this.trip, required this.leg, required this.days, required this.totals, required this.keyOf});

  final ViewerTrip trip;
  final ViewerLeg leg;
  final List<ViewerDay> days;
  final Map<int, int> totals;
  final GlobalKey Function(int day) keyOf;

  @override
  Widget build(BuildContext context) {
    final outer = DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));
    final head = DS.br(const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(36)));
    return Container(
      key: ValueKey('viewer_leg_${leg.index}'),
      margin: DS.insets(l: 18, t: 44, r: 18),
      decoration: BoxDecoration(
        color: ViewerLook.legBg,
        borderRadius: outer,
        border: Border.all(color: ViewerLook.legBorder, width: DS.s(2)),
        boxShadow: DS.shadows(ViewerLook.legShadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(minHeight: DS.s(96)),
                padding: DS.insets(l: 92, t: 14, r: 14, b: 16),
                decoration: BoxDecoration(gradient: ViewerLook.indigoGradient, borderRadius: head),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(leg.cityName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, DesignColors.surface, height: 1.3, letterSpacing: 0)),
                          Text(ViewerStrings.legRange(leg.firstDay, leg.lastDay, ViewerRules.legDates(trip, leg)),
                              style: Ink3D.text(12.5, FontWeight.w400, DesignColors.surface, height: 1.55, letterSpacing: 0)),
                          Text(ViewerStrings.legDetail(leg.spotCount, leg.nights), style: Ink3D.text(12.5, FontWeight.w400, DesignColors.surface, height: 1.55, letterSpacing: 0)),
                        ],
                      ),
                    ),
                    Gap.h(8),
                    const _LegChip(),
                  ],
                ),
              ),
              Positioned(
                left: DS.s(10),
                top: DS.s(-16),
                child: ExcludeSemantics(
                  child: Art3D(asset: ListingArt.mountain, size: 68, halo: 66, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22), shadowBlur: 4, shadowOffset: const Offset(3, 5)),
                ),
              ),
            ],
          ),
          Stack(
            children: [
              Positioned(
                left: DS.s(14),
                top: 0,
                bottom: DS.s(36),
                child: Container(width: DS.s(4), decoration: BoxDecoration(color: ViewerLook.rail, borderRadius: DS.circular(2))),
              ),
              Padding(
                padding: DS.insets(l: 30, r: 12, b: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in days)
                      _DayCard(
                        key: keyOf(d.day),
                        tripId: trip.tripId,
                        day: d,
                        date: ViewerRules.dateOfDay(trip, d.day),
                        color: ViewerLook.dayColor(d.day - leg.firstDay + 1),
                        spent: totals[d.day] ?? 0,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegChip extends StatelessWidget {
  const _LegChip();

  @override
  Widget build(BuildContext context) => Container(
        height: DS.s(40),
        padding: DS.sym(h: 14),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(20), boxShadow: DS.shadows(ViewerLook.whiteBtn)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Image.asset(BuddyArt.locked, width: DS.s(18), height: DS.s(18))),
            Gap.h(6),
            Text(BuddySharedStrings.viewOnly, style: Ink3D.text(12, FontWeight.w700, BuddyLook.tealEnd, letterSpacing: 0)),
          ],
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({super.key, required this.tripId, required this.day, required this.date, required this.color, required this.spent});

  final String tripId;
  final ViewerDay day;
  final DateTime? date;
  final Color color;
  final int spent;

  @override
  Widget build(BuildContext context) {
    final radius = DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));
    final rows = <Widget>[];
    if (day.restDay || day.spots.isEmpty) {
      rows.add(Padding(
        padding: DS.sym(h: 16, v: 18),
        child: Text(day.restDay ? ViewerStrings.restDay : ViewerStrings.noPlacesYet, style: Ink3D.text(13.5, FontWeight.w600, ViewerLook.sub, letterSpacing: 0)),
      ));
    } else {
      for (var i = 0; i < day.spots.length; i++) {
        final s = day.spots[i];
        rows.add(_SpotRow(spot: s, number: i + 1, color: color));
        final road = s.travelMinutesToNext;
        if (i < day.spots.length - 1 && road != null) rows.add(_DriveRow(minutes: road));
      }
    }
    if (spent > 0) {
      rows.add(InkWell(
        key: ValueKey('viewer_spent_${day.day}'),
        onTap: () => BuddyNavigation.openExpenses(tripId, day: day.day),
        child: Container(
          margin: DS.sym(h: 14),
          padding: DS.insets(l: 4, t: 10, r: 4, b: 2),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: ViewerLook.line))),
          child: Row(
            children: [
              ExcludeSemantics(child: Image.asset(BuddyArt.moneyBag, width: DS.s(22), height: DS.s(22))),
              Gap.h(8),
              Expanded(child: Text(ViewerStrings.spentOnDay(spent), style: Ink3D.text(12.5, FontWeight.w700, ViewerLook.roseText, letterSpacing: 0))),
              Text(ViewerStrings.arrow, style: Ink3D.text(12.5, FontWeight.w700, ViewerLook.roseText, letterSpacing: 0)),
            ],
          ),
        ),
      ));
    }
    return Padding(
      padding: EdgeInsets.only(top: DS.s(48)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.only(bottom: DS.s(8)),
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: DS.shadows(ViewerLook.dayShadow)),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: DS.insets(l: 88, t: 14, r: 14, b: 14),
                    decoration: const BoxDecoration(gradient: ViewerLook.indigoGradient),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: DS.s(40)),
                          child: Row(
                            children: [
                              Container(
                                width: DS.s(14),
                                height: DS.s(14),
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: DesignColors.surface, width: DS.s(2.5))),
                              ),
                              Gap.h(8),
                              Expanded(
                                child: Text(
                                  ViewerStrings.dayTitle(day.day, date == null ? null : BuddyFormat.weekdayDate(date!)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ink3D.text(17, FontWeight.w700, DesignColors.surface, height: 1.3, letterSpacing: 0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!day.restDay && day.spots.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: DS.s(2)),
                            child: Row(
                              children: [
                                Text(ViewerRules.duration(day.totalMinutes), style: Ink3D.text(13, FontWeight.w600, DesignColors.surface, letterSpacing: 0)),
                                Gap.h(10),
                                Container(
                                  height: DS.s(28),
                                  alignment: Alignment.center,
                                  padding: DS.sym(h: 10),
                                  decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surface, Alpha.v25), borderRadius: DS.circular(10)),
                                  child: Text(ViewerStrings.places(day.placeCount == 0 ? day.spots.length : day.placeCount),
                                      style: Ink3D.text(12.5, FontWeight.w700, DesignColors.surface, letterSpacing: 0)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...rows,
                ],
              ),
            ),
          ),
          Positioned(
            left: DS.s(10),
            top: DS.s(-13),
            child: ExcludeSemantics(
              child: Art3D(asset: BuddyArt.calendar, size: 63, halo: 62, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22), shadowBlur: 5, shadowOffset: const Offset(4, 6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.spot, required this.number, required this.color});

  final ViewerSpot spot;
  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cat = spot.category ?? '';
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(60)),
      child: Padding(
        padding: DS.insets(l: 12, t: 8, r: 8, b: 8),
        child: Row(
          children: [
            SizedBox(
              width: DS.s(66),
              child: Text(BuddyFormat.time12(spot.startTime), style: Ink3D.text(12.5, FontWeight.w600, ViewerLook.sub, letterSpacing: 0)),
            ),
            Container(
              width: DS.s(26),
              height: DS.s(26),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text('$number', style: Ink3D.text(12.5, FontWeight.w700, DesignColors.surface, height: 1, letterSpacing: 0)),
            ),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, ViewerLook.ink, letterSpacing: 0)),
                  Text(
                    ViewerStrings.dot(TripSpotCategory.label(cat), ViewerRules.duration(spot.visitMinutes)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12.5, FontWeight.w400, ViewerLook.greyKey, letterSpacing: 0),
                  ),
                ],
              ),
            ),
            Gap.h(10),
            ExcludeSemantics(child: Image.asset(TripSpotLook.assetOf(cat), width: DS.s(30), height: DS.s(30))),
          ],
        ),
      ),
    );
  }
}

class _DriveRow extends StatelessWidget {
  const _DriveRow({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(left: DS.s(86)),
        padding: DS.insets(l: 18, t: 3, b: 3),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: DesignColors.tint(ViewerLook.planTo, Alpha.v30), width: DS.s(2)))),
        child: Row(
          children: [
            ExcludeSemantics(child: Image.asset(ListingArt.taxi, width: DS.s(16), height: DS.s(16))),
            Gap.h(8),
            Text(ViewerRules.road(minutes), style: Ink3D.text(12.5, FontWeight.w400, ViewerLook.greyKey, letterSpacing: 0)),
          ],
        ),
      );
}
