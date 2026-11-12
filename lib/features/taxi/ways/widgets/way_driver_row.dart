import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../../models/browse_item.dart';
import '../../../../models/card_fact.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../../../trip/trip_strings_algo_aa.dart';
import '../../../trip/trip_strings_steps_a3.dart';
import '../../../trip/trip_strings_shortlist.dart';
import '../../../trip/widgets/trip_shortlist_toggle.dart';
import 'best_way_mark.dart';

class WayDriverRow extends StatelessWidget {
  static const String finalFareNote = 'Driver confirms the final fare';

  final WayDriver driver;
  final int people;
  final String? bestReason;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onUse;
  final bool useBusy;
  final VoidCallback? onShortlist;
  final bool shortlisted;
  final bool shortlistBusy;
  final bool noReply;

  const WayDriverRow({
    super.key,
    required this.driver,
    required this.onTap,
    this.people = 1,
    this.bestReason,
    this.onCall,
    this.onUse,
    this.useBusy = false,
    this.onShortlist,
    this.shortlisted = false,
    this.shortlistBusy = false,
    this.noReply = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final from = d.reversed ? d.toName : d.fromName;
    final to = d.reversed ? d.fromName : d.toName;
    final vehicle = d.vehicleCategory != null ? TaxiOptionSets.categoryLabel(d.vehicleCategory) : d.vehicleTypeName;
    final best = bestReason != null;
    final cars = d.carsFor(people);
    final price = BrowseItem.inr(d.groupFare(people));
    final card = DriverOptionCard(
      name: d.driverName,
      vehicle: TaxiWaysStrings.subtitle(from, to),
      subtitle: [
        vehicle,
        if (d.repliesInApp) TaxiWaysStrings.repliesInApp,
        if (d.meetAtName != null && d.meetAtName!.isNotEmpty) TripStringsShortlist.startsAt(d.meetAtName!),
      ].join(' · '),
      facts: [
        if (noReply) CardFact(TripStringsShortlist.noReply, tone: FactTone.accent),
        CardFact(
          cars > 1 ? TripStringsAlgoAa.cars(cars) : (d.basedHere ? TaxiWaysStrings.basedHere : TaxiWaysStrings.oneCar),
          tone: FactTone.slate,
        ),
        if (d.basedHere || (d.meetAtName != null && d.meetAtName!.isNotEmpty))
          const CardFact(finalFareNote, tone: FactTone.slate),
      ],
      fareValue: d.isEstimate ? TripStringsAlgoAa.about(price) : price,
      onTap: onTap,
      margin: EdgeInsets.zero,
      actions: [
        if (onCall != null)
          PillAction(
            label: TaxiWaysStrings.call,
            tone: KitTone.taxi,
            icon: const Icon(Icons.call_rounded, size: 16, color: DesignColors.primary),
            onTap: onCall,
          ),
        if (onShortlist != null)
          TripShortlistToggle(selected: shortlisted, busy: shortlistBusy, onTap: onShortlist, tone: KitTone.taxi)
        else if (onUse != null)
          PrimaryButton(
            label: TripStringsStepsA3.useForMyTrip,
            onPressed: useBusy ? null : onUse,
            loading: useBusy,
            tone: KitTone.taxi,
            expand: false,
            height: 44,
          ),
      ],
    );
    if (!best) return card;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: BestWayMark(reason: bestReason!)),
      Stack(children: [
        card,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: CardRadius.tile,
                border: Border.all(color: KitTone.taxi.accent, width: 2),
              ),
            ),
          ),
        ),
      ]),
    ]);
  }
}
