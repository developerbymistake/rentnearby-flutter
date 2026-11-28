import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/features/social/a/edit/place_picker_sheet.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_controller.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../shared/social_test_support.dart';

class _Loc extends LocationController {
  int asked = 0;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<CityModel?> ensureGpsCity() {
    asked++;
    return Future.value(gpsCity.value);
  }

  void resolve(String city, String state) {
    gpsCityDistrict.value = DistrictModel(id: 'd1', name: 'Dehradun', stateName: state);
    gpsCity.value = CityModel(id: 'c-$city', districtId: 'd1', name: city);
  }
}

OnboardingController _make() {
  final c = OnboardingController(clock: () => DateTime(2026, 11, 26));
  Get.put(c);
  return c;
}

void _fillStep1(OnboardingController c) {
  c.name.value = 'Rahul Verma';
  c.gender.value = 'Male';
  c.birthMonth.value = 8;
  c.birthYear.value = 1998;
}

void _fillStep2(OnboardingController c) {
  for (final i in ['Mountains', 'Treks', 'Food']) {
    if (!c.interests.contains(i)) c.toggleInterest(i);
  }
  c.toggleSkill('Driver');
  c.toggleSkill('Cook');
}

void _fillPlaces(OnboardingController c) => c.addPlace('Rishikesh');

void main() {
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  test('step 1 stays off with a hint per missing field', () {
    final c = _make();
    c.name.value = '';
    expect(c.canNext, isFalse);
    expect(c.missingHint, 'Add your name, gender and birth month and year');
    c.name.value = 'Rahul Verma';
    expect(c.missingHint, 'Pick your gender and birth month and year');
    c.gender.value = 'Male';
    expect(c.missingHint, 'Pick your birth month and year');
    c.birthMonth.value = 8;
    expect(c.canNext, isFalse);
    c.birthYear.value = 1998;
    expect(c.canNext, isTrue);
    expect(c.missingHint, isNull);
  });

  test('a name over 100 characters is refused', () {
    final c = _make();
    _fillStep1(c);
    c.name.value = 'a' * 101;
    expect(c.canNext, isFalse);
    expect(c.missingHint, SocialStringsA.nameTooLong);
  });

  test('photo is the only optional item: next moves only when the step is complete', () {
    final c = _make();
    expect(c.next(), isFalse);
    _fillStep1(c);
    expect(c.next(), isTrue);
    expect(c.step.value, 1);
    expect(c.missingHint, 'Pick 2 more interests and 2 skills');
    c.toggleInterest('Mountains');
    expect(c.missingHint, 'Pick 1 more interest and 2 skills');
    _fillStep2(c);
    expect(c.canNext, isTrue);
    expect(c.next(), isTrue);
    expect(c.missingHint, 'Pick 1 place');
    _fillPlaces(c);
    expect(c.missingHint, SocialStringsA.writeAbout);
    c.about.value = 'Weekend trekker. Happy to share a cab.';
    expect(c.canNext, isTrue);
    expect(c.back(), isTrue);
    expect(c.step.value, 1);
  });

  test('I-10 interests, skills and places cap at 3; places are unique', () {
    final c = _make();
    for (final i in ['Mountains', 'Treks', 'Food', 'Culture']) {
      c.toggleInterest(i);
    }
    expect(c.interests, ['Mountains', 'Treks', 'Food']);
    for (final s in ['Driver', 'Cook', 'Tour guide', 'First aid']) {
      c.toggleSkill(s);
    }
    expect(c.skills, ['Driver', 'Cook', 'Tour guide']);
    c.addPlace('Manali');
    c.addPlace('manali');
    expect(c.places, ['Manali']);
    for (final p in ['Shimla', 'Kasol', 'Rishikesh']) {
      c.addPlace(p);
    }
    expect(c.places, ['Manali', 'Shimla', 'Kasol']);
  });

  test('I-10 step 2 needs 2 interests and 2 skills, step 3 needs 1 place and About', () {
    final c = _make();
    _fillStep1(c);
    c.next();
    c.toggleInterest('Mountains');
    c.toggleInterest('Treks');
    c.toggleSkill('Driver');
    expect(c.step2Ok, isFalse);
    c.toggleSkill('Cook');
    expect(c.step2Ok, isTrue);
    expect(c.next(), isTrue);
    c.about.value = 'Weekend trekker.';
    expect(c.step3Ok, isFalse);
    c.addPlace('Manali');
    expect(c.step3Ok, isTrue);
    expect(ProfileRules.interestsMin, 2);
    expect(ProfileRules.skillsMin, 2);
    expect(ProfileRules.placesMin, 1);
    expect(SocialCatalogDefaults.interests, ['Mountains', 'Treks', 'Adventure', 'Food', 'Culture', 'Spiritual', 'Road trips', 'Camping']);
  });

  test('birth years run from the 18+ year down to 1940', () {
    final c = _make();
    expect(c.years.first, 2008);
    expect(c.years.last, 1940);
    expect(ProfileRules.isAdult(11, 2008, DateTime(2026, 11, 26)), isTrue);
    expect(ProfileRules.isAdult(12, 2008, DateTime(2026, 11, 26)), isFalse);
  });

  test('finish body carries every profile field and the home city when known', () {
    final c = _make();
    _fillStep1(c);
    _fillStep2(c);
    _fillPlaces(c);
    c.about.value = 'Hills over beaches. Chai at every stop.';
    c.pickHomeCity(const PickedHome(city: 'Dehradun', state: 'Uttarakhand'));
    expect(c.profileBody(), {
      'gender': 'Male',
      'birthMonth': 8,
      'birthYear': 1998,
      'interests': ['Mountains', 'Treks', 'Food'],
      'skills': ['Driver', 'Cook'],
      'places': ['Rishikesh'],
      'about': 'Hills over beaches. Chai at every stop.',
      'homeCityName': 'Dehradun',
      'homeStateName': 'Uttarakhand',
    });
  });

  test('name prefilled from the account made on Fill basic details; finish calls PUT /social/me/onboarding and marks the profile done', () async {
    final server = installServer();
    server.on('PUT', '/social/me/onboarding', myProfileJson());
    final c = _make();
    expect(c.name.value, 'Rahul Verma');
    _fillStep1(c);
    _fillStep2(c);
    _fillPlaces(c);
    c.about.value = 'Hills over beaches. Chai at every stop.';
    final ok = await c.finish();
    expect(ok, isTrue);
    final call = server.calls('PUT', '/social/me/onboarding').single;
    expect((call.data as Map)['gender'], 'Male');
    expect((call.data as Map).containsKey('name'), isFalse);
    expect(Get.find<AuthController>().user.value!.profileCompleted, isTrue);
  });

  test('Under18 shows the server message and stays', () async {
    final server = installServer();
    server.refuse('PUT', '/social/me/onboarding', status: 400, type: 'Under18', message: 'Bakhli is for people who are 18 or over.');
    final c = _make();
    _fillStep1(c);
    _fillStep2(c);
    _fillPlaces(c);
    c.about.value = 'Hills over beaches. Chai at every stop.';
    expect(await c.finish(), isFalse);
    expect(c.error.value, 'Bakhli is for people who are 18 or over.');
  });

  test('the traveller form never creates an account: finish only calls PUT /social/me/onboarding', () async {
    final server = installServer();
    server.on('PUT', '/social/me/onboarding', myProfileJson());
    final c = _make();
    _fillStep1(c);
    _fillStep2(c);
    _fillPlaces(c);
    c.about.value = 'Hills over beaches. Chai at every stop.';
    expect(await c.finish(), isTrue);
    expect(server.calls('POST', '/auth/phone/complete-onboarding'), isEmpty);
    expect(server.calls('PUT', '/social/me/onboarding'), hasLength(1));
  });

  test('a user without a name yet starts with an empty name', () {
    Get.find<AuthController>().user.value = UserModel(id: 'me', phoneNumber: '9897012345', createdAt: DateTime(2026), roleConfirmed: true, profileCompleted: false);
    final c = _make();
    expect(c.name.value, isEmpty);
    expect(c.missingHint, 'Add your name, gender and birth month and year');
  });
  group('I-29 home city from the GPS city', () {
    test('no area prefill from autoCity: home city stays empty until the GPS city resolves', () {
      final loc = Get.put<LocationController>(_Loc()) as _Loc;
      loc.autoCity.value = CityModel(id: 'area', districtId: 'd1', name: 'Kamalwaganja');
      loc.selectedDistrict.value = DistrictModel(id: 'd1', name: 'Nainital', stateName: 'Uttarakhand');
      final c = _make();
      expect(loc.asked, 1);
      expect(c.homeCity.value, isNull);
      expect(c.homeState.value, isNull);
      expect(c.homeCityFromGps, isFalse);
      expect(c.profileBody().containsKey('homeCityName'), isFalse);
      expect(c.profileBody().containsKey('homeStateName'), isFalse);
    });

    test('prefills from an already resolved GPS city', () {
      final loc = Get.put<LocationController>(_Loc()) as _Loc;
      loc.resolve('Haldwani', 'Uttarakhand');
      final c = _make();
      expect(c.homeCity.value, 'Haldwani');
      expect(c.homeState.value, 'Uttarakhand');
      expect(c.homeCityFromGps, isTrue);
    });

    test('a late GPS answer fills the field while the user has not picked', () {
      final loc = Get.put<LocationController>(_Loc()) as _Loc;
      final c = _make();
      expect(c.homeCity.value, isNull);
      loc.resolve('Haldwani', 'Uttarakhand');
      expect(c.homeCity.value, 'Haldwani');
      expect(c.homeCityFromGps, isTrue);
    });

    test('a user pick is never overwritten by a late GPS answer', () {
      final loc = Get.put<LocationController>(_Loc()) as _Loc;
      final c = _make();
      c.pickHomeCity(const PickedHome(city: 'Dehradun', state: 'Uttarakhand'));
      expect(c.homeCityFromGps, isFalse);
      loc.resolve('Haldwani', 'Uttarakhand');
      expect(c.homeCity.value, 'Dehradun');
      expect(c.homeState.value, 'Uttarakhand');
      expect(c.profileBody()['homeCityName'], 'Dehradun');
      expect(c.profileBody()['homeStateName'], 'Uttarakhand');
    });

    test('picking the same city as the GPS prefill clears the from-GPS line', () {
      final loc = Get.put<LocationController>(_Loc()) as _Loc;
      loc.resolve('Haldwani', 'Uttarakhand');
      final c = _make();
      expect(c.homeCityFromGps, isTrue);
      c.pickHomeCity(const PickedHome(city: 'Haldwani', state: 'Uttarakhand'));
      expect(c.homeCityFromGps, isFalse);
      expect(c.homeCity.value, 'Haldwani');
      expect(c.homeState.value, 'Uttarakhand');
    });

    test('a pick without a state sends no state key', () {
      final c = _make();
      c.pickHomeCity(const PickedHome(city: 'Dehradun', state: ''));
      expect(c.profileBody()['homeCityName'], 'Dehradun');
      expect(c.profileBody().containsKey('homeStateName'), isFalse);
    });
  });
}
