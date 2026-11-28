import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../buddy/buddy_routes.dart';
import '../shared/social_nav.dart';
import 'feed/travel_buddies_screen.dart';
import 'join/join_requests_screen.dart';
import 'post/trip_post_screen.dart';
import 'wizard/post_trip_screen.dart';

GetPage<dynamic> _page(String name, GetPageBuilder page) =>
    GetPage(name: name, page: page, customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration);

final List<GetPage<dynamic>> socialPagesB = [
  _page(
    AppRoutes.travelBuddies,
    () => TravelBuddiesScreen(
      posted: BuddyArgs.flag(BuddyArgs.current, 'posted'),
      myPosts: BuddyArgs.textOrNull(BuddyArgs.current, 'tab') == SocialNav.groupsMine,
    ),
  ),
  _page(AppRoutes.tripPost, () => TripPostScreen(tripId: BuddyArgs.text(BuddyArgs.current, 'tripId'))),
  _page(
    AppRoutes.postTrip,
    () => PostTripScreen(tripId: BuddyArgs.textOrNull(BuddyArgs.current, 'tripId'), edit: BuddyArgs.flag(BuddyArgs.current, 'edit')),
  ),
  _page(AppRoutes.joinRequests, () => JoinRequestsScreen(tripId: BuddyArgs.text(BuddyArgs.current, 'tripId'))),
];
