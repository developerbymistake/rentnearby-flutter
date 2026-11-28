import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/trip_join_card.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';
import 'my_posts_controller.dart';
import 'travel_buddies_controller.dart';
import 'travel_buddies_screen.dart';

class MyPostsTab extends StatelessWidget {
  const MyPostsTab({super.key, required this.c});

  final MyPostsController c;

  Widget _state(Widget card) => Padding(padding: DS.gapInsets(t: 24, b: 24), child: card);

  Widget _card(PublicTrip t) => Padding(
        key: ValueKey('mine-${t.tripId}'),
        padding: DS.gapInsets(l: 18, r: 18, b: 16),
        child: TripJoinCard(trip: t, onBack: c.load),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final st = c.state.value;
      final items = c.items.toList();
      final children = <Widget>[
        ...switch (st) {
          FeedLoad.loading => [
              for (var i = 0; i < 2; i++)
                Padding(padding: DS.gapInsets(l: 18, r: 18, b: 16), child: SkeletonBox(height: DS.s(260), borderRadius: SocialLookB.cardRadius)),
            ],
          FeedLoad.offline => [_state(StateCard.error(title: SocialStrings.offline, actionLabel: SocialStrings.retry, onAction: c.load))],
          FeedLoad.failed => [_state(StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: c.load))],
          FeedLoad.ready => items.isEmpty
              ? [
                  _state(StateCard(
                    key: TravelBuddiesScreen.mineEmptyKey,
                    title: SocialStringsB.myPostsEmptyTitle,
                    message: SocialStringsB.myPostsEmptyBody,
                    asset: ListingArt.backpack,
                  )),
                ]
              : [for (final t in items) _card(t)],
        },
      ];
      return RefreshIndicator(
        color: ListingTone.indigo.g2,
        onRefresh: c.load,
        child: ListView(
          key: TravelBuddiesScreen.mineKey,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: DS.s(8), bottom: DS.s(24)),
          children: children,
        ),
      );
    });
  }
}
