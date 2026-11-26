import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../shared/data/social_me_api.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';

abstract final class MessagePolicies {
  static const String everyone = 'Everyone';
  static const String following = 'Following';
  static const String buddies = 'Buddies';
  static const List<String> all = [everyone, following, buddies];
}

class SocialSettingsController extends GetxController {
  SocialSettingsController({SocialMeApi api = const SocialMeApi()}) : _api = api;

  final SocialMeApi _api;
  final busy = <String>{}.obs;

  MyProfile? get profile => SocialMeController.maybe?.profile;

  Future<String?> updatePrivacy(String key, Object value) async {
    if (busy.contains(key)) return null;
    busy.add(key);
    try {
      final r = await _api.updatePrivacy({key: value});
      switch (r) {
        case BuddyOk(:final value):
          SocialMeController.maybe?.applyProfile(value);
          return null;
        case BuddyRefused(:final message):
          return message ?? SocialStrings.failed;
        case BuddyOffline():
          return SocialStrings.offline;
        case BuddyFailed():
          return SocialStrings.failed;
      }
    } finally {
      busy.remove(key);
    }
  }
}
