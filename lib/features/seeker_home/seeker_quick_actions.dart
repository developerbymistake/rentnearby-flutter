import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/tab_config_controller.dart';
import '../../design/design.dart';
import '../../navigation/traveller_gate.dart';
import '../social/shared/social_nav.dart';
import 'seeker_trip_card.dart';
import 'strings/seeker_home_strings.dart';

class SeekerQuickAction {
  const SeekerQuickAction({required this.art, required this.tone, required this.title, required this.body, required this.add, required this.onTap});

  final String art;
  final ListingTone tone;
  final String title;
  final String body;
  final bool add;
  final VoidCallback onTap;
}

abstract final class SeekerQuickActionTargets {
  static void findBuddy() => SocialNav.openTravelBuddies();
}

class SeekerQuickActions extends StatelessWidget {
  const SeekerQuickActions({super.key, this.actions});

  final List<SeekerQuickAction>? actions;

  static bool get _tripsOn {
    if (Get.isRegistered<AuthController>() && Get.isRegistered<TabConfigController>()) return Get.find<AuthController>().tripsEnabled;
    return TravellerGate.allowed && (!Get.isRegistered<TabConfigController>() || TabConfigController.to.isActiveForIndex(AppTabs.trips));
  }

  static bool get _buddyOn => TravellerGate.allowed;

  // FX-25: Plan a trip and My trips are hidden while the Trips module is off.
  static List<SeekerQuickAction> defaults({bool? tripsOn, bool? buddyOn}) => [
    if (tripsOn ?? _tripsOn) SeekerQuickAction(
      art: ListingArt.worldMap,
      tone: ListingTone.cB,
      title: SeekerHomeStrings.tilePlanTitle,
      body: SeekerHomeStrings.tilePlanBody,
      add: true,
      onTap: SeekerTripActions.planTrip,
    ),
    if (tripsOn ?? _tripsOn) SeekerQuickAction(
      art: ListingArt.luggage,
      tone: ListingTone.teal,
      title: SeekerHomeStrings.tileTripsTitle,
      body: SeekerHomeStrings.tileTripsBody,
      add: false,
      onTap: SeekerTripActions.openMyTrips,
    ),
    if (buddyOn ?? _buddyOn) SeekerQuickAction(
      art: ListingArt.panda,
      tone: ListingTone.cB,
      title: SeekerHomeStrings.tileBuddyTitle,
      body: SeekerHomeStrings.tileBuddyBody,
      add: false,
      onTap: SeekerQuickActionTargets.findBuddy,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final given = actions;
    if (given != null) return _build(given);
    if (!Get.isRegistered<TabConfigController>()) return _build(defaults());
    return Obx(() {
      TabConfigController.to.version.value;
      if (Get.isRegistered<AuthController>()) Get.find<AuthController>().roleKey.value;
      return _build(defaults());
    });
  }

  Widget _build(List<SeekerQuickAction> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: const TitleRow3D(title: SeekerHomeStrings.quickActions)),
        LayoutBuilder(
          builder: (context, box) {
            final width = tileWidth(box.maxWidth);
            return MealsRail(
              physics: const BouncingScrollPhysics(),
              children: [
                for (final a in list)
                  MealsCardV(
                    key: ValueKey('seeker-qa-${a.title}'),
                    width: width,
                    tone: a.tone,
                    art: a.art,
                    title: a.title,
                    minCardHeight: 0,
                    goIcon: a.add ? Icons.add : Icons.arrow_forward,
                    onTap: a.onTap,
                    semanticsLabel: '${a.title}, ${a.body}',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static double tileWidth(double maxWidth) {
    final w = (maxWidth - DS.s(20)) / 3.1;
    return w.clamp(DS.s(104), DS.s(160)).toDouble();
  }
}
