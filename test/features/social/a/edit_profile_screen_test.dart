import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/a/edit/edit_profile_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/a/widgets/social_chips_a.dart';
import 'package:bakhli/features/social/a/widgets/social_section_card.dart';
import 'package:bakhli/features/social/shared/social_formats.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/widgets/location_switch_sheet.dart';
import 'package:bakhli/widgets/profile_photo_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

class _Loc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<List<CityModel>> loadCitiesForDistrict(String districtId, {bool forceRefresh = false}) => Future.value([
        for (final n in ['Bhimtal', 'Haldwani']) CityModel(id: n, districtId: districtId, name: n, latitude: 29.3, longitude: 79.5),
      ]);

  @override
  Future<List<DistrictModel>> loadAllDistricts({bool forceRefresh = false}) => Future.value([DistrictModel(id: 'nt', name: 'Nainital', stateName: 'Uttarakhand')]);
}

GradientPillButton _save(WidgetTester t) => t.widget<GradientPillButton>(find.byKey(EditProfileScreen.saveKey));

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  Map<String, dynamic> validProfile() => {
        ...myProfileJson(),
        'interests': ['Mountains', 'Treks', 'Food'],
        'places': ['Rishikesh', 'Nainital', 'Jaipur'],
      };

  Future<SocialFakeServer> open(WidgetTester t, {Size size = const Size(392, 2000), double scale = 1.0}) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: validProfile()));
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const EditProfileScreen(), size: size, textScale: scale);
    return server;
  }

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('Save stays off until a change; gender and birth are locked rows ($size, $scale)', (t) async {
        await open(t, size: Size(size.width, 2000), scale: scale);
        expect(find.text(SocialStringsA.editTitle), findsOneWidget);
        expect(find.byKey(const ValueKey('edit_locked_gender')), findsOneWidget);
        expect(find.byKey(const ValueKey('edit_locked_birth')), findsOneWidget);
        expect(find.text('Aug 1998'), findsOneWidget);
        expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
        expect(find.text(SocialStringsA.lockedNote), findsOneWidget);
        expect(_save(t).enabled, isFalse);
        expect(find.text(SocialStringsA.changeToSave), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('a change enables Save, shows 1 change and sends only the changed field', (t) async {
    final server = await open(t);
    server.on('PUT', '/social/me/profile', {...myProfileJson(), 'about': 'Weekend trekker.'});
    await t.enterText(find.byKey(const ValueKey('edit_about')), 'Weekend trekker.');
    await settle(t);
    expect(_save(t).enabled, isTrue);
    expect(find.text(SocialStringsA.changes(1)), findsOneWidget);
    await t.tap(find.byKey(EditProfileScreen.saveKey));
    await settle(t);
    final body = server.calls('PUT', '/social/me/profile').single.data as Map;
    expect(body, {'about': 'Weekend trekker.'});
    expect(body.containsKey('gender'), isFalse);
    expect(body.containsKey('birthMonth'), isFalse);
    expect(_save(t).enabled, isFalse);
    await drain(t);
  });

  testWidgets('I-29 home city dropdown opens the city sheet; a pick sets city + state as one change', (t) async {
    final loc = Get.put<LocationController>(_Loc());
    loc.selectedDistrict.value = DistrictModel(id: 'nt', name: 'Nainital', stateName: 'Uttarakhand');
    final server = await open(t);
    final pill = find.byKey(const ValueKey('edit_home_city'));
    expect(find.descendant(of: pill, matching: find.text('Dehradun, Uttarakhand')), findsOneWidget);
    expect(find.text(SocialStringsA.change), findsNothing);
    await t.ensureVisible(pill);
    await t.tap(pill);
    await settle(t);
    expect(find.byType(LocationSwitchSheet), findsOneWidget);
    expect(find.text(SocialStringsA.pickHomeTitle), findsOneWidget);
    await t.tap(find.text('Haldwani'));
    await settle(t);
    expect(find.byType(LocationSwitchSheet), findsNothing);
    expect(find.descendant(of: pill, matching: find.text('Haldwani, Uttarakhand')), findsOneWidget);
    expect(find.text(SocialStringsA.changes(1)), findsOneWidget);
    server.on('PUT', '/social/me/profile', {...myProfileJson(), 'homeCity': 'Haldwani'});
    await t.tap(find.byKey(EditProfileScreen.saveKey));
    await settle(t);
    final body = server.calls('PUT', '/social/me/profile').single.data as Map;
    expect(body, {'homeCityName': 'Haldwani', 'homeStateName': 'Uttarakhand'});
    await drain(t);
  });

  testWidgets('I-10 dropping interests under 2 keeps Save off', (t) async {
    await open(t);
    await t.tap(find.text('Mountains'));
    await t.tap(find.text('Treks'));
    await settle(t);
    expect(_save(t).enabled, isFalse);
    expect(find.text(SocialStringsA.interestsHint(1)), findsOneWidget);
    await drain(t);
  });

  testWidgets('I-10 an older profile over the new limits (4 interests, 4 places) cannot save until trimmed to 3', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const EditProfileScreen(), size: const Size(392, 2000));
    await t.enterText(find.byKey(const ValueKey('edit_about')), 'Weekend trekker.');
    await settle(t);
    expect(_save(t).enabled, isFalse);
    await t.ensureVisible(find.byKey(const ValueKey('edit_interest_Photography')));
    await t.tap(find.byKey(const ValueKey('edit_interest_Photography')));
    await settle(t);
    await t.ensureVisible(find.text('Jaipur'));
    await t.tap(find.text('Jaipur'));
    await settle(t);
    expect(_save(t).enabled, isTrue);
    await drain(t);
  });

  for (final (width, scale) in [(320.0, 1.3), (320.0, 1.0)]) {
    testWidgets('narrow phone: locked pills stack and never clip Female ($width, $scale)', (t) async {
      final server = installServer();
      server.on('GET', '/social/me', socialMeJson(profile: {...myProfileJson(), 'gender': 'Female'}));
      Get.put(SocialMeController(), permanent: true);
      await pumpSocial(t, const EditProfileScreen(), size: Size(width, 2000), textScale: scale);
      final g = t.getRect(find.byKey(const ValueKey('edit_locked_gender')));
      final b = t.getRect(find.byKey(const ValueKey('edit_locked_birth')));
      final female = t.renderObject<RenderParagraph>(find.text('Female'));
      expect(female.didExceedMaxLines, isFalse, reason: 'Female must not be cut');
      if (b.top >= g.bottom) expect(b.left, closeTo(g.left, 0.5));
      await drain(t);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('wide phone keeps the pills side by side', (t) async {
    await open(t, size: const Size(411, 2000));
    final g = t.getRect(find.byKey(const ValueKey('edit_locked_gender')));
    final b = t.getRect(find.byKey(const ValueKey('edit_locked_birth')));
    expect(b.top, closeTo(g.top, 0.5));
    expect(b.left, greaterThan(g.right));
    await drain(t);
  });

  testWidgets('Remove shows only with a photo and clears it through DELETE /users/me/photo', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    server.on('DELETE', '/users/me/photo', {'id': 'me', 'phoneNumber': '9897012345', 'createdAt': '2026-11-22T10:00:00Z', 'profilePhotoUrl': null});
    Get.put(SocialMeController(), permanent: true);
    final auth = Get.find<AuthController>();
    auth.user.value = UserModel(
      id: 'me',
      phoneNumber: '9897012345',
      name: 'Rahul Verma',
      createdAt: DateTime(2026),
      role: UserRoleKeys.seeker,
      roleConfirmed: true,
      profileCompleted: true,
      gender: 'Male',
      profilePhotoUrl: 'https://x/a.jpg',
    );
    Get.put(ProfilePhotoController(offline: () async => false), permanent: true);
    await pumpSocial(t, const EditProfileScreen(), size: const Size(392, 2000));
    expect(find.byKey(EditProfileScreen.removePhotoKey), findsOneWidget);
    await t.tap(find.byKey(EditProfileScreen.removePhotoKey));
    await settle(t);
    expect(server.calls('DELETE', '/users/me/photo'), hasLength(1));
    expect(auth.user.value?.profilePhotoUrl, isNull);
    expect(find.byKey(EditProfileScreen.removePhotoKey), findsNothing);
    await drain(t);
    // Evicting the old photo makes flutter_cache_manager schedule its store cleanup 10 s later (CacheStore.cleanupRunMinInterval).
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('a tap anywhere on a place chip removes it (the whole chip is the target)', (t) async {
    await open(t);
    final chip = find.bySemanticsLabel(SocialStringsA.removeTag('Jaipur'));
    expect(chip, findsOneWidget);
    expect(t.getSize(chip).height, greaterThanOrEqualTo(t.getSize(find.text('Jaipur')).height));
    await t.ensureVisible(find.text('Jaipur'));
    await t.tap(find.text('Jaipur'));
    await settle(t);
    expect(find.text('Jaipur'), findsNothing);
    expect(find.text(SocialStringsA.changes(1)), findsOneWidget);
    await drain(t);
  });

  testWidgets('loaded profile fills the name and About fields, and only unused About lines are offered', (t) async {
    await open(t);
    String text(String key) => (find.byKey(ValueKey(key)).evaluate().single.widget as TextField).controller!.text;
    expect(text('edit_name'), 'Rahul Verma');
    expect(text('edit_about'), 'Hills over beaches. Chai at every stop.');
    expect(find.text('+ Hills over beaches. Chai at every stop.'), findsNothing);
    expect(find.text('+ Weekend trekker. Happy to share a cab.'), findsOneWidget);
    expect(find.text('+ Slow travel, local food, early mornings.'), findsOneWidget);
    await drain(t);
  });

  testWidgets('name and About fields draw no theme outline of their own', (t) async {
    await open(t);
    for (final key in ['edit_name', 'edit_about']) {
      final d = (find.byKey(ValueKey(key)).evaluate().single.widget as TextField).decoration!;
      expect(d.enabledBorder, InputBorder.none, reason: key);
      expect(d.focusedBorder, InputBorder.none, reason: key);
    }
    await drain(t);
  });

  testWidgets('identity card follows mock B5: photo with links, then labelled name and locked rows', (t) async {
    await open(t);
    final photo = t.getRect(find.byType(ProfilePhotoCircle));
    final change = t.getRect(find.text(SocialStringsA.changePhoto));
    expect(change.left, greaterThan(photo.right));
    final nameLabel = t.getRect(find.text(SocialStringsA.fullName));
    final name = t.getRect(find.byKey(EditProfileScreen.nameKey));
    expect(nameLabel.top, greaterThan(photo.bottom));
    expect(name.top, greaterThan(nameLabel.bottom));
    final lockLabel = t.getRect(find.text(SocialStringsA.genderAndBirth));
    expect(lockLabel.top, greaterThan(name.bottom));
    expect(t.getRect(find.byKey(const ValueKey('edit_locked_gender'))).top, greaterThan(lockLabel.bottom));
    await drain(t);
  });

  testWidgets('the photo shows the camera badge', (t) async {
    await open(t);
    expect(find.byType(ProfileRoundButton), findsOneWidget);
    await drain(t);
  });

  TextField nameField(WidgetTester t) => t.widget<TextField>(find.byKey(EditProfileScreen.nameKey));

  testWidgets('the name field shows the 14 day rule and stays editable when no lock is set', (t) async {
    await open(t);
    expect(find.text(SocialStringsA.nameRule), findsOneWidget);
    expect(nameField(t).readOnly, isFalse);
    await drain(t);
  });

  testWidgets('a future nameChangeAllowedAt makes the name read-only with the next date', (t) async {
    final until = DateTime.now().toUtc().add(const Duration(days: 9));
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: {...myProfileJson(), 'nameChangeAllowedAt': until.toIso8601String()}));
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const EditProfileScreen(), size: const Size(392, 2000));
    expect(nameField(t).readOnly, isTrue);
    expect(find.text(SocialStringsA.nameAgainOn(SocialFormats.dayMonth(until))), findsOneWidget);
    expect(find.text(SocialStringsA.nameRule), findsNothing);
    await drain(t);
  });

  testWidgets('a past nameChangeAllowedAt leaves the name editable', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: {...myProfileJson(), 'nameChangeAllowedAt': '2020-01-01T00:00:00Z'}));
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const EditProfileScreen(), size: const Size(392, 2000));
    expect(nameField(t).readOnly, isFalse);
    expect(find.text(SocialStringsA.nameRule), findsOneWidget);
    await drain(t);
  });

  testWidgets('NameChangeTooSoon locks the name, restores it and keeps the other edits', (t) async {
    final server = await open(t);
    final until = DateTime.utc(2026, 12, 11, 6);
    server.on('PUT', '/social/me/profile', {
      'error': {'type': 'NameChangeTooSoon', 'message': 'Too soon'},
      'data': {'nextAllowedAt': until.toIso8601String()},
    }, status: 409);
    await t.enterText(find.byKey(EditProfileScreen.nameKey), 'Rahul V');
    await t.enterText(find.byKey(const ValueKey('edit_about')), 'Weekend trekker.');
    await settle(t);
    await t.tap(find.byKey(EditProfileScreen.saveKey));
    await settle(t);
    expect(nameField(t).readOnly, isTrue);
    expect(nameField(t).controller!.text, 'Rahul Verma');
    expect(find.text(SocialStringsA.nameAgainOn(SocialFormats.dayMonth(until))), findsOneWidget);
    expect((find.byKey(const ValueKey('edit_about')).evaluate().single.widget as TextField).controller!.text, 'Weekend trekker.');
    expect(find.text(SocialStringsA.changes(1)), findsOneWidget);
    await drain(t);
  });

  testWidgets('interests and skills are equal tiles in a grid, sections use the shared section card', (t) async {
    await open(t);
    expect(find.byType(SocialSectionCard), findsNWidgets(5));
    final tiles = find.byType(ChoiceArtTile);
    expect(tiles, findsWidgets);
    final h = t.getSize(tiles.first).height;
    for (final e in tiles.evaluate()) {
      expect(t.getSize(find.byWidget(e.widget)).height, closeTo(h, 0.5));
    }
    final a = t.getRect(find.byKey(const ValueKey('edit_interest_Mountains')));
    final b = t.getRect(find.byKey(const ValueKey('edit_interest_Treks')));
    expect(b.top, closeTo(a.top, 0.5));
    expect(b.width, closeTo(a.width, 0.5));
    await drain(t);
  });
}
