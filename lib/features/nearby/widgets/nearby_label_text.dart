import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../models/nearby_models.dart';
import '../nearby_strings.dart';

class NearbyLabelText extends StatelessWidget {
  final NearbyDistance distance;
  final bool taxi;
  const NearbyLabelText({super.key, required this.distance, this.taxi = false});

  static String textFor(NearbyDistance d, {bool taxi = false}) {
    final city = d.city;
    switch (d.label) {
      case NearbyLabel.inCity:
        return city == null || city.trim().isEmpty ? NearbyStrings.near(null, d.km) : NearbyStrings.inCity(city);
      case NearbyLabel.near:
        return taxi ? NearbyStrings.basedIn(city, d.km) : NearbyStrings.near(city, d.km);
      case NearbyLabel.far:
        return NearbyStrings.far(city, d.state, d.km);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(textFor(distance, taxi: taxi), style: TypeTokens.label.copyWith(color: DesignColors.textSecondary)),
        if (distance.isFar) Text(NearbyStrings.byRoad, style: TypeTokens.caption),
      ],
    );
  }
}
