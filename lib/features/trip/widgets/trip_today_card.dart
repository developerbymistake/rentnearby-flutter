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

const _accent = DesignColors.lunchEnd;

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
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: DesignColors.surface,
            borderRadius: CardRadius.tile,
            boxShadow: ShadowTokens.elev2,
          ),
          child: ClipRRect(
            borderRadius: CardRadius.tile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TemplateEntranceOnce(
                    index: 0,
                    count: 6,
                    child: Text(
                    today == null
                        ? (journey == null ? TripStringsFinB1.checkOutDay : TripStringsStepsA3.travelDay(_todayDate))
                        : !c.isMultiCity
                            ? TripStrings.todayDay(n, c.dayCount)
                            : travelDay
                                ? TripStringsMcdA3.todayTravelDay(n, c.dayCount)
                                : TripStringsMcdA3.todayDayCity(n, c.dayCount, c.cityNameOf(n)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 15, fontWeight: FontWeight.w700, color: _accent),
                  ),
                  ),
                  if (offline) ...[
                    const SizedBox(height: 8),
                    _offlineBanner(),
                  ],
                  for (var i = 0; i < rows.length; i++) ...[
                    const SizedBox(height: 8),
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
        ),
      );
    });
  }

  Widget _offlineBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: DesignColors.scaffold, borderRadius: CardRadius.chip),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 15, color: DesignColors.textGrey),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                TripStrings.offlineSaved,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: DesignColors.textGrey),
              ),
            ),
          ],
        ),
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
    final wa = _validPhone(leg.whatsApp);
    final head = j.role == TripStepRole.comingBack ? TripStringsStepsA3.todayComingBack : TripStringsStepsA3.todayGettingThere;
    final paused = legs.where((l) => !l.driverAvailable).firstOrNull;
    return [
      Text(
        head,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: DesignColors.textSecondary),
      ),
      _TravelRow(
        title: multi ? TripStringsStepsA3.changeCarAt(leg.changePlace) : TripStringsStepsA3.takesYou(leg.driverName, j.toName),
        subtitle: multi
            ? TripStringsStepsA3.nextDriver(leg.driverName)
            : [leg.vehicleTypeName, leg.plateDisplay].where((e) => e != null && e.isNotEmpty).join(' · '),
        onCall: phone == null ? null : () => ContactLauncher.call(phone),
        onWhatsApp: wa == null ? null : () => ContactLauncher.whatsApp(wa),
      ),
      if (paused != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: TripEntryStyle.sunriseTint, borderRadius: CardRadius.chip),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: DesignColors.textGreyDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                TripStringsStepsA3.pausedBackup(paused.driverName, paused.backupName),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: DesignColors.textGreyDark),
              ),
            ),
          ]),
        ),
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

  static Widget _caps(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: DesignColors.textSecondary),
      );

  static Widget _amberLine(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: TripEntryStyle.sunriseTint, borderRadius: CardRadius.chip),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 15, color: DesignColors.textGreyDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: DesignColors.textGreyDark),
            ),
          ),
        ]),
      );

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
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.textStrong),
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
          accent: _accent,
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
        accent: _accent,
        surface: TripEntryStyle.surface,
        title: offline ? TripStrings.lastSavedRoute : TripStrings.todaysRoute,
        subtitle: names.join(' · '),
        actionLabel: TripStrings.map,
        onAction: () => TripNavigation.openMap(day: n),
      ),
    ];
  }

  Widget _problemButton(BuildContext context, int n) => _pill(
          onTap: () => TripProblemSheet.show(context, day: n),
          minHeight: 48,
          fill: TripEntryStyle.roseTint,
          border: const BorderSide(color: DesignColors.error, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: DesignColors.error),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  TripStrings.problemOnTrip,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.error),
                ),
              ),
            ],
          ),
        );
}

Widget _pill({
  required VoidCallback onTap,
  required Widget child,
  required double minHeight,
  required BorderSide border,
  required EdgeInsets padding,
  Color? fill,
}) =>
    Material(
      color: fill ?? DesignColors.surface,
      shape: RoundedRectangleBorder(borderRadius: CardRadius.chip, side: border),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(padding: padding, child: Center(child: child)),
        ),
      ),
    );

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            boxShadow: ShadowTokens.elev1,
          ),
          child: Center(child: TravelIcon(icon, size: 26)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.textStrong),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: DesignColors.textSecondary),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Text(
              actionLabel!,
              maxLines: 1,
              style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w700, color: _accent),
            ),
          ),
      ],
    );
  }
}

class _TravelRow extends StatelessWidget {
  const _TravelRow({required this.title, required this.subtitle, this.onCall, this.onWhatsApp});

  final String title;
  final String subtitle;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      if (onCall != null) _button(TripStringsStepsA3.call, const Icon(Icons.call_rounded, size: 16, color: _accent), _accent, onCall!),
      if (onWhatsApp != null) _button(TripStringsStepsA3.whatsApp, const TravelIcon(TravelIcon.chat, size: 18), DesignColors.primary, onWhatsApp!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignColors.error,
                shape: BoxShape.circle,
                boxShadow: ShadowTokens.elev1,
              ),
              child: const TravelIcon(TravelIcon.route, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.textStrong),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: DesignColors.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, box) {
            if (buttons.length == 1) return buttons.first;
            if (box.maxWidth < 220) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [buttons[0], const SizedBox(height: 8), buttons[1]],
              );
            }
            return Row(children: [Expanded(child: buttons[0]), const SizedBox(width: 8), Expanded(child: buttons[1])]);
          }),
        ],
      ],
    );
  }

  static Widget _button(String label, Widget icon, Color color, VoidCallback onTap) => _pill(
        onTap: onTap,
        minHeight: 44,
        border: const BorderSide(color: TripEntryStyle.border, width: 1.3),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      );
}
