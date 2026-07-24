class AppConstants {
  static const String serverUrl = 'https://developerbymistake.tech';
  static const String baseUrl = '$serverUrl/api/v1';
  static const String nominatimUrl = 'https://nominatim.developerbymistake.tech';
  static const String photonUrl = 'https://photon.developerbymistake.tech';
  // static const String baseUrl = 'http://192.168.1.33:5000/api/v1'; // Local dev
  // static const String baseUrl = 'http://10.0.2.2:5000/api/v1'; // Android emulator

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String fcmTokenKey = 'fcm_token';
  static const String notifPromptDismissedKey = 'notif_prompt_dismissed_at';
  static const String subscribedDistrictTopicKey = 'subscribed_district_topic';

  static const String tourHomeSeenKey = 'tour_home_seen';
  static const String tourRoomsSeenKey = 'tour_rooms_seen';
  static const String tourPlotsSeenKey = 'tour_plots_seen';
  static const String tourServicesSeenKey = 'tour_services_seen';

  // District-switch feature — cached reference data for the location picker.
  // (Not the user's manual browsing choice — that is in-memory only, see
  // LocationController.)
  static const String districtsCacheKey = 'districts_cache';
  static const String citiesCacheKeyPrefix = 'cities_cache_';
  static const Duration locationsCacheTtl = Duration(hours: 24);

  static const String registerTokenPath = '/notifications/register-token';
  static const String districtTopicPrefix = 'district_';

  // Chat push notifications — recent-lines-per-conversation cache, so a killed-app
  // background isolate can stack a new message onto whatever the previous isolate
  // invocation already showed (flutter_local_notifications has no API to read back an
  // already-shown notification's stacked lines).
  static const String chatStackedLinesKeyPrefix = 'chat_stacked_lines_';

  static const double defaultRadius = 5.0; // km
  static const int maxPhotos = 5;

  // Map defaults
  static const double fallbackLat = 30.0668; // Uttarakhand centre
  static const double fallbackLng = 79.0193;
  static const double clusterRadius = 500.0;
  static const int maxMapMarkers = 50;
  static const List<double> radiusOptions = [1.0, 5.0, 10.0];
}

class FurnishedStatus {
  static const String none = 'None';
  static const String semi = 'Semi';
  static const String full = 'Full';
  static const List<String> values = [none, semi, full];
}
