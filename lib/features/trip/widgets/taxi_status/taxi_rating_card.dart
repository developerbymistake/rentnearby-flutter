import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_status.dart';
import 'taxi_driver_card.dart';
import 'taxi_status_states.dart';

class TaxiRatingCard extends StatelessWidget {
  const TaxiRatingCard({super.key, required this.driver, required this.stars, required this.onStar});

  final TaxiDriverCard? driver;
  final int stars;
  final ValueChanged<int> onStar;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    return TaxiStatusCard(
      cardKey: const ValueKey('taxi_rating_card'),
      padding: DS.all(18),
      radius: TripCustomizeLook.addDayRadius,
      children: [
        Text(TripStringsTaxiStatus.rateTitle, textAlign: TextAlign.center, style: Ink3D.text(20, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
        if (d != null) ...[
          Gap.v(12),
          Center(child: TaxiDriverIdentity(driver: d, showRating: false, centered: true)),
        ],
        Gap.v(18),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++) ...[
              if (i > 1) Gap.h(8),
              Tap3D(
                tapKey: ValueKey('rate_star_$i'),
                label: '$i',
                onTap: () => onStar(i),
                child: Icon(Icons.star, size: DS.s(46), color: i <= stars ? TaxiStatusLook.star : TaxiStatusLook.holdFill),
              ),
            ],
          ],
          ),
        ),
      ],
    );
  }
}
