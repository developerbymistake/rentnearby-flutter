import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/taxi_option_sets.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../utils/trip_travel_rules.dart';
import 'trip_taxi_booking_sheet.dart';

class TripJourneyStrip extends StatelessWidget {
  const TripJourneyStrip({super.key, required this.legIndex, this.dense = false});

  final int legIndex;
  final bool dense;

  static const List<Color> _carColors = [TaxiColors.accentDark, TripStatusColors.booked, TripColors.accentDark];

  static Color carColor(int i) => _carColors[i % _carColors.length];

  static String driverOf(String name) => name.trim().isEmpty ? TripStringsMcbA2.driverFallback : name.trim();

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
    return [j.fromName, for (var i = 1; i < j.legs.length; i++) j.legs[i].changePlace, j.toName];
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.trip.value;
      c.plan.value;
      c.enquiryList.length;
      final j = c.segmentJourney(legIndex);
      if (j == null || j.legs.isEmpty) return const SizedBox.shrink();
      if (dense) return _ribbon(j);
      final rows = c.segmentRows(legIndex);
      final day = c.plan.value?.legStart(legIndex) ?? 1;
      final dateOk = c.travelStateOf(legIndex) != TripTravelState.dateChanged;
      final canAct = !c.isReadOnly && !c.needsUpdate.value && c.canEditDay(day) && dateOk;
      final total = totalOf(j);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _places(j),
          for (final l in j.legs) ...[
            const SizedBox(height: 8),
            _car(context, j, l, rows, canAct),
          ],
          if (total != null) ...[
            const SizedBox(height: 8),
            Text(
              TripStringsMcbA2.about(BrowseItem.inr(total)),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium),
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
      if (i > 0) spans.add(const TextSpan(text: ' → ', style: TextStyle(color: AppColors.textHint)));
      spans.add(TextSpan(text: nodes[i]));
      if (i > 0 && i < nodes.length - 1) {
        spans.add(const TextSpan(
          text: ' · ${TripStringsMcbA2.changeCar}',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.warningText),
        ));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
    );
  }

  Widget _ribbon(TripJourney j) {
    final nodes = nodesOf(j);
    final legs = j.legs;
    return LayoutBuilder(builder: (context, box) {
      const stop = 64.0;
      final fits = legs.length <= 3 && box.maxWidth >= nodes.length * stop + legs.length * 52;
      return fits ? _ribbonRow(nodes, legs, stop) : _ribbonColumn(nodes, legs);
    });
  }

  Widget _ribbonRow(List<String> nodes, List<TripJourneyLeg> legs, double stop) {
    final children = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final change = i > 0 && i < nodes.length - 1;
      children.add(SizedBox(width: stop, child: _stop(nodes[i], change)));
      if (i < legs.length) children.add(Expanded(child: _segment(legs[i], i)));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
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
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          if (change)
            const Text(
              TripStringsMcbA2.changeCar,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.warningText),
            ),
        ],
      );

  Widget _dot(bool change) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: change ? Colors.white : TaxiColors.accentDark,
          border: change ? Border.all(color: TripStatusColors.waiting, width: 3) : null,
        ),
      );

  Widget _segment(TripJourneyLeg l, int i) {
    final color = l.driverAvailable ? carColor(i) : TripStatusColors.waiting;
    final fare = fareOf(l);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 3),
          if (fare != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                BrowseItem.inr(fare),
                maxLines: 1,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
            ),
          Text(
            firstName(l.driverName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _ribbonColumn(List<String> nodes, List<TripJourneyLeg> legs) {
    final rows = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final change = i > 0 && i < nodes.length - 1;
      rows.add(Row(children: [
        SizedBox(width: 20, child: Center(child: _dot(change))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            change ? '${nodes[i]} · ${TripStringsMcbA2.changeCar}' : nodes[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: change ? AppColors.warningText : AppColors.textDark,
            ),
          ),
        ),
      ]));
      if (i < legs.length) {
        final l = legs[i];
        final fare = fareOf(l);
        rows.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 20,
              child: Center(
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: l.driverAvailable ? carColor(i) : TripStatusColors.waiting,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  [if (fare != null) BrowseItem.inr(fare), firstName(l.driverName)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                ),
              ),
            ),
          ]),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows);
  }

  static TripEnquiryModel? _askRow(TripJourneyLeg l, List<TripEnquiryModel> rows) {
    TripEnquiryModel? pick;
    for (final e in rows) {
      if (e.context.journeyLegIndex != l.legIndex || TripTravelRules.isRedRow(e) || !TripTravelRules.isLive(e)) continue;
      if (l.taxiId != null && e.listingId == l.taxiId) return e;
      pick ??= e;
    }
    return pick;
  }

  Widget _car(BuildContext context, TripJourney j, TripJourneyLeg l, List<TripEnquiryModel> rows, bool canAct) {
    final car = l.legIndex;
    final booking = TripTravelRules.carBooking(car, rows);
    final confirmed = booking?.status == TripEnquiryStatuses.confirmedByBoth;
    final missing = TripTravelRules.carMissing(j, car, rows);
    final paused = !l.driverAvailable;
    final (String pill, Color tone, Color fill) = confirmed
        ? (TripStringsMcbA2.confirmed, TripStatusColors.both, TripStatusColors.bothSurface)
        : booking != null
            ? (TripStringsMcbA2.bookedByYou, TripStatusColors.booked, TripStatusColors.bookedSurface)
            : missing
                ? (TripStringsMcbA2.noDriver, TripStatusColors.failed, TripStatusColors.failedSurface)
                : paused
                    ? (TripStringsMcbA2.paused, AppColors.warningText, TripStatusColors.waitingSurface)
                    : l.lastKnownStatus == TripTravelRules.freeStatus
                        ? (TripStringsMcbA2.free, AppColors.warningText, TripStatusColors.waitingSurface)
                        : l.isAsked
                            ? (TripStringsMcbA2.waiting, AppColors.warningText, TripStatusColors.waitingSurface)
                            : (TripStringsMcbA2.notAsked, AppColors.textLight, AppColors.divider);
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
    final driverLine = [driverOf(l.driverName), if (l.vehicleTypeName != null) l.vehicleTypeName!].join(' · ');
    final canBook = canAct && booking == null && !missing && l.taxiId != null;
    String? alert;
    Color alertColor = AppColors.warningText;
    if (missing) {
      alert = TripStringsMcbA2.carNoDriver(car);
      alertColor = TripStatusColors.failed;
    } else if (paused && booking != null) {
      alert = TripStringsMcbA2.driverPaused;
    } else if (paused) {
      final backup = l.backupName;
      alert = backup != null && backup.isNotEmpty ? TripStringsMcbA2.replaceWith(backup) : TripStringsMcbA2.driversUnavailable(1);
      alertColor = TripStatusColors.failed;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 34,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(color: carColor(car - 1), borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(
                  TripStringsMcbA2.carTo(car, l.toName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                Text(
                  driverLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                ),
                if (fareText != null)
                  Text(
                    fareText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMedium),
                  ),
              ]),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 112), child: _pill(pill, tone, fill)),
          ]),
          if (alert != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => TripNavigation.openJourney(j.id),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Iconsax.warning_2, size: 14, color: alertColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alert,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: alertColor),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          if (phone != null || canBook) ...[
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, box) {
              final call = phone == null
                  ? null
                  : OutlinedButton.icon(
                      onPressed: () => ContactLauncher.call(phone),
                      icon: const Icon(Iconsax.call, size: 16, color: TaxiColors.accentDark),
                      label: const Text(TripStringsMcbA2.call,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        side: const BorderSide(color: AppColors.divider, width: 1.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      ),
                    );
              final book = !canBook
                  ? null
                  : ElevatedButton(
                      onPressed: () => TripTaxiBookingSheet.showForJourneyCar(
                        context,
                        legIndex: legIndex,
                        journeyId: j.id,
                        carIndex: car,
                        car: l,
                        enquiry: _askRow(l, rows),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TripStatusColors.booked,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      ),
                      child: const Text(TripStringsMcbA2.iBooked,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700)),
                    );
              final buttons = [?call, ?book];
              if (buttons.length == 1) return buttons.first;
              if (box.maxWidth < 220) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [buttons[0], const SizedBox(height: 8), buttons[1]]);
              }
              return Row(children: [Expanded(child: buttons[0]), const SizedBox(width: 8), Expanded(child: buttons[1])]);
            }),
          ],
        ],
      ),
    );
  }

  static String? _phoneOf(String? a, String? b, String? c) {
    for (final p in [a, b, c]) {
      if (p != null && ContactLauncher.tenDigits(p).isNotEmpty) return p;
    }
    return null;
  }

  static Widget _pill(String text, Color tone, Color fill) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: tone),
        ),
      );
}
