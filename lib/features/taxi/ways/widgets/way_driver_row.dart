import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../../models/browse_item.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../../../trip/trip_strings_algo_aa.dart';
import '../../../trip/trip_strings_steps_a3.dart';
import '../../../trip/trip_strings_shortlist.dart';

class WayDriverRow extends StatelessWidget {
  final WayDriver driver;
  final int people;
  final String? bestReason;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final bool callBusy;
  final VoidCallback? onUse;
  final bool useBusy;
  final VoidCallback? onShortlist;
  final bool shortlisted;
  final bool shortlistBusy;
  final bool noReply;
  final String? startName;
  final ListingTone? tone;

  const WayDriverRow({
    super.key,
    required this.driver,
    required this.onTap,
    this.people = 1,
    this.bestReason,
    this.onCall,
    this.callBusy = false,
    this.onUse,
    this.useBusy = false,
    this.onShortlist,
    this.shortlisted = false,
    this.shortlistBusy = false,
    this.noReply = false,
    this.startName,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final from = (startName != null && startName!.isNotEmpty) ? startName! : d.fromName;
    final to = d.toName;
    final vehicle = d.vehicleCategory != null ? TaxiOptionSets.categoryLabel(d.vehicleCategory) : d.vehicleTypeName;
    final best = bestReason != null;
    final cars = d.carsFor(people);
    final price = BrowseItem.inr(d.groupFare(people));
    final routeFrom = (d.routeFromName ?? '').isNotEmpty ? d.routeFromName! : d.fromName;
    final routeTo = (d.routeToName ?? '').isNotEmpty ? d.routeToName! : d.toName;
    final base = d.basedHere ? _basedHere : TripStringsShortlist.basedIn((d.cityName ?? '').isNotEmpty ? d.cityName! : routeFrom);
    return WideCard(
      tone: tone ?? ListingTone.cA,
      art: ListingArt.forVehicle(vehicle),
      tag: [_tag, if (noReply) TripStringsShortlist.noReply, if (best) TaxiWaysStrings.bestWay, if (d.isFeatured) _featured].map((e) => e.replaceAll(' ', ' ')).join(' · '),
      title: d.driverName,
      subtitleSlots: const [2, 2],
      subtitle: [
        d.isOnTheWay ? TaxiWaysStrings.going(routeFrom, routeTo) : TaxiWaysStrings.subtitle(from, to),
        [
          vehicle,
          if (d.repliesInApp) TaxiWaysStrings.repliesInApp,
          base,
          if (d.meetAtName != null && d.meetAtName!.isNotEmpty) TripStringsShortlist.startsAt(d.meetAtName!),
        ].join(' · '),
      ].join('\n'),
      number: price,
      unit: [TaxiWaysStrings.toPlace(to), if (d.isEstimate) TaxiWaysStrings.estimateShort, if (cars > 1) TripStringsAlgoAa.cars(cars)].where((e) => e.isNotEmpty).join(' · '),
      label: bestReason,
      actions: [
        if (onCall != null) WideAction(icon: Icons.call_rounded, label: TaxiWaysStrings.call, onTap: onCall, busy: callBusy),
        if (onShortlist != null)
          WideAction(
            icon: shortlisted ? Icons.check_rounded : Icons.add_rounded,
            label: shortlisted ? TripStringsShortlist.shortlisted : TripStringsShortlist.shortlist,
            onTap: onShortlist,
            selected: shortlisted,
            busy: shortlistBusy,
          )
        else if (onUse != null)
          WideAction(icon: Icons.bookmark_add_outlined, label: TripStringsStepsA3.useForMyTrip, onTap: onUse, busy: useBusy),
      ],
      picked: shortlisted,
      onTap: onTap,
    );
  }

  static const String _tag = 'Taxi';
  static const String _basedHere = 'Based here';
  static const String _featured = 'Featured';
}
