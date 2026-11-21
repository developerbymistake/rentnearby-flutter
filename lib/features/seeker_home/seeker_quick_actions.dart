import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../design/design.dart';
import 'seeker_feed_controller.dart';
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
  static void addExpense() {
    final id = SeekerFeedController.maybe?.feed.value?.tripCard.tripId;
    if (id == null || id.isEmpty) {
      Get.toNamed(AppRoutes.myTrips);
    } else {
      Get.toNamed(AppRoutes.tripExpenses, arguments: {'tripId': id});
    }
  }

  static void findBuddy() => Get.toNamed(AppRoutes.buddies);
}

class SeekerQuickActions extends StatelessWidget {
  const SeekerQuickActions({super.key, this.actions});

  final List<SeekerQuickAction>? actions;

  static List<SeekerQuickAction> defaults() => [
    SeekerQuickAction(
      art: ListingArt.worldMap,
      tone: ListingTone.cB,
      title: SeekerHomeStrings.tilePlanTitle,
      body: SeekerHomeStrings.tilePlanBody,
      add: true,
      onTap: SeekerTripActions.planTrip,
    ),
    SeekerQuickAction(
      art: ListingArt.luggage,
      tone: ListingTone.teal,
      title: SeekerHomeStrings.tileTripsTitle,
      body: SeekerHomeStrings.tileTripsBody,
      add: false,
      onTap: SeekerTripActions.openMyTrips,
    ),
    SeekerQuickAction(
      art: ListingArt.moneyBag,
      tone: ListingTone.cF,
      title: SeekerHomeStrings.tileExpenseTitle,
      body: SeekerHomeStrings.tileExpenseBody,
      add: true,
      onTap: SeekerQuickActionTargets.addExpense,
    ),
    SeekerQuickAction(
      art: ListingArt.guests,
      tone: ListingTone.cB,
      title: SeekerHomeStrings.tileBuddyTitle,
      body: SeekerHomeStrings.tileBuddyBody,
      add: false,
      onTap: SeekerQuickActionTargets.findBuddy,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final list = actions ?? defaults();
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
                    description: a.body,
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
