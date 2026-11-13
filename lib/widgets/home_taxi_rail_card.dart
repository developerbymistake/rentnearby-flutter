import 'package:flutter/material.dart';
import '../design/design.dart';
import '../features/taxi/guest/taxi_navigation.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../features/taxi/taxi_option_sets.dart';
import '../models/browse_item.dart';
import 'home_stay_rail_card.dart';

class HomeTaxiRailCard extends StatelessWidget {
  final TaxiBrowseItem taxi;
  final VoidCallback? onOpen;
  final int index;

  const HomeTaxiRailCard({super.key, required this.taxi, this.onOpen, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final t = taxi;
    final hasFare = t.minFare != null;
    final chips = [
      if (t.isFeatured) 'Featured',
      if (t.vehicleTypeName.isNotEmpty) t.vehicleTypeName,
      if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
    ];
    return MealsCardV(
      tone: ListingTone.list(ListingTone.coral, index),
      art: ListingArt.forVehicle(t.vehicleTypeName),
      tag: 'TAXI',
      title: t.driverName,
      description: t.locality,
      chips: chips,
      caption: hasFare ? 'FARE FROM' : '',
      number: hasFare ? BrowseItem.inr(t.minFare!) : 'Local taxi',
      width: HomeStayRailCard.cellWidth,
      titleLines: 2,
      onTap: onOpen ?? () => TaxiNavigation.openDetail(t.id),
    );
  }
}
