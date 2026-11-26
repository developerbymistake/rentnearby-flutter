import 'package:get/get.dart';

import '../../services/storage_service.dart';
import '../buddy/buddies/controllers/buddy_summary_controller.dart';
import '../buddy/buddies/data/buddies_api.dart';
import '../buddy/buddy_live.dart';
import '../seeker_home/seeker_feed_controller.dart';
import '../social/social_session_hooks.dart';
import '../taxi/journeys/journeys_controller.dart';
import 'controllers/my_trips_controller.dart';
import 'controllers/trip_shortlist_controller.dart';
import 'enquiries/my_enquiry_count_controller.dart';

abstract final class TravellerSession {
  static void clear() {
    StorageService.clearAllTripCaches();
    BuddiesApi.clearSessionCache();
    BuddyLive.reset();
    if (Get.isRegistered<SeekerFeedController>()) Get.delete<SeekerFeedController>(force: true);
    if (Get.isRegistered<MyTripsController>()) Get.delete<MyTripsController>(force: true);
    if (Get.isRegistered<JourneysController>()) Get.delete<JourneysController>(force: true);
    if (Get.isRegistered<TripShortlistController>()) Get.delete<TripShortlistController>(force: true);
    if (Get.isRegistered<MyEnquiryCountController>()) Get.delete<MyEnquiryCountController>(force: true);
    if (Get.isRegistered<BuddySummaryController>()) Get.delete<BuddySummaryController>(force: true);
    SocialSessionHooks.onLogout();
  }
}
