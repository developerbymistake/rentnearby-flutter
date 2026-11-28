import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../a/people/people_widgets.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/plus_widgets.dart';
import '../../shared/widgets/trip_join_card.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';
import 'my_posts_controller.dart';
import 'travel_buddies_controller.dart';
import 'travel_buddies_screen.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({
    super.key,
    required this.c,
    required this.mine,
    required this.rail,
    required this.scroll,
    required this.onRefresh,
    required this.onClearFilters,
    required this.railBuilder,
  });

  final TravelBuddiesController c;
  final MyPostsController mine;
  final RxList<DiscoverPerson> rail;
  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearFilters;
  final Widget Function(List<DiscoverPerson>) railBuilder;

  Widget _card(PublicTrip t) => Padding(
        key: ValueKey('feed-${t.tripId}'),
        padding: DS.gapInsets(l: 18, r: 18, b: 16),
        child: TripJoinCard(
          trip: t,
          onRequested: (id) => c.applyMyJoin(id, 'requested'),
          onStale: c.applyRefusal,
          onFollowChanged: c.applyFollow,
        ),
      );

  Widget _state(Widget card) => Padding(padding: DS.gapInsets(t: 24, b: 24), child: card);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final st = c.state.value;
      final items = c.items.toList();
      final f = c.filter.value;
      final people = rail.toList();
      final plus = mine.state.value == FeedLoad.ready && mine.items.isEmpty;
      final children = <Widget>[
        if (plus) const PlusBanner(from: 'feed'),
      ];
      switch (st) {
        case FeedLoad.loading:
          children.addAll([
            for (var i = 0; i < 2; i++)
              Padding(padding: DS.gapInsets(l: 18, r: 18, b: 16), child: SkeletonBox(height: DS.s(260), borderRadius: SocialLookB.cardRadius)),
          ]);
        case FeedLoad.offline:
          children.add(_state(StateCard.error(title: SocialStrings.offline, actionLabel: SocialStrings.retry, onAction: c.load)));
        case FeedLoad.failed:
          children.add(_state(StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: c.load)));
        case FeedLoad.ready:
          if (items.isEmpty) {
            final filtered = f.count > 0;
            children.add(_state(StateCard(
              title: filtered ? (f.q.trim().isNotEmpty ? SocialStringsB.noMatch(f.q.trim()) : SocialStringsB.noMatchFilters) : SocialStringsB.feedEmptyTitle,
              message: filtered ? null : SocialStringsB.feedEmptyBody,
              asset: ListingArt.panda,
              actionLabel: filtered ? SocialStringsB.clearFilters : null,
              onAction: filtered ? onClearFilters : null,
            )));
          } else {
            final at = f.count > 0 || people.isEmpty ? -1 : (items.length < TravelBuddiesScreen.railAfter ? items.length : TravelBuddiesScreen.railAfter);
            for (var i = 0; i < items.length; i++) {
              if (i == at) children.add(railBuilder(people));
              children.add(_card(items[i]));
            }
            if (at == items.length) children.add(railBuilder(people));
            if (c.loadingMore.value) children.add(Padding(padding: DS.gapInsets(b: 20), child: const LoadMoreFooter(loading: true)));
          }
      }
      return RefreshIndicator(
        color: ListingTone.indigo.g2,
        onRefresh: onRefresh,
        child: ListView(
          key: TravelBuddiesScreen.exploreKey,
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: DS.s(8), bottom: DS.s(24)),
          children: children,
        ),
      );
    });
  }
}
