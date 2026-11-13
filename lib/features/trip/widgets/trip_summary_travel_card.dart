import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
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
import 'trip_status.dart';
import 'trip_summary_booking_card.dart';

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
    final cars = !t.isOwn && t.cars.isNotEmpty;
    return TripSummaryBookingCard(
      tone: ListingTone.coral,
      art: ListingArt.taxi,
      eyebrow: date.isEmpty ? TripStringsMcdA3.travelHeadFallback : TripStringsMcdA3.travelLine(date),
      title: head,
      subtitle: route,
      pill: TripSummaryBookingCard.statusPill(status, taxi: true, label: pillLabel),
      rows: cars ? [for (final c in t.cars) _carRow(c)] : const [],
      payLine: cars ? TripStrings.taxiPayLine : null,
    );
  }

  (String, String) _carRow(TripSummaryTravelCar c) {
    final fare = c.fare;
    final word = TripSummaryText.carStatus(c);
    final name = c.driverName.isEmpty ? TripStrings.driver : c.driverName;
    final vehicle = (c.vehicleTypeName ?? '').isEmpty ? name : '$name · ${c.vehicleTypeName}';
    final pickup = (c.pickupTime ?? '').isEmpty ? null : TripStrings.pickupAt(TripFormat.time12(c.pickupTime!));
    return (
      TripStringsMcaA3.fromTo(c.fromName, c.toName),
      TripStrings.joinDots([vehicle, pickup, if (fare != null && fare > 0) BrowseItem.inr(fare), word]),
    );
  }
}
