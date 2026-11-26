import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(SocialLive.reset);

  test('every social page is pushed on top of main, so a push never rebuilds main', () {
    for (final route in [
      AppRoutes.settings,
      AppRoutes.editProfile,
      AppRoutes.traveller,
      AppRoutes.people,
      AppRoutes.addBuddies,
      AppRoutes.travelBuddies,
      AppRoutes.tripPost,
      AppRoutes.postTrip,
      AppRoutes.joinRequests,
      AppRoutes.dmRoom,
      AppRoutes.seekerPlus,
    ]) {
      expect(NotificationService.isOnTopOfMain(route), isTrue, reason: route);
    }
  });

  test('an open trip post, join list, feed or people page refreshes in place', () {
    for (final route in [AppRoutes.tripPost, AppRoutes.joinRequests, AppRoutes.travelBuddies, AppRoutes.people]) {
      expect(NotificationService.refreshesInPlace(route), isTrue, reason: route);
    }
  });

  test('a push for an open social page bumps the counter that page reloads on', () {
    NotificationService.bumpSocialFor(AppRoutes.joinRequests);
    NotificationService.bumpSocialFor(AppRoutes.tripPost);
    NotificationService.bumpSocialFor(AppRoutes.travelBuddies);
    NotificationService.bumpSocialFor(AppRoutes.people);
    NotificationService.bumpSocialFor(AppRoutes.tripPlan);
    expect(SocialLive.joinRequests.value, 2);
    expect(SocialLive.posts.value, 1);
    expect(SocialLive.followers.value, 1);
  });
}
