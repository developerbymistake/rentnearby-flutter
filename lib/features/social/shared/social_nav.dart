import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';

abstract final class SocialNav {
  static Future<dynamic>? _go(String route, [Map<String, dynamic> args = const {}]) => Get.toNamed(route, arguments: args);

  static String? get _myId => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;

  static Future<dynamic>? openSettings() => _go(AppRoutes.settings);

  static Future<dynamic>? openEditProfile() => _go(AppRoutes.editProfile);

  static Future<dynamic>? openTraveller(String userId) {
    if (userId.isNotEmpty && userId == _myId) {
      Get.until((r) => r.settings.name == AppRoutes.main || r.isFirst);
      Get.find<AuthController>().openPlace(AppPlace.profile);
      return null;
    }
    return _go(AppRoutes.traveller, {'userId': userId});
  }

  static Future<dynamic>? openPeople({String tab = 'discover'}) => _go(AppRoutes.people, {'tab': tab});

  static Future<dynamic>? openAddBuddies() => _go(AppRoutes.addBuddies);

  static Future<dynamic>? openTravelLevels() => _go(AppRoutes.travelLevels);

  // The feed already on top: never stack a second copy.
  static Future<dynamic>? openTravelBuddies({bool posted = false}) =>
      Get.currentRoute == AppRoutes.travelBuddies ? null : _go(AppRoutes.travelBuddies, {if (posted) 'posted': true});

  static Future<dynamic>? openTripPost(String tripId) => _go(AppRoutes.tripPost, {'tripId': tripId});

  static Future<dynamic>? openPostTrip({String? tripId}) => _go(AppRoutes.postTrip, {'tripId': ?tripId});

  static Future<dynamic>? openJoinRequests(String tripId) => _go(AppRoutes.joinRequests, {'tripId': tripId});

  static Future<dynamic>? openChats() => Get.toNamed(AppRoutes.chatsList);

  static Future<dynamic>? openDirectChat({required String userId, required String name, String? photoUrl}) =>
      _go(AppRoutes.dmRoom, {'userId': userId, 'name': name, 'photoUrl': ?photoUrl});

  static Future<dynamic>? openRoom(String roomId) => _go(AppRoutes.dmRoom, {'roomId': roomId});

  static Future<dynamic>? openTripChat(String tripId) => _go(AppRoutes.dmRoom, {'tripId': tripId});

  static Future<dynamic>? openPlus({String? from}) => _go(AppRoutes.seekerPlus, {'from': ?from});
}
