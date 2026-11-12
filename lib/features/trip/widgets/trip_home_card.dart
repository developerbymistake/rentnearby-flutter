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
    final card = Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 14, KitMetrics.gutter, 0),
      child: HeroBanner(
        title: TripStrings.homeCardTitle,
        subtitle: TripStrings.homeCardSubtitle,
        cta: TripStrings.start,
        iconAsset: TravelIcon.plane,
        tone: KitTone.trip,
        onTap: () => TripNavigation.start(context),
      ),
    );
    final a = animation;
    final c = animationController;
    if (a != null && c != null) return TemplateEntrance(animation: a, animationController: c, child: card);
    return TemplateEntranceOnce(child: card);
  }
}
