import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_controller.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../shared/social_test_support.dart';

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
  c.addPlace('Rishikesh');
}

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
    expect(c.missingHint, 'Pick 3 more interests, 1 skill and 1 place');
    c.toggleInterest('Mountains');
    expect(c.missingHint, 'Pick 2 more interests, 1 skill and 1 place');
    _fillStep2(c);
    expect(c.canNext, isTrue);
    expect(c.next(), isTrue);
    expect(c.missingHint, SocialStringsA.writeAbout);
    c.useExample('Weekend trekker. Happy to share a cab.');
    expect(c.canNext, isTrue);
    expect(c.back(), isTrue);
    expect(c.step.value, 1);
  });

  test('interests cap at 5, places are unique', () {
    final c = _make();
    for (final i in ['Mountains', 'Treks', 'Food', 'Culture', 'Camping', 'Beaches']) {
      c.toggleInterest(i);
    }
    expect(c.interests.length, 5);
    expect(c.interests, isNot(contains('Beaches')));
    c.addPlace('Manali');
    c.addPlace('manali');
    expect(c.places, ['Manali']);
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
    c.useExample('Hills over beaches. Chai at every stop.');
    c.homeCity = 'Dehradun';
    c.homeState = 'Uttarakhand';
    expect(c.profileBody(), {
      'gender': 'Male',
      'birthMonth': 8,
      'birthYear': 1998,
      'interests': ['Mountains', 'Treks', 'Food'],
      'skills': ['Driver'],
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
    c.useExample('Hills over beaches. Chai at every stop.');
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
    c.useExample('Hills over beaches. Chai at every stop.');
    expect(await c.finish(), isFalse);
    expect(c.error.value, 'Bakhli is for people who are 18 or over.');
  });

  test('the traveller form never creates an account: finish only calls PUT /social/me/onboarding', () async {
    final server = installServer();
    server.on('PUT', '/social/me/onboarding', myProfileJson());
    final c = _make();
    _fillStep1(c);
    _fillStep2(c);
    c.useExample('Hills over beaches. Chai at every stop.');
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
}
