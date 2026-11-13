import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../taxi_ways_strings.dart';

class JourneyChangeStop extends StatelessWidget {
  final String placeName;
  final String? meetingPlace;

  const JourneyChangeStop({super.key, required this.placeName, this.meetingPlace});

  @override
  Widget build(BuildContext context) {
    final meet = meetingPlace;
    return JourneyStop3D(
      top: 0,
      change: true,
      title: placeName,
      tag: TaxiWaysStrings.changeCarHere,
      subtitle: meet != null && meet != placeName ? '${TaxiWaysStrings.meetNext} · $meet' : TaxiWaysStrings.meetNext,
    );
  }
}
