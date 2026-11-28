import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/design.dart';
import '../../navigation/traveller_gate.dart';
import '../social/a/social_strings_a.dart';
import '../social/shared/social_live.dart';
import '../social/shared/social_me_controller.dart';
import '../social/shared/social_nav.dart';

/// Home card shown only while the traveller follows fewer than [followingBelow] people; no API call of its own.
class BuildCircleCard extends StatefulWidget {
  const BuildCircleCard({super.key});

  static const Key cardKey = ValueKey('build_circle_card');
  static const int followingBelow = 5;

  static void findTravellers() => SocialNav.openPeople(tab: 'discover');

  static bool showFor(SocialMeController me) {
    final profile = me.me.value?.profile;
    return profile != null && profile.following < followingBelow;
  }

  @override
  State<BuildCircleCard> createState() => _BuildCircleCardState();
}

class _BuildCircleCardState extends State<BuildCircleCard> {
  Worker? _follows;

  @override
  void initState() {
    super.initState();
    // A follow only bumps SocialLive; refresh the count so the card can leave at 5.
    _follows = ever<int>(SocialLive.followers, (_) {
      final me = SocialMeController.maybe;
      if (me != null && BuildCircleCard.showFor(me)) me.refreshQuiet();
    });
  }

  @override
  void dispose() {
    _follows?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!TravellerGate.allowed) return const SizedBox.shrink();
    final me = SocialMeController.maybe;
    if (me == null) return const SizedBox.shrink();
    return Obx(() {
      if (!BuildCircleCard.showFor(me)) return const SizedBox.shrink();
      return WorkoutCard(
        key: BuildCircleCard.cardKey,
        tone: ListingTone.teal,
        art: ListingArt.panda,
        title: SocialStringsA.circleTitle,
        subtitle: SocialStringsA.circleLine,
        ctaLabel: SocialStringsA.findTravellers,
        margin: DS.insets(l: 18, r: 18, b: 4, scaled: false),
        semanticsLabel: '${SocialStringsA.circleTitle}. ${SocialStringsA.circleLine} ${SocialStringsA.findTravellers}',
        onTap: BuildCircleCard.findTravellers,
      );
    });
  }
}
