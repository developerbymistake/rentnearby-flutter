import 'package:flutter/material.dart';
import '../design/design.dart';
import '../features/taxi/guest/taxi_navigation.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../features/taxi/taxi_option_sets.dart';
import '../models/browse_item.dart';
import '../models/card_fact.dart';
import 'home_stay_rail_card.dart';

class HomeTaxiRailCard extends StatelessWidget {
  final TaxiBrowseItem taxi;
  final VoidCallback? onOpen;

  const HomeTaxiRailCard({super.key, required this.taxi, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = taxi;
    final facts = <CardFact>[
      if (t.vehicleTypeName.isNotEmpty) CardFact(t.vehicleTypeName),
      if (t.seats != null) CardFact('${TaxiOptionSets.seatsLabel(t.seats!)} seats'),
    ];
    final hasFare = t.minFare != null;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);
    return Padding(
      padding: HomeStayRailCard.cellPadding,
      child: SizedBox(
        width: HomeStayRailCard.cellWidth,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: RailCard(
            tone: KitTone.taxi,
            fallbackAsset: TravelIcon.taxi,
            tagLabel: 'TAXI',
            title: t.driverName,
            locationLabel: t.locality,
            facts: facts,
            isFeatured: t.isFeatured,
            priceCaption: hasFare ? 'FARE FROM' : '',
            priceValue: hasFare ? BrowseItem.inr(t.minFare!) : '',
            stackedCaption: true,
            noPriceLabel: 'LOCAL TAXI',
            onTap: onOpen ?? () => TaxiNavigation.openDetail(t.id),
          ),
        ),
      ),
    );
  }
}
