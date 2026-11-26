import 'package:get/get.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/data/social_me_api.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_formats.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../onboarding/onboarding_controller.dart';
import '../social_strings_a.dart';

class EditProfileController extends GetxController {
  EditProfileController({SocialMeApi api = const SocialMeApi()}) : _api = api;

  final SocialMeApi _api;

  final original = Rxn<MyProfile>();
  final name = ''.obs;
  final about = ''.obs;
  final interests = <String>[].obs;
  final skills = <String>[].obs;
  final places = <String>[].obs;
  final homeCity = RxnString();
  final homeState = RxnString();
  final nameLockedUntil = Rxn<DateTime>();
  final saving = false.obs;
  final loading = false.obs;
  final loadFailed = false.obs;

  List<String> get interestOptions {
    final c = SocialMeController.maybe?.catalog.interests ?? const <String>[];
    return c.isEmpty ? SocialCatalogDefaults.interests : c;
  }

  List<String> get skillOptions {
    final c = SocialMeController.maybe?.catalog.skills ?? const <String>[];
    return c.isEmpty ? SocialCatalogDefaults.skills : c;
  }

  List<String> get aboutExamples {
    final c = SocialMeController.maybe?.catalog.aboutExamples ?? const <String>[];
    return c.isEmpty ? SocialCatalogDefaults.aboutExamples : c;
  }

  @override
  void onInit() {
    super.onInit();
    final p = SocialMeController.maybe?.profile;
    if (p != null) {
      seed(p);
    } else {
      reload();
    }
  }

  Future<void> reload() async {
    loading.value = true;
    loadFailed.value = false;
    final r = await _api.me();
    loading.value = false;
    final p = r.valueOrNull?.profile;
    if (p == null) {
      loadFailed.value = true;
      return;
    }
    seed(p);
  }

  // original last: the screen's text sync listens to it and must see the seeded values.
  void seed(MyProfile p) {
    name.value = p.name;
    about.value = p.about;
    interests.assignAll(p.interests);
    skills.assignAll(p.skills);
    places.assignAll(p.places);
    homeCity.value = p.homeCity;
    homeState.value = p.homeState;
    nameLockedUntil.value = p.nameLockedAt(DateTime.now()) ? p.nameChangeAllowedAt : null;
    original.value = p;
  }

  bool get nameLocked => nameLockedUntil.value != null;

  void _lockName(DateTime? until) {
    final p = original.value;
    if (p == null) return;
    seed(p.withNameChangeAllowedAt(until ?? DateTime.now().toUtc().add(const Duration(days: ProfileRules.nameChangeDays))));
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> changedBody() {
    final p = original.value;
    if (p == null) return const {};
    return {
      if (!nameLocked && name.value.trim() != p.name) 'name': name.value.trim(),
      if (about.value.trim() != p.about) 'about': about.value.trim(),
      if (!_sameList(interests, p.interests)) 'interests': interests.toList(),
      if (!_sameList(skills, p.skills)) 'skills': skills.toList(),
      if (!_sameList(places, p.places)) 'places': places.toList(),
      if ((homeCity.value ?? '') != (p.homeCity ?? '') || (homeState.value ?? '') != (p.homeState ?? '')) ...{
        'homeCityName': homeCity.value,
        'homeStateName': homeState.value,
      },
    };
  }

  int get changeCount {
    final b = changedBody();
    return b.length - (b.containsKey('homeStateName') ? 1 : 0);
  }

  bool get valid =>
      name.value.trim().isNotEmpty &&
      name.value.trim().length <= ProfileRules.nameMax &&
      about.value.trim().isNotEmpty &&
      interests.length >= ProfileRules.interestsMin &&
      interests.length <= ProfileRules.interestsMax &&
      skills.length >= ProfileRules.skillsMin &&
      places.length >= ProfileRules.placesMin;

  bool get canSave => !saving.value && changeCount > 0 && valid;

  void toggleInterest(String v) {
    if (interests.remove(v)) return;
    if (interests.length < ProfileRules.interestsMax) interests.add(v);
  }

  void toggleSkill(String v) {
    if (skills.remove(v)) return;
    if (skills.length < ProfileRules.skillsMax) skills.add(v);
  }

  void addPlace(String v) {
    final t = v.trim();
    if (t.isEmpty || places.length >= ProfileRules.placesMax || places.any((p) => p.toLowerCase() == t.toLowerCase())) return;
    places.add(t);
  }

  void addAboutLine(String line) {
    final cur = about.value.trim();
    final next = cur.isEmpty ? line : '$cur $line';
    about.value = next.length > ProfileRules.aboutMax ? next.substring(0, ProfileRules.aboutMax) : next;
  }

  void _restore(Map<String, dynamic> edits) {
    if (edits['about'] is String) about.value = edits['about'] as String;
    if (edits['interests'] is List) interests.assignAll((edits['interests'] as List).cast<String>());
    if (edits['skills'] is List) skills.assignAll((edits['skills'] as List).cast<String>());
    if (edits['places'] is List) places.assignAll((edits['places'] as List).cast<String>());
    if (edits.containsKey('homeCityName')) {
      homeCity.value = edits['homeCityName'] as String?;
      homeState.value = edits['homeStateName'] as String?;
    }
  }

  Future<String?> save() async {
    if (!canSave) return null;
    saving.value = true;
    try {
      final r = await _api.updateProfile(changedBody());
      switch (r) {
        case BuddyOk(:final value):
          seed(value);
          SocialMeController.maybe?.applyProfile(value);
          if (Get.isRegistered<AuthController>()) Get.find<AuthController>().refreshProfile();
          return null;
        case BuddyRefused(:final type, :final data) when type == SocialErrorTypes.nameChangeTooSoon:
          final edits = changedBody()..remove('name');
          _lockName(BuddyJson.time(data['nextAllowedAt'] ?? data['nameChangeAllowedAt']));
          _restore(edits);
          final until = nameLockedUntil.value;
          return until == null ? SocialStringsA.nameTooSoon : '${SocialStringsA.nameTooSoon} ${SocialStringsA.nameAgainOn(SocialFormats.dayMonth(until))}';
        case BuddyRefused(:final message):
          return message ?? SocialStrings.failed;
        case BuddyOffline():
          return SocialStrings.offline;
        case BuddyFailed():
          return SocialStrings.failed;
      }
    } finally {
      saving.value = false;
    }
  }
}
