import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import '../../../models/browse_item.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcb_a1.dart';
import '../trip_strings_mcd_a3.dart';
import '../trip_strings_steps_a3.dart';
import '../utils/trip_format.dart';
import '../utils/trip_summary_text.dart';
import '../utils/trip_travel_rules.dart';
import 'trip_payment_line.dart';
import 'trip_status.dart';
import 'trip_status_card.dart';

class TripSummaryTravelCard extends StatelessWidget {
  const TripSummaryTravelCard(this.travel, {super.key});

  final TripSummaryTravel travel;

  static TripDisplayStatus statusOf(TripSummaryTravel t) {
    if (t.isOwn) return TripDisplayStatus.own;
    return switch (t.state) {
      TripTravelState.booked => TripDisplayStatus.bookedByYou,
      TripTravelState.confirmed => TripDisplayStatus.confirmedByBoth,
      TripTravelState.asked ||
      TripTravelState.free ||
      TripTravelState.partlyBooked ||
      TripTravelState.saved =>
        TripDisplayStatus.asked,
      _ => TripDisplayStatus.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = travel;
    final status = statusOf(t);
    final pillLabel = t.isOwn ? TripStringsMcaA3.ownTravel : (t.state == null ? null : TripStringsMcbA1.stateLabel(t.state!));
    final head = t.isOwn ? TripStringsMcdA3.travelHeadOwn(t.toName) : TripStringsMcdA3.travelHead(t.toName, t.shownCars);
    final date = t.date == null ? '' : TripFormat.shortDate(t.date!);
    final route = t.isOwn ? TripStringsMcaA3.fromTo(t.fromName, t.toName) : TripStringsStepsA3.routeLine(t.places);
    return TripStatusCard(
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      head,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: TripLook.textDark),
                    ),
                    Text(
                      date.isEmpty ? TripStringsMcdA3.travelHeadFallback : TripStringsMcdA3.travelLine(date),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textMedium),
                    ),
                    Text(
                      route,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: TripStatusPill(status, taxi: true, label: pillLabel)),
            ],
          ),
          if (!t.isOwn) ..._cars(t),
        ],
      ),
    );
  }

  List<Widget> _cars(TripSummaryTravel t) {
    if (t.cars.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      for (final c in t.cars) _carRow(c),
      const SizedBox(height: 10),
      const TripPaymentLine(text: TripStrings.taxiPayLine),
    ];
  }

  Widget _carRow(TripSummaryTravelCar c) {
    final fare = c.fare;
    final word = TripSummaryText.carStatus(c);
    final name = c.driverName.isEmpty ? TripStrings.driver : c.driverName;
    final vehicle = (c.vehicleTypeName ?? '').isEmpty ? name : '$name · ${c.vehicleTypeName}';
    final pickup = (c.pickupTime ?? '').isEmpty ? null : TripStrings.pickupAt(TripFormat.time12(c.pickupTime!));
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: TripLook.textDark),
                ),
                Text(
                  TripStrings.joinDots([TripStringsMcaA3.fromTo(c.fromName, c.toName), pickup]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, color: TripLook.textLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              TripStrings.joinDots([if (fare != null && fare > 0) BrowseItem.inr(fare), word]),
              maxLines: 2,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: TripLook.textMedium),
            ),
          ),
        ],
      ),
    );
  }
}
