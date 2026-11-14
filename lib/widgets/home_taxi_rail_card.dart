import 'package:flutter/material.dart';
import '../design/design.dart';
import '../features/taxi/guest/taxi_navigation.dart';
import '../features/taxi/models/taxi_browse_item.dart';
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
    final base = (t.baseCityName ?? t.cityName)?.trim() ?? '';
    return MealsCardV(
      tone: ListingTone.list(ListingTone.coral, index),
      art: ListingArt.forVehicle(t.vehicleTypeName),
      tag: 'TAXI',
      starBadge: t.isFeatured,
      title: t.driverName,
      description: base,
      chips: t.vehicleTypeName.isEmpty ? null : [t.vehicleTypeName],
      caption: hasFare ? 'FARE FROM' : '',
      number: hasFare ? BrowseItem.inr(t.minFare!) : 'Local taxi',
      width: HomeStayRailCard.cellWidth,
      titleLines: 2,
      uniformSlots: true,
      onTap: onOpen ?? () => TaxiNavigation.openDetail(t.id),
    );
  }
}
