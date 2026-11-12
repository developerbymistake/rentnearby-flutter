import 'trip_ui.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/ways/trip_strings_journey_card.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../utils/trip_travel_rules.dart';
import 'trip_journey_card.dart';
import 'trip_taxi_booking_sheet.dart';

class TripJourneyStrip extends StatelessWidget {
  const TripJourneyStrip({
    super.key,
    this.legIndex,
    this.role,
    this.dense = false,
  }) : assert((legIndex == null) != (role == null));

  final int? legIndex;
  final TripStepRole? role;
  final bool dense;

  static const List<Color> _carColors = [
    TripUi.taxiDark,
    TripUi.tripDark,
    TripUi.tripDark,
  ];

  static Color carColor(int i) => _carColors[i % _carColors.length];

  static String driverOf(String name) =>
      name.trim().isEmpty ? TripStringsMcbA2.driverFallback : name.trim();

  static String firstName(String name) {
    final t = driverOf(name);
    final i = t.indexOf(' ');
    return i > 0 ? t.substring(0, i) : t;
  }

  static int? fareOf(TripJourneyLeg l) {
    final q = l.lastQuotedFare;
    if (q != null && q > 0) return q;
    final f = l.listedFare;
    return f != null && f > 0 ? f : null;
  }

  static int? totalOf(TripJourney j) {
    final t = j.listedTotal;
    if (t != null && t > 0) return t;
    final sum = j.legs.fold<int>(0, (a, l) => a + (l.listedFare ?? 0));
    return sum > 0 ? sum : null;
  }

  static List<String> nodesOf(TripJourney j) {
    final p = j.places;
    if (p.length == j.legs.length + 1) return p;
    return [
      j.fromName,
      for (var i = 1; i < j.legs.length; i++) j.legs[i].changePlace,
      j.toName,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.trip.value;
      c.plan.value;
      c.enquiryList.length;
      final j = TripJourneyCard.journeyOf(c, role: role, legIndex: legIndex);
      if (j == null || j.legs.isEmpty) return const SizedBox.shrink();
      if (dense) return _ribbon(j);
      final rows = TripJourneyCard.rowsOf(c, j, legIndex: legIndex);
      final canAct = TripJourneyCard.canActOn(
        c,
        j,
        role: role,
        legIndex: legIndex,
      );
      final k = legIndex;
      final moved =
          !c.isReadOnly &&
          !c.needsUpdate.value &&
          (k != null
              ? c.travelStateOf(k) == TripTravelState.dateChanged
              : j.dateChanged);
      final ownCars = k != null
          ? (c.plan.value?.legAt(k)?.arrival?.ownCars ?? const <int>[])
          : (role == null ? const <int>[] : c.stepOf(role!).ownCars);
      final lines = TripTravelRules.carLines(j, rows, ownCars);
      final total = totalOf(j);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _places(j),
          for (final l in j.legs) ...[
            const SizedBox(height: 8),
            _car(
              context,
              j,
              l,
              rows,
              canAct,
              lines.firstWhereOrNull((x) => x.car == l.legIndex),
              moved: moved,
            ),
          ],
          if (total != null) ...[
            const SizedBox(height: 8),
            Text(
              TripStringsMcbA2.about(BrowseItem.inr(total)),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FitnessAppTheme.fontName,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FitnessAppTheme.darkText,
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _places(TripJourney j) {
    final nodes = nodesOf(j);
    final spans = <InlineSpan>[];
    for (var i = 0; i < nodes.length; i++) {
      if (i > 0)
        spans.add(
          const TextSpan(
            text: ' → ',
            style: TextStyle(
              fontFamily: FitnessAppTheme.fontName,
              color: FitnessAppTheme.deactivatedText,
            ),
          ),
        );
      spans.add(TextSpan(text: nodes[i]));
      if (i > 0 && i < nodes.length - 1) {
        spans.add(
          const TextSpan(
            text: ' · ${TripStringsMcbA2.changeCar}',
            style: TextStyle(
              fontFamily: FitnessAppTheme.fontName,
              fontWeight: FontWeight.w600,
              color: TripUi.warn,
            ),
          ),
        );
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: FitnessAppTheme.fontName,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: FitnessAppTheme.darkerText,
      ),
    );
  }

  Widget _ribbon(TripJourney j) {
    final nodes = nodesOf(j);
    final legs = j.legs;
    return LayoutBuilder(
      builder: (context, box) {
        const stop = 64.0;
        final fits =
            legs.length <= 3 &&
            box.maxWidth >= nodes.length * stop + legs.length * 52;
        return fits
            ? KitRouteReveal(child: _ribbonRow(nodes, legs, stop))
            : KitRouteReveal(axis: Axis.vertical, child: _ribbonColumn(nodes, legs));
      },
    );
  }

  Widget _ribbonRow(
    List<String> nodes,
    List<TripJourneyLeg> legs,
    double stop,
  ) {
    final children = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final change = i > 0 && i < nodes.length - 1;
      children.add(SizedBox(width: stop, child: _stop(nodes[i], change)));
      if (i < legs.length) children.add(Expanded(child: _segment(legs[i], i)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _stop(String name, bool change) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 6),
      _dot(change),
      const SizedBox(height: 4),
      Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: FitnessAppTheme.fontName,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FitnessAppTheme.darkerText,
        ),
      ),
      if (change)
        const Text(
          TripStringsMcbA2.changeCar,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: FitnessAppTheme.fontName,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TripUi.warn,
          ),
        ),
    ],
  );

  Widget _dot(bool change) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: change ? FitnessAppTheme.white : TripUi.taxiDark,
      border: change ? Border.all(color: TripUi.warn, width: 3) : null,
    ),
  );

  Widget _segment(TripJourneyLeg l, int i) {
    final color = l.driverAvailable ? carColor(i) : TripUi.warn;
    final fare = fareOf(l);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: CardRadius.pill,
            ),
          ),
          const SizedBox(height: 3),
          if (fare != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                BrowseItem.inr(fare),
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: FitnessAppTheme.darkerText,
                ),
              ),
            ),
          Text(
            firstName(l.driverName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: FitnessAppTheme.fontName,
              fontSize: 11,
              color: FitnessAppTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ribbonColumn(List<String> nodes, List<TripJourneyLeg> legs) {
    final rows = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final change = i > 0 && i < nodes.length - 1;
      rows.add(
        Row(
          children: [
            SizedBox(width: 20, child: Center(child: _dot(change))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                change
                    ? '${nodes[i]} · ${TripStringsMcbA2.changeCar}'
                    : nodes[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FitnessAppTheme.fontName,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: change ? TripUi.warn : FitnessAppTheme.darkerText,
                ),
              ),
            ),
          ],
        ),
      );
      if (i < legs.length) {
        final l = legs[i];
        final fare = fareOf(l);
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Center(
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: l.driverAvailable ? carColor(i) : TripUi.warn,
                        borderRadius: CardRadius.pill,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      [
                        if (fare != null) BrowseItem.inr(fare),
                        firstName(l.driverName),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 11,
                        color: FitnessAppTheme.lightText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  static TripEnquiryModel? _askRow(
    TripJourneyLeg l,
    List<TripEnquiryModel> rows,
  ) {
    TripEnquiryModel? pick;
    for (final e in rows) {
      if (e.context.journeyLegIndex != l.legIndex ||
          TripTravelRules.isRedRow(e) ||
          !TripTravelRules.isLive(e))
        continue;
      if (l.taxiId != null && e.listingId == l.taxiId) return e;
      pick ??= e;
    }
    return pick;
  }

  static TripCarState carStateOf(
    TripJourney j,
    TripJourneyLeg l,
    List<TripEnquiryModel> rows,
  ) {
    final booking = TripTravelRules.carBooking(l.legIndex, rows);
    if (booking?.status == TripEnquiryStatuses.confirmedByBoth)
      return TripCarState.confirmed;
    if (booking != null) return TripCarState.bookedByYou;
    if (TripTravelRules.carMissing(j, l.legIndex, rows))
      return TripCarState.notAvailable;
    if (!l.driverAvailable) return TripCarState.paused;
    if (l.lastKnownStatus == TripTravelRules.freeStatus)
      return TripCarState.free;
    return l.isAsked ? TripCarState.asked : TripCarState.notAsked;
  }

  static String carLabel(TripCarState s, {bool noReply = false}) => switch (s) {
    TripCarState.notAsked => TripStringsJourneyCard.carNotAsked,
    TripCarState.asked => TripStringsJourneyCard.carAsked,
    TripCarState.free => TripStringsJourneyCard.carFree,
    TripCarState.bookedByYou => TripStringsJourneyCard.carBookedByYou,
    TripCarState.confirmed => TripStringsJourneyCard.carConfirmed,
    TripCarState.own => TripStringsJourneyCard.carOwn,
    TripCarState.notAvailable =>
      noReply
          ? TripStringsJourneyCard.carNoReply
          : TripStringsJourneyCard.carNotAvailable,
    TripCarState.paused => TripStringsJourneyCard.carPaused,
  };

  static (Color, Color) carTone(TripCarState s) => switch (s) {
    TripCarState.confirmed => (TripUi.good, TripUi.goodTint),
    TripCarState.bookedByYou ||
    TripCarState.asked ||
    TripCarState.free ||
    TripCarState.paused => (TripUi.warn, TripUi.warnTint),
    TripCarState.notAvailable => (TripUi.bad, TripUi.badTint),
    TripCarState.own || TripCarState.notAsked => (
      FitnessAppTheme.lightText,
      FitnessAppTheme.spacer,
    ),
  };

  @visibleForTesting
  Widget carCard(BuildContext context, TripJourney j, TripJourneyLeg l, List<TripEnquiryModel> rows, bool canAct,
          {bool moved = false}) =>
      _car(context, j, l, rows, canAct, null, moved: moved);

  Widget _car(
    BuildContext context,
    TripJourney j,
    TripJourneyLeg l,
    List<TripEnquiryModel> rows,
    bool canAct,
    TripCarLine? line, {
    bool moved = false,
  }) {
    final car = l.legIndex;
    final booking = TripTravelRules.carBooking(car, rows);
    final state = line?.state ?? carStateOf(j, l, rows);
    final own = state == TripCarState.own;
    final confirmed = state == TripCarState.confirmed;
    final missing = state == TripCarState.notAvailable;
    final paused = !l.driverAvailable;
    final pill = carLabel(
      state,
      noReply:
          line?.noReply ??
          (missing && TripTravelRules.carNoReply(j, car, rows)),
    );
    final (Color tone, Color fill) = carTone(state);
    final agreed = booking?.taxi?.agreedFare;
    final String? fareText;
    if (agreed != null && agreed > 0) {
      fareText = TripStringsMcbA2.agreed(BrowseItem.inr(agreed));
    } else if (l.lastQuotedFare != null && l.lastQuotedFare! > 0) {
      fareText = TripStringsMcbA2.quoted(BrowseItem.inr(l.lastQuotedFare!));
    } else if (l.listedFare != null && l.listedFare! > 0) {
      fareText = TripStringsMcbA2.listed(BrowseItem.inr(l.listedFare!));
    } else {
      fareText = null;
    }
    final phone = _phoneOf(booking?.owner.phone, l.phone, l.whatsApp);
    final driverLine = [
      driverOf(l.driverName),
      if (l.vehicleTypeName != null) l.vehicleTypeName!,
    ].join(' · ');
    final canBook =
        canAct && booking == null && !missing && !own && l.taxiId != null;
    final backup = l.backupName;
    final exits = canAct && !own && !confirmed;
    String? alert;
    Color alertColor = TripUi.warn;
    if (own) {
      alert = null;
    } else if (missing) {
      alert = (line?.noReply ?? TripTravelRules.carNoReply(j, car, rows))
          ? TripStringsMcbA2.carNoReply(car)
          : TripStringsMcbA2.carNoDriver(car);
      alertColor = TripUi.bad;
    } else if (paused && booking != null) {
      alert = TripStringsMcbA2.driverPaused;
    } else if (paused) {
      alert = backup != null && backup.isNotEmpty
          ? TripStringsMcbA2.replaceWith(backup)
          : TripStringsMcbA2.driversUnavailable(1);
      alertColor = TripUi.bad;
    }
    final hasBody =
        alert != null ||
        phone != null ||
        canBook ||
        (moved && booking != null && !own) ||
        exits ||
        (own && canAct);
    return DriverOptionCard(
      margin: EdgeInsets.zero,
      name: TripStringsMcbA2.carTo(car, l.toName),
      vehicle: driverLine,
      subtitle: fareText,
      legColor: carColor(car - 1),
      avatarInitial: '$car',
      header: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: _pill(pill, tone, fill),
        ),
      ),
      actions: hasBody
          ? [
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (alert != null) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () =>
                            TripJourneyCard.findAnotherCar(context, j, car),
                        borderRadius: CardRadius.chip,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: TravelIcon(
                                  TravelIcon.calendar,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  alert,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: alertColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (phone != null || canBook) ...[
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, box) {
                          final call = phone == null
                              ? null
                              : SecondaryButton(
                                  label: TripStringsMcbA2.call,
                                  tone: KitTone.taxi,
                                  height: 44,
                                  onPressed: () => ContactLauncher.call(phone),
                                );
                          final book = !canBook
                              ? null
                              : PrimaryButton(
                                  label: TripStringsMcbA2.iBooked,
                                  tone: KitTone.trip,
                                  height: 44,
                                  onPressed: () =>
                                      TripTaxiBookingSheet.showForJourneyCar(
                                        context,
                                        role: role,
                                        legIndex: legIndex,
                                        journeyId: j.id,
                                        carIndex: car,
                                        car: l,
                                        enquiry: _askRow(l, rows),
                                      ),
                                );
                          final buttons = [?call, ?book];
                          if (buttons.length == 1) return buttons.first;
                          if (box.maxWidth < 220) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                buttons[0],
                                const SizedBox(height: 8),
                                buttons[1],
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: buttons[0]),
                              const SizedBox(width: 8),
                              Expanded(child: buttons[1]),
                            ],
                          );
                        },
                      ),
                    ],
                    if (moved && booking != null && !own)
                      Wrap(
                        children: [
                          _exit(
                            TripStringsJourneyCard.cancelDriverBooking(
                              firstName(l.driverName),
                            ),
                            () => TripJourneyCard.cancelCarBooking(
                              context,
                              role: role,
                              legIndex: legIndex,
                              car: car,
                            ),
                          ),
                        ],
                      ),
                    if (exits || (own && canAct))
                      Wrap(
                        spacing: 2,
                        runSpacing: 0,
                        children: [
                          if (own)
                            _exit(
                              TripStringsJourneyCard.undo,
                              () => TripJourneyCard.setCarOwn(
                                role: role,
                                legIndex: legIndex,
                                car: car,
                                own: false,
                              ),
                            )
                          else ...[
                            if (booking == null &&
                                backup != null &&
                                backup.isNotEmpty &&
                                l.backupTaxiId != null &&
                                (missing || paused))
                              _exit(
                                TripStringsJourneyCard.useBackup(
                                  firstName(backup),
                                ),
                                () => TripJourneyCard.useBackup(
                                  j,
                                  car,
                                  l.backupTaxiId!,
                                ),
                              ),
                            if (booking == null)
                              _exit(
                                TripStringsJourneyCard.findAnotherCar,
                                () => TripJourneyCard.findAnotherCar(
                                  context,
                                  j,
                                  car,
                                ),
                              ),
                            _exit(
                              TripStringsJourneyCard.arrangeCar(car),
                              () => TripJourneyCard.arrangeCar(
                                context,
                                role: role,
                                legIndex: legIndex,
                                car: car,
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ]
          : const [],
    );
  }

  static Widget _exit(String label, VoidCallback onTap) =>
      TextLink(label: label, onTap: onTap, tone: KitTone.trip);

  static String? _phoneOf(String? a, String? b, String? c) {
    for (final p in [a, b, c]) {
      if (p != null && ContactLauncher.tenDigits(p).isNotEmpty) return p;
    }
    return null;
  }

  static Widget _pill(String text, Color tone, Color fill) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: fill, borderRadius: CardRadius.pill),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: FitnessAppTheme.fontName,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: tone,
      ),
    ),
  );
}
