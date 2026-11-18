import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_status.dart';
import 'taxi_driver_card.dart';

class TaxiRatingCard extends StatelessWidget {
  const TaxiRatingCard({super.key, required this.driver, required this.stars, required this.onStar});

  final TaxiDriverCard? driver;
  final int stars;
  final ValueChanged<int> onStar;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    return Container(
      key: const ValueKey('taxi_rating_card'),
      padding: DS.sym(h: 16, v: 18),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.hero), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Column(
        children: [
          Text(TripStringsTaxiStatus.rateTitle, textAlign: TextAlign.center, style: Ink3D.text(20, FontWeight.w700, Ink3D.title)),
          if (d != null) ...[
            Gap.v(12),
            TaxiDriverIdentity(driver: d, showRating: false),
          ],
          Gap.v(16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DS.gh(8),
            children: [
              for (var i = 1; i <= 5; i++)
                Tap3D(
                  tapKey: ValueKey('rate_star_$i'),
                  label: '$i',
                  onTap: () => onStar(i),
                  child: Icon(Icons.star_rounded, size: DS.s(44), color: i <= stars ? DesignColors.amber : DesignColors.chipBackground),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
