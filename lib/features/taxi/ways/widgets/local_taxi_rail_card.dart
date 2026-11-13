import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../../models/browse_item.dart';
import '../../guest/taxi_navigation.dart';
import '../../models/taxi_browse_item.dart';
import '../../taxi_option_sets.dart' show TaxiOptionSets;
import '../taxi_ways_strings.dart';

class LocalTaxiRailCard extends StatelessWidget {
  static const EdgeInsets cellPadding = JourneyRailCard3D.cellPadding;
  static const double baseHeight = 300;

  final TaxiBrowseItem item;
  final double width;
  final int index;

  const LocalTaxiRailCard({super.key, required this.item, this.width = 160, this.index = 0});

  static double heightFor(BuildContext context) => JourneyRailCard3D.heightFor(context);

  @override
  Widget build(BuildContext context) {
    final rate = item.localDayRate;
    final seats = item.seats;
    final facts = [
      if (item.vehicleTypeName.isNotEmpty) item.vehicleTypeName,
      if (seats != null) '${TaxiOptionSets.seatsLabel(seats)} seats',
    ].join(' · ');
    return JourneyRailCard3D(
      tone: ListingTone.list(ListingTone.coral, index),
      art: JourneyArt.forVehicle(item.vehicleTypeName, seats),
      title: item.driverName,
      lines: [TaxiWaysStrings.localTag, if (facts.isNotEmpty) facts],
      number: rate == null ? null : BrowseItem.inr(rate),
      unit: rate == null ? '' : ' /day',
      buttonLabel: TaxiWaysStrings.viewAndCall,
      width: width,
      onTap: () => TaxiNavigation.openDetail(item.id),
    );
  }
}
