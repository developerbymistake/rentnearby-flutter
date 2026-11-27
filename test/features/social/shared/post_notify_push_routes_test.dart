import 'dart:convert';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(SocialLive.reset);

  test('follower push (one post) opens that trip post: the route and tripId pass through untouched', () {
    final data = {'notification_type': 'social_trip_posted', 'action_route': AppRoutes.tripPost, 'action_args_json': jsonEncode({'tripId': 't-1'})};
    final live = NotificationService.liveRouteData(data);
    expect(live['action_route'], AppRoutes.tripPost);
    expect(jsonDecode(live['action_args_json'] as String), {'tripId': 't-1'});
  });

  test('nearby digest with several posts opens the feed', () {
    final data = {'notification_type': 'social_nearby_trips', 'action_route': AppRoutes.travelBuddies, 'action_args_json': '{}'};
    expect(NotificationService.liveRouteData(data)['action_route'], AppRoutes.travelBuddies);
  });

  test('the host push at 50 requests opens his join requests', () {
    final data = {'notification_type': 'social_join_requests_full', 'action_route': AppRoutes.joinRequests, 'action_args_json': jsonEncode({'tripId': 't-1'})};
    final live = NotificationService.liveRouteData(data);
    expect(live['action_route'], AppRoutes.joinRequests);
    expect(jsonDecode(live['action_args_json'] as String), {'tripId': 't-1'});
  });

  test('both targets are pushed on top of main and refresh in place when already open', () {
    for (final r in [AppRoutes.tripPost, AppRoutes.travelBuddies, AppRoutes.joinRequests]) {
      expect(NotificationService.isOnTopOfMain(r), isTrue, reason: r);
      expect(NotificationService.refreshesInPlace(r), isTrue, reason: r);
    }
  });

  test('a push for the open feed reloads it; for an open post page or join list reloads that', () {
    NotificationService.bumpSocialFor(AppRoutes.travelBuddies);
    NotificationService.bumpSocialFor(AppRoutes.tripPost);
    NotificationService.bumpSocialFor(AppRoutes.joinRequests);
    expect(SocialLive.posts.value, 1);
    expect(SocialLive.joinRequests.value, 2);
  });
}
