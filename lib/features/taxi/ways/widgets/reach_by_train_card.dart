import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../taxi_ways_strings.dart';

class ReachByTrainCard extends StatelessWidget {
  final String placeName;

  const ReachByTrainCard({super.key, required this.placeName});

  @override
  Widget build(BuildContext context) => WideCard(
        kind: WideKind.slim,
        tone: ListingTone.cB,
        art: 'assets/images/design/travel3d/train.png',
        title: TaxiWaysStrings.reachBy(placeName),
        subtitle: TaxiWaysStrings.reachBody,
      );
}
