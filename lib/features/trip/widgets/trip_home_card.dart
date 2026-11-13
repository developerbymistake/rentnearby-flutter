import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

class TripHomeCard extends StatelessWidget {
  const TripHomeCard({super.key, this.animation, this.animationController});

  final Animation<double>? animation;
  final AnimationController? animationController;

  @override
  Widget build(BuildContext context) {
    final card = WorkoutCard(
      tone: ListingTone.indigo,
      art: ListingArt.luggage,
      eyebrow: 'Travel Planner',
      title: TripStrings.homeCardTitle,
      subtitle: TripStrings.homeCardSubtitle,
      trailing: WorkoutTrailing.arrow,
      semanticsLabel: '${TripStrings.homeCardTitle}. ${TripStrings.homeCardSubtitle}',
      onTap: () => TripNavigation.openTripsTab(),
    );
    final a = animation;
    final c = animationController;
    if (a != null && c != null) return TemplateEntrance(animation: a, animationController: c, child: card);
    return TemplateEntranceOnce(child: card);
  }
}
