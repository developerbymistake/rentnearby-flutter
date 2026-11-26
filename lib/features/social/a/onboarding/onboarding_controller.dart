import 'package:get/get.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/location_controller.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/data/social_me_api.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_strings.dart';
import '../social_strings_a.dart';

abstract final class SocialCatalogDefaults {
  static const List<String> interests = ['Mountains', 'Treks', 'Beaches', 'Adventure', 'Food', 'Culture', 'Photography', 'Spiritual', 'Road trips', 'Camping'];
  static const List<String> skills = ['Photographer', 'Driver', 'Cook', 'Tour guide', 'Content creator', 'First aid'];
  static const List<String> aboutExamples = [
    'Hills over beaches. Chai at every stop.',
    'Weekend trekker. Happy to share a cab.',
    'Slow travel, local food, early mornings.',
  ];
}

abstract final class ProfileRules {
  static const int nameMax = 100;
  static const int aboutMax = 150;
  static const int interestsMin = 3;
  static const int interestsMax = 5;
  static const int skillsMin = 1;
  static const int skillsMax = 6;
  static const int placesMin = 1;
  static const int placesMax = 20;
  static const int oldestYear = 1940;
  static const int adultYears = 18;
  static const int nameChangeDays = 14;

  static List<int> birthYears(DateTime now) => [for (var y = now.year - adultYears; y >= oldestYear; y--) y];

  static bool isAdult(int month, int year, DateTime now) => (now.year * 12 + now.month) - (year * 12 + month) >= adultYears * 12;
}

class OnboardingController extends GetxController {
  OnboardingController({required this.existing, this.phone, SocialMeApi api = const SocialMeApi(), DateTime Function()? clock})
      : _api = api,
        _clock = clock ?? DateTime.now;

  static const int stepCount = 3;

  final bool existing;
  final String? phone;
  final SocialMeApi _api;
  final DateTime Function() _clock;

  final step = 0.obs;
  final name = ''.obs;
  final gender = RxnString();
  final birthMonth = RxnInt();
  final birthYear = RxnInt();
  final interests = <String>[].obs;
  final skills = <String>[].obs;
  final places = <String>[].obs;
  final about = ''.obs;
  final submitting = false.obs;
  final error = RxnString();
  String? homeCity;
  String? homeState;

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

  List<int> get years => ProfileRules.birthYears(_clock());

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AuthController>()) {
      final n = Get.find<AuthController>().user.value?.name?.trim() ?? '';
      if (existing && n.isNotEmpty) name.value = n;
    }
    if (Get.isRegistered<LocationController>()) {
      final loc = Get.find<LocationController>();
      final city = loc.autoCity.value?.name.trim();
      if (city != null && city.isNotEmpty) homeCity = city;
      final state = loc.selectedDistrict.value?.stateName?.trim();
      if (state != null && state.isNotEmpty) homeState = state;
    }
  }

  String get trimmedName => name.value.trim();

  bool get _nameOk => trimmedName.isNotEmpty && trimmedName.length <= ProfileRules.nameMax;

  bool get step1Ok => _nameOk && gender.value != null && birthMonth.value != null && birthYear.value != null;

  bool get step2Ok =>
      interests.length >= ProfileRules.interestsMin &&
      interests.length <= ProfileRules.interestsMax &&
      skills.length >= ProfileRules.skillsMin &&
      places.length >= ProfileRules.placesMin;

  bool get step3Ok => about.value.trim().isNotEmpty && about.value.trim().length <= ProfileRules.aboutMax;

  bool get canNext => switch (step.value) {
        0 => step1Ok,
        1 => step2Ok,
        _ => step3Ok,
      };

  String? get missingHint {
    if (canNext) return null;
    switch (step.value) {
      case 0:
        if (trimmedName.length > ProfileRules.nameMax) return SocialStringsA.nameTooLong;
        return SocialStringsA.step1Missing(name: !_nameOk, gender: gender.value == null, birth: birthMonth.value == null || birthYear.value == null);
      case 1:
        final i = ProfileRules.interestsMin - interests.length;
        return SocialStringsA.step2Missing(
          interests: i > 0 ? i : 0,
          skills: skills.length >= ProfileRules.skillsMin ? 0 : ProfileRules.skillsMin - skills.length,
          places: places.length >= ProfileRules.placesMin ? 0 : ProfileRules.placesMin - places.length,
        );
      default:
        return SocialStringsA.writeAbout;
    }
  }

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
    if (t.isEmpty || places.length >= ProfileRules.placesMax) return;
    if (places.any((p) => p.toLowerCase() == t.toLowerCase())) return;
    places.add(t);
  }

  void removePlace(String v) => places.remove(v);

  void useExample(String text) => about.value = text.length > ProfileRules.aboutMax ? text.substring(0, ProfileRules.aboutMax) : text;

  bool next() {
    if (!canNext || step.value >= stepCount - 1) return false;
    step.value++;
    error.value = null;
    return true;
  }

  bool get isLast => step.value == stepCount - 1;

  bool back() {
    if (step.value == 0) return false;
    step.value--;
    return true;
  }

  Map<String, dynamic> profileBody() => {
        'gender': gender.value,
        'birthMonth': birthMonth.value,
        'birthYear': birthYear.value,
        'interests': interests.toList(),
        'skills': skills.toList(),
        'places': places.toList(),
        'about': about.value.trim(),
        'homeCityName': ?homeCity,
        'homeStateName': ?homeState,
      };

  Future<bool> finish() async {
    if (!step1Ok || !step2Ok || !step3Ok || submitting.value) return false;
    submitting.value = true;
    error.value = null;
    try {
      return existing ? await _finishExisting() : await _finishNew();
    } finally {
      submitting.value = false;
    }
  }

  Future<bool> _finishNew() async {
    final auth = Get.find<AuthController>();
    return auth.createOnboardingAccount(
      phone: phone ?? '',
      name: trimmedName,
      gender: gender.value,
      birthMonth: birthMonth.value,
      birthYear: birthYear.value,
      interests: interests.toList(),
      skills: skills.toList(),
      places: places.toList(),
      about: about.value.trim(),
      homeCityName: homeCity,
      homeStateName: homeState,
    );
  }

  Future<bool> _finishExisting() async {
    final auth = Get.find<AuthController>();
    final current = auth.user.value?.name?.trim() ?? '';
    if (trimmedName != current) {
      final nameError = await auth.saveName(trimmedName);
      if (nameError != null) {
        error.value = nameError;
        return false;
      }
    }
    final r = await _api.completeOnboarding(profileBody());
    switch (r) {
      case BuddyOk(:final value):
        SocialMeController.maybe?.applyProfile(value);
        auth.markProfileCompleted(gender: value.gender.isEmpty ? (gender.value ?? '') : value.gender);
        SocialMeController.maybe?.refreshQuiet();
        return true;
      case BuddyRefused(:final message):
        error.value = message ?? SocialStrings.failed;
      case BuddyOffline():
        error.value = SocialStrings.offline;
      case BuddyFailed():
        error.value = SocialStrings.failed;
    }
    return false;
  }
}
