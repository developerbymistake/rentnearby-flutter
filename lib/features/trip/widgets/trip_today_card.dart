import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_navigation.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_fin_b1.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcb_a1.dart';
import '../trip_strings_mcd_a3.dart';
import '../trip_strings_steps_a3.dart';
import '../trip_strings_v2_plan.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../utils/trip_format.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_travel_rules.dart';
import 'trip_problem_sheet.dart';

class TripTodayCard extends StatelessWidget {
  const TripTodayCard({super.key});

  static String? _validPhone(String? raw) =>
      raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;

  static String? stayPhone(TripEnquiryModel e) => _validPhone(e.owner.phone);

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.plan.value;
      c.enquiryList.length;
      c.trip.value;
      final today = c.todayDay;
      final journey = c.journeyToday;
      final checkOutDay = today == null && c.isCheckOutDay;
      if ((today == null && journey == null && !checkOutDay) || c.isCompleted) return const SizedBox.shrink();
      final n = today ?? _nearestDay(c);
      final offline = c.offline.value;
      final travelDay = today != null && c.isMultiCity && c.isTravelDay(n);
      final rows = <Widget>[
        if (checkOutDay) ..._checkOutRow(c, c.dayCount + 1),
        if (journey != null) ..._travelRows(journey),
        if (travelDay) ..._travelDayRows(c, n),
        if (travelDay) ..._checkOutRow(c, n),
        if (today != null) ..._stayRow(c, n, travelDay: travelDay),
        if (today != null) ..._taxiRow(c, n),
        if (today != null) ..._routeRow(c, n, offline, travelDay: travelDay),
      ];
      final title = today == null
          ? (journey == null ? TripStringsFinB1.checkOutDay : TripStringsStepsA3.travelDay(_todayDate))
          : !c.isMultiCity
              ? TripStrings.todayDay(n, c.dayCount)
              : travelDay
                  ? TripStringsMcdA3.todayTravelDay(n, c.dayCount)
                  : TripStringsMcdA3.todayDayCity(n, c.dayCount, c.cityNameOf(n));
      final narrow = MediaQuery.sizeOf(context).width < 340;
      final art = narrow ? 76.0 : 92.0;
      final tone = ListingTone.indigo;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
              decoration: BoxDecoration(
                gradient: tone.gradient,
                borderRadius: kMealsRadius,
                boxShadow: [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 6), blurRadius: 14)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TemplateEntranceOnce(
                    index: 0,
                    count: 6,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, art - 6, 0),
                      child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(19, FontWeight.w700, DesignColors.textInverse, height: 1.25)),
                    ),
                  ),
                  if (offline) ...[
                    const SizedBox(height: 10),
                    _offlineBanner(),
                  ],
                  for (var i = 0; i < rows.length; i++) ...[
                    const SizedBox(height: 10),
                    TemplateEntranceOnce(index: i + 1, count: 6, child: rows[i]),
                  ],
                  if (today != null || _problemAllowed(c)) ...[
                    const SizedBox(height: 12),
                    TemplateEntranceOnce(index: 5, count: 6, child: _problemButton(context, n)),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 26,
            top: 0,
            child: IgnorePointer(child: Art3D(asset: ListingArt.sunrise, size: art, halo: art + 6, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22))),
          ),
        ],
      );
    });
  }

  Widget _offlineBanner() => _onCardLine(Icons.cloud_off_rounded, TripStrings.offlineSaved);

  static Widget _onCardLine(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surface, Alpha.soft), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, size: 16, color: DesignColors.surface),
          const SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, DesignColors.textInverse))),
        ]),
      );

  static bool _problemAllowed(TripPlanController c) {
    final first = c.dateOf(1);
    final out = c.stepDate(TripStepRole.comingBack) ?? c.checkOutDate;
    if (first == null || out == null) return false;
    final t = _todayDate;
    return !t.isBefore(DateTime(first.year, first.month, first.day)) && !t.isAfter(DateTime(out.year, out.month, out.day));
  }

  static int _nearestDay(TripPlanController c) {
    final first = c.dateOf(1);
    return first != null && _todayDate.isBefore(first) ? 1 : c.dayCount;
  }

  static List<Widget> _travelRows(TripJourney j) {
    final legs = j.legs;
    if (legs.isEmpty) return const [];
    final multi = legs.length > 1;
    final leg = multi ? legs[1] : legs.first;
    final phone = _validPhone(leg.phone);
    final head = j.role == TripStepRole.comingBack ? TripStringsStepsA3.todayComingBack : TripStringsStepsA3.todayGettingThere;
    final paused = legs.where((l) => !l.driverAvailable).firstOrNull;
    return [
      _caps(head),
      _TravelRow(
        title: multi ? TripStringsStepsA3.changeCarAt(leg.changePlace) : TripStringsStepsA3.takesYou(leg.driverName, j.toName),
        subtitle: multi
            ? TripStringsStepsA3.nextDriver(leg.driverName)
            : [leg.vehicleTypeName, leg.plateDisplay].where((e) => e != null && e.isNotEmpty).join(' · '),
        onCall: phone == null ? null : () => ContactLauncher.call(phone),
      ),
      if (paused != null) _amberLine(TripStringsStepsA3.pausedBackup(paused.driverName, paused.backupName)),
    ];
  }

  static DateTime get _todayDate => TripClock.today();

  static String _checkOutLine(DateTime checkOut) {
    final t = _todayDate;
    final tomorrow = DateTime(t.year, t.month, t.day + 1);
    return checkOut == tomorrow ? TripStringsA5.checkOutTomorrow : TripStringsA5.checkOutOn(TripFormat.shortDate(checkOut));
  }

  static ({int k, int total, DateTime checkOut}) _nightOf(TripEnquiryModel e) {
    final today = _todayDate;
    final inDate = e.checkIn == null ? null : DateTime(e.checkIn!.year, e.checkIn!.month, e.checkIn!.day);
    final total = inDate == null ? 1 : e.nights.clamp(1, 1 << 20);
    final k = inDate == null ? 1 : TripClock.nightOf(inDate, total, today);
    final out = e.checkOut == null
        ? DateTime(today.year, today.month, today.day + total - k + 1)
        : DateTime(e.checkOut!.year, e.checkOut!.month, e.checkOut!.day);
    return (k: k, total: total, checkOut: out);
  }

  static Widget _caps(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text.toUpperCase(),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, DesignColors.whiteHigh, letterSpacing: 0.6)),
      );

  static Widget _amberLine(String text) => _onCardLine(Icons.warning_amber_rounded, text);

  static String _carState(TripJourneyLeg leg) {
    if (leg.lastKnownStatus == TripTravelRules.freeStatus) return TripStringsMcbA2.free;
    return leg.lastEnquiryId != null ? TripStringsMcbA2.asked : TripStringsMcbA2.notAsked;
  }

  static Widget _carRow(TripJourneyLeg cl, int i, TripEnquiryModel? booking) {
    final pickup = booking?.taxi?.pickupTime;
    final fare = booking?.taxi?.agreedFare ?? cl.lastQuotedFare ?? cl.listedFare;
    final phone = _validPhone(booking?.owner.phone) ?? _validPhone(cl.phone) ?? _validPhone(cl.whatsApp);
    return _Row(
      icon: TravelIcon.taxi,
      accent: DesignColors.error,
      surface: TripEntryStyle.roseTint,
      title: TripStringsMcdA3.carRow(cl.driverName.isEmpty ? TripStrings.driver : cl.driverName, i),
      subtitle: TripStrings.joinDots([
        i == 1 ? TripStringsMcdA3.toPlace(cl.toName) : TripStringsMcaA3.fromTo(cl.fromName, cl.toName),
        if (pickup != null && pickup.isNotEmpty) TripStrings.pickupAt(TripFormat.time12(pickup)),
        if (fare != null && fare > 0) BrowseItem.inr(fare),
        if (booking == null) _carState(cl),
      ]),
      actionLabel: phone == null ? null : TripStrings.call,
      onAction: phone == null ? null : () => ContactLauncher.call(phone),
    );
  }

  List<Widget> _travelDayRows(TripPlanController c, int n) {
    final k = c.legIndexOf(n);
    final plan = c.plan.value;
    final leg = plan?.legAt(k);
    if (leg == null) return const [];
    final prev = plan?.legAt(k - 1);
    final to = c.cityNameOf(n);
    final a = leg.arrival;
    final from = (prev?.cityName ?? '').isNotEmpty ? prev!.cityName : (a?.fromName ?? '');
    final state = c.travelStateOf(k);
    final warn = state == TripTravelState.dateChanged ||
        state == TripTravelState.carMissing ||
        state == TripTravelState.driverUnavailable;
    final out = <Widget>[
      _caps(TripStringsMcdA3.travelDayCaps),
      if (from.isNotEmpty)
        Text(
          TripStringsMcaA3.fromTo(from, to),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(13.5, FontWeight.w700, DesignColors.textInverse),
        ),
    ];
    final j = a != null ? c.segmentJourney(k) : null;
    if (a == null) {
      out.add(_Row(
        icon: TravelIcon.route,
        accent: DesignColors.error,
        surface: TripEntryStyle.roseTint,
        title: TripStringsMcaA3.travelTo(to),
        subtitle: TripStringsMcaA3.notPlannedYet,
      ));
    } else if (j == null) {
      out.add(_Row(
        icon: TravelIcon.route,
        accent: DesignColors.error,
        surface: TripEntryStyle.roseTint,
        title: TripStringsMcaA3.travelTo(to),
        subtitle: TripStringsMcbA1.stateLabel(state),
      ));
    } else {
      for (var i = 0; i < j.legs.length; i++) {
        out.add(_carRow(j.legs[i], i + 1, c.carBooking(k, i + 1)));
      }
      final paused = j.legs.where((l) => !l.driverAvailable).firstOrNull;
      if (paused != null) out.add(_amberLine(TripStringsStepsA3.pausedBackup(paused.driverName, paused.backupName)));
    }
    if (warn) out.add(_amberLine(TripStringsMcbA1.stateLabel(state)));
    return out;
  }

  List<Widget> _checkOutRow(TripPlanController c, int n) {
    if (n < 2) return const [];
    final e = c.todayStay(n - 1);
    final String name;
    final String? phone;
    if (e != null) {
      name = e.listingName.isEmpty ? TripStrings.stay : e.listingName;
      phone = stayPhone(e);
    } else {
      return const [];
    }
    return [
      _Row(
        icon: TravelIcon.checkout,
        accent: DesignColors.statusAttention,
        surface: TripEntryStyle.sunriseTint,
        title: TripStringsMcdA3.checkOut(name),
        subtitle: '',
        actionLabel: phone == null ? null : TripStrings.call,
        onAction: phone == null ? null : () => ContactLauncher.call(phone!),
      ),
    ];
  }

  List<Widget> _stayRow(TripPlanController c, int n, {bool travelDay = false}) {
    final city = c.isMultiCity ? c.cityNameOf(n) : '';
    final e = c.todayStay(n);
    if (e != null) {
      final room = e.acceptedOffer?.lines.firstOrNull?.roomName ?? '';
      final night = _nightOf(e);
      final sub = [
        if (city.isNotEmpty) city,
        if (room.isNotEmpty) room,
        TripStringsA5.nightOf(night.k, night.total, (e.agreedTotal ?? 0) <= 0 ? null : BrowseItem.inr(e.agreedTotal!)),
        e.isConfirmedByBoth ? TripStringsV2Plan.confirmedShort : TripStringsV2Plan.bookedByYouHost,
      ].join(' · ');
      final stayName = e.listingName.isEmpty ? TripStrings.stay : e.listingName;
      return [
        _Row(
          icon: TravelIcon.stay,
          accent: DesignColors.statusAttention,
          surface: TripEntryStyle.sunriseTint,
          title: travelDay ? TripStringsMcdA3.tonightTitle(stayName) : stayName,
          subtitle: '$sub\n${_checkOutLine(night.checkOut)}',
          actionLabel: stayPhone(e) == null ? null : TripStrings.call,
          onAction: () => ContactLauncher.call(stayPhone(e)!),
        ),
      ];
    }
    return const [];
  }

  List<Widget> _taxiRow(TripPlanController c, int n) {
    final e = c.todayTaxi(n);
    if (e != null) {
      final pickup = e.taxi?.pickupTime;
      final hasPickup = pickup != null && pickup.isNotEmpty;
      final sub = [
        if (hasPickup && e.listingName.isNotEmpty) e.listingName,
        e.isConfirmedByBoth ? TripStringsV2Plan.confirmedShort : TripStringsV2Plan.bookedByYouDriver,
      ].join(' · ');
      final phone = _validPhone(e.owner.phone);
      return [
        _Row(
          icon: TravelIcon.taxi,
          accent: DesignColors.error,
          surface: TripEntryStyle.roseTint,
          title: pickup != null && pickup.isNotEmpty
              ? TripStrings.pickupAt(TripFormat.time12(pickup))
              : (e.listingName.isEmpty ? TripStrings.driver : e.listingName),
          subtitle: sub,
          actionLabel: phone == null ? null : TripStrings.call,
          onAction: phone == null ? null : () => ContactLauncher.call(phone),
        ),
      ];
    }
    return const [];
  }

  List<Widget> _routeRow(TripPlanController c, int n, bool offline, {bool travelDay = false}) {
    final names = c.todaySpotNames(n);
    if (names.isEmpty && travelDay) {
      final minutes = c.plan.value?.legAt(c.legIndexOf(n))?.arrival?.roadMinutes;
      return [
        _Row(
          icon: TravelIcon.place,
          accent: DesignColors.primary,
          surface: TripEntryStyle.surface,
          title: TripStringsMcdA3.todaysRoad,
          subtitle: minutes == null ? TripStringsMcdA3.longRoad : TripStringsMcdA3.roadLine(minutes),
          actionLabel: TripStrings.map,
          onAction: () => TripNavigation.openMap(day: n),
        ),
      ];
    }
    if (names.isEmpty) return const [];
    return [
      _Row(
        icon: TravelIcon.place,
        accent: DesignColors.primary,
        surface: TripEntryStyle.surface,
        title: offline ? TripStrings.lastSavedRoute : TripStrings.todaysRoute,
        subtitle: names.join(' · '),
        actionLabel: TripStrings.map,
        onAction: () => TripNavigation.openMap(day: n),
      ),
    ];
  }

  Widget _problemButton(BuildContext context, int n) => Tap3D(
        onTap: () => TripProblemSheet.show(context, day: n),
        label: TripStrings.problemOnTrip,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.pill, boxShadow: Ink3D.whiteBtn),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 17, color: DesignColors.error),
              const SizedBox(width: 6),
              Flexible(
                child: Text(TripStrings.problemOnTrip,
                    maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, DesignColors.error)),
              ),
            ],
          ),
        ),
      );
}

String _artOf(String icon) {
  if (icon == TravelIcon.stay) return ListingArt.hotel;
  if (icon == TravelIcon.taxi) return ListingArt.taxi;
  if (icon == TravelIcon.place) return ListingArt.roundPushpin;
  if (icon == TravelIcon.checkout) return ListingArt.key;
  return ListingArt.compass;
}

ListingTone _toneOf(String icon) {
  if (icon == TravelIcon.stay || icon == TravelIcon.checkout) return ListingTone.forest;
  if (icon == TravelIcon.taxi || icon == TravelIcon.route) return ListingTone.coral;
  return ListingTone.indigo;
}

class _TodayTile extends StatelessWidget {
  const _TodayTile({required this.art, required this.title, required this.subtitle, this.trailing});

  final String art;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Art3D(asset: art, size: 42, shadowBlur: 3, shadowOffset: const Offset(2, 3))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final Color accent;
  final Color surface;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tone = _toneOf(icon);
    return _TodayTile(
      art: _artOf(icon),
      title: title,
      subtitle: subtitle,
      trailing: actionLabel != null && onAction != null
          ? GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 38, fontSize: 13.5, expand: false)
          : null,
    );
  }
}

class _TravelRow extends StatelessWidget {
  const _TravelRow({required this.title, required this.subtitle, this.onCall});

  final String title;
  final String subtitle;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return _TodayTile(
      art: ListingArt.taxi,
      title: title,
      subtitle: subtitle,
      trailing: onCall == null
          ? null
          : GradientPillButton(tone: ListingTone.coral, label: TripStringsStepsA3.call, onTap: onCall, height: 38, fontSize: 13.5, expand: false),
    );
  }
}
