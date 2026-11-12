import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../../models/browse_item.dart';
import '../../../../models/card_fact.dart';
import '../../guest/taxi_navigation.dart';
import '../../models/taxi_browse_item.dart';
import '../../taxi_option_sets.dart' show TaxiOptionSets;
import '../taxi_ways_strings.dart';

class LocalTaxiRailCard extends StatelessWidget {
  static const EdgeInsets cellPadding = EdgeInsets.only(top: 4, bottom: 20);
  static const double baseHeight = RailCard.height + 24;

  final TaxiBrowseItem item;
  final double width;

  const LocalTaxiRailCard({super.key, required this.item, this.width = RailCard.width});

  static double heightFor(BuildContext context) => baseHeight;

  @override
  Widget build(BuildContext context) {
    final rate = item.localDayRate;
    final seats = item.seats;
    final facts = <CardFact>[
      if (item.vehicleTypeName.isNotEmpty) CardFact(item.vehicleTypeName),
      if (seats != null) CardFact('${TaxiOptionSets.seatsLabel(seats)} seats'),
    ];
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);
    return Padding(
      padding: cellPadding,
      child: SizedBox(
        width: width,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: RailCard(
            tone: KitTone.taxi,
            fallbackAsset: TravelIcon.taxi,
            tagLabel: TaxiWaysStrings.localTag,
            title: item.driverName,
            facts: facts,
            priceValue: rate == null ? '' : BrowseItem.inr(rate),
            priceUnit: rate == null ? '' : ' / day',
            noPriceLabel: TaxiWaysStrings.viewAndCall,
            trailing: rate == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(TaxiWaysStrings.viewAndCall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(12, FontWeight.w700, color: KitTone.taxi.accentDark)),
                  ),
            onTap: () => TaxiNavigation.openDetail(item.id),
          ),
        ),
      ),
    );
  }
}
