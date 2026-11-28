import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/profile_photo_strings.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
import 'package:bakhli/design/extra/ext_buddy.dart';
import 'package:bakhli/features/social/a/edit/place_picker_sheet.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_steps.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/a/widgets/social_chips_a.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
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
}

_Loc _putLoc() {
  final loc = Get.put<LocationController>(_Loc()) as _Loc;
  loc.selectedDistrict.value = DistrictModel(id: 'nt', name: 'Nainital', stateName: 'Uttarakhand');
  return loc;
}

final _pages = [GetPage(name: AppRoutes.main, page: () => const Scaffold(body: Text('MAIN')))];

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await settle(t);
}

Future<void> _toStep3(WidgetTester t) async {
  final c = t.widget<OnboardingStepYou>(find.byType(OnboardingStepYou)).c;
  c.gender.value = SocialStringsA.male;
  c.birthMonth.value = 1;
  c.birthYear.value = DateTime.now().year - 18;
  c.interests.assignAll(const ['Mountains', 'Treks', 'Food']);
  c.skills.assignAll(const ['Driver', 'Cook']);
  expect(c.next(), isTrue);
  expect(c.next(), isTrue);
  await settle(t);
}

Future<void> _pickFirst(WidgetTester t, Key pill, String value) async {
  await _tap(t, find.byKey(pill));
  await t.tap(find.text(value).last);
  await settle(t);
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker(profileCompleted: false);
    TripCityCatalog.to.seedForTest(const [
      TripCityModel(cityKey: 1, name: 'Rishikesh', districtName: 'Dehradun', stateName: 'Uttarakhand', latitude: 30.1, longitude: 78.3),
    ]);
  });
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('step 1 shows the compact header, dots, no fox hero and a disabled Next with the hint ($size, $scale)', (t) async {
        installServer();
        await pumpSocial(t, const OnboardingScreen(), size: size, textScale: scale, pages: _pages);
        expect(find.text(SocialStringsA.obTitle), findsOneWidget);
        expect(find.text(SocialStringsA.obStep1), findsOneWidget);
        expect(find.byType(OnboardingStepDots), findsOneWidget);
        expect(find.byKey(const ValueKey('ob_dot_2')), findsOneWidget);
        expect(find.text(SocialStringsA.birthHelp), findsOneWidget);
        expect(find.text('Add your name, gender and birth month and year'), findsNothing);
        expect(find.byKey(const ValueKey('ob_hint')), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('step 1 has no phone or username row (Fill basic details showed them) and keeps the prefilled name', (t) async {
    installServer();
    await pumpSocial(t, const OnboardingScreen(), size: const Size(720, 1400), pages: _pages);
    expect(find.byType(AuthVerifiedRow), findsNothing);
    expect(find.byType(UsernameLockedPill), findsNothing);
    expect(find.text('Bakhli#48291736'), findsNothing);
    expect(find.textContaining('+91 '), findsNothing);
    expect((find.byKey(const ValueKey('ob_name')).evaluate().single.widget as TextField).controller!.text, 'Rahul Verma');
    expect(find.byType(OnboardingPhotoRow), findsOneWidget);
    await drain(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('existing seeker walks the 3 steps, sees the live preview and finishes', (t) async {
    final server = installServer();
    server.on('PUT', '/social/me/onboarding', myProfileJson());
    await pumpSocial(t, const OnboardingScreen(), pages: _pages);

    expect((find.byKey(const ValueKey('ob_name')).evaluate().single.widget as TextField).controller!.text, 'Rahul Verma');
    expect(find.text('Pick your gender and birth month and year'), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('ob_gender_Male')));
    await _pickFirst(t, const ValueKey('ob_month'), 'January');
    await _pickFirst(t, const ValueKey('ob_year'), '${DateTime.now().year - 18}');
    expect(find.byKey(const ValueKey('ob_hint')), findsNothing);
    await _tap(t, find.byKey(OnboardingBottom.buttonKey));

    expect(find.text(SocialStringsA.obStep2), findsOneWidget);
    expect(find.text('Pick 2 more interests and 2 skills'), findsOneWidget);
    for (final i in ['Mountains', 'Treks', 'Food']) {
      await _tap(t, find.byKey(ValueKey('ob_int_$i')));
    }
    await _tap(t, find.byKey(const ValueKey('ob_skill_Driver')));
    await _tap(t, find.byKey(const ValueKey('ob_skill_Cook')));
    expect(find.byKey(const ValueKey('ob_add_place')), findsNothing, reason: 'I-10: places moved to step 3');
    await _tap(t, find.byKey(OnboardingBottom.buttonKey));

    expect(find.text(SocialStringsA.obStep3), findsOneWidget);
    expect(find.text('Pick 1 place'), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('ob_add_place')));
    await t.tap(find.text('Rishikesh').last);
    await settle(t);
    expect(find.text('Rishikesh'), findsOneWidget);
    expect(find.text(SocialStringsA.placesAdded(1)), findsOneWidget);
    final placeAdd = t.getRect(find.byKey(const ValueKey('ob_add_place')));
    expect(placeAdd.bottom, lessThan(t.getRect(find.byKey(const ValueKey('ob_about'))).top), reason: 'I-10: places above About');
    expect(find.text('Hills over beaches. Chai at every stop.'), findsNothing, reason: 'I-10: no About examples');
    expect(find.byKey(const ValueKey('ob_preview')), findsNothing);
    await t.ensureVisible(find.byKey(const ValueKey('ob_about')));
    await t.enterText(find.byKey(const ValueKey('ob_about')), 'Weekend trekker. Happy to share a cab.');
    await settle(t);
    expect(find.byKey(const ValueKey('ob_preview')), findsOneWidget);
    expect(find.text(SocialStringsA.howOthersSee), findsOneWidget);
    await _tap(t, find.byKey(OnboardingBottom.buttonKey));

    final body = server.calls('PUT', '/social/me/onboarding').single.data as Map;
    expect(body['gender'], 'Male');
    expect(body['birthMonth'], 1);
    expect(body['interests'], ['Mountains', 'Treks', 'Food']);
    expect(body['skills'], ['Driver', 'Cook']);
    expect(body['places'], ['Rishikesh']);
    expect(find.text('MAIN'), findsOneWidget);
    await drain(t);
  });

  testWidgets('back from step 2 returns to step 1', (t) async {
    installServer();
    await pumpSocial(t, const OnboardingScreen(), pages: _pages);
    await _tap(t, find.byKey(const ValueKey('ob_gender_Female')));
    await _pickFirst(t, const ValueKey('ob_month'), 'January');
    await _pickFirst(t, const ValueKey('ob_year'), '${DateTime.now().year - 18}');
    await _tap(t, find.byKey(OnboardingBottom.buttonKey));
    expect(find.text(SocialStringsA.obStep2), findsOneWidget);
    await _tap(t, find.byIcon(Icons.chevron_left_rounded));
    expect(find.text(SocialStringsA.obStep1), findsOneWidget);
    await drain(t);
  });

  testWidgets('as the login gate step 1 has no back; Log out sits only in the menu, no Change role for a Seeker', (t) async {
    installServer();
    await pumpSocial(t, const OnboardingScreen(), pages: _pages);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.text(ProfilePhotoStrings.logOut), findsNothing, reason: 'mock A1: no bottom Log out link');
    expect(find.byKey(OnboardingHeader.menuKey), findsOneWidget);
    await _tap(t, find.byKey(OnboardingHeader.menuKey));
    expect(find.text(ProfilePhotoStrings.logOut), findsOneWidget);
    expect(find.text('Change role'), findsNothing, reason: 'R1: Seekers cannot change role (owner order 2026-11-27)');
    await drain(t);
  });

  testWidgets('opened from Profile, step 1 Back leaves the wizard', (t) async {
    installServer();
    await pumpSocial(
      t,
      const Scaffold(body: Text('PROFILE')),
      pages: [
        ..._pages,
        GetPage(name: AppRoutes.onboarding, page: () => const OnboardingScreen()),
      ],
    );
    Get.toNamed(AppRoutes.onboarding);
    await settle(t);
    expect(find.text(SocialStringsA.obStep1), findsOneWidget);
    expect(find.text(ProfilePhotoStrings.logOut), findsNothing);
    await _tap(t, find.byIcon(Icons.chevron_left_rounded));
    expect(find.text(SocialStringsA.obStep1), findsNothing);
    expect(find.text('PROFILE'), findsOneWidget);
    await drain(t);
  });

  testWidgets('gender tiles centre the art and the label', (t) async {
    installServer();
    await pumpSocial(t, const OnboardingScreen(), pages: _pages);
    for (final g in SocialStringsA.genders) {
      final tile = t.getRect(find.byKey(ValueKey('ob_gender_$g')));
      expect(t.getCenter(find.text(g)).dx, closeTo(tile.center.dx, 1.0), reason: g);
    }
    await drain(t);
  });

  testWidgets('step 3 About field shows a bio already held by the controller', (t) async {
    installServer();
    await pumpSocial(t, const OnboardingScreen(), pages: _pages);
    final c = t.widget<OnboardingStepYou>(find.byType(OnboardingStepYou)).c;
    c.gender.value = SocialStringsA.male;
    c.birthMonth.value = 1;
    c.birthYear.value = DateTime.now().year - 18;
    c.interests.assignAll(const ['Mountains', 'Treks', 'Food']);
    c.skills.assignAll(const ['Driver', 'Cook']);
    c.places.assignAll(const ['Rishikesh']);
    expect(c.next(), isTrue);
    expect(c.next(), isTrue);
    c.about.value = 'Hills over beaches.';
    await settle(t);
    expect((find.byKey(const ValueKey('ob_about')).evaluate().single.widget as TextField).controller!.text, 'Hills over beaches.');
    expect(find.text('19/150'), findsOneWidget);
    final counter = t.getRect(find.byKey(OnboardingStepAbout.counterKey));
    expect(counter.bottom, lessThanOrEqualTo(t.getRect(find.byKey(const ValueKey('ob_about'))).top), reason: 'mock A3: counter on the About label row');
    expect(find.text(SocialStringsA.needed), findsNothing);
    await drain(t);
  });

  testWidgets('preview card: one skill plus a count, city falls back to Traveller, gender in a white badge', (t) async {
    await pumpSocial(
      t,
      const Scaffold(
        body: ProfilePreviewCard(
          name: 'Rahul Verma',
          about: 'Hills over beaches.',
          interests: ['Mountains'],
          places: ['Rishikesh', 'Nainital', 'Jaipur', 'Manali'],
          skills: ['Photographer', 'Driver'],
          gender: 'Male',
        ),
      ),
    );
    expect(find.text('Photographer'), findsOneWidget);
    expect(find.text('Driver'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text(SocialStringsA.traveller), findsOneWidget);
    final glyph = t.widget<GenderGlyph>(find.byType(GenderGlyph));
    expect(glyph.color, GenderGlyph.inkOf('Male'));
    await drain(t);
  });

  testWidgets('step 3 shows three cards in order: Home city, Places, About', (t) async {
    installServer();
    _putLoc();
    await pumpSocial(t, const OnboardingScreen(), size: const Size(392, 2000), pages: _pages);
    await _toStep3(t);
    final cards = find.descendant(of: find.byType(OnboardingStepAbout), matching: find.byType(OnboardingCard));
    expect(cards, findsNWidgets(3));
    bool inCard(int i, Finder f) => find.descendant(of: cards.at(i), matching: f).evaluate().isNotEmpty;
    expect(inCard(0, find.byKey(const ValueKey('ob_home_city'))), isTrue);
    expect(inCard(1, find.byKey(const ValueKey('ob_add_place'))), isTrue);
    expect(inCard(2, find.byKey(const ValueKey('ob_about'))), isTrue);
    expect(t.getRect(cards.at(0)).bottom, lessThan(t.getRect(cards.at(1)).top));
    expect(t.getRect(cards.at(1)).bottom, lessThan(t.getRect(cards.at(2)).top));
    expect(find.text(SocialStringsA.homeCity), findsOneWidget);
    expect(find.text(SocialStringsA.homeCityHint), findsOneWidget);
    expect(find.text(SocialStringsA.addHomeCity), findsOneWidget);
    expect(find.text(SocialStringsA.homeCityFound), findsNothing);
    await drain(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('step 3 cards fit a small phone with large text', (t) async {
    installServer();
    _putLoc();
    await pumpSocial(t, const OnboardingScreen(), size: const Size(320, 2400), textScale: 1.3, pages: _pages);
    await _toStep3(t);
    expect(find.byKey(const ValueKey('ob_home_city')), findsOneWidget);
    await drain(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('step 3 home city pill shows the controller value', (t) async {
    installServer();
    _putLoc();
    await pumpSocial(t, const OnboardingScreen(), size: const Size(392, 2000), pages: _pages);
    await _toStep3(t);
    final c = t.widget<OnboardingStepAbout>(find.byType(OnboardingStepAbout)).c;
    c.pickHomeCity(const PickedHome(city: 'Dehradun', state: 'Uttarakhand'));
    await settle(t);
    expect(find.descendant(of: find.byKey(const ValueKey('ob_home_city')), matching: find.text('Dehradun, Uttarakhand')), findsOneWidget);
    expect(find.text(SocialStringsA.homeCityFound), findsNothing);
    await drain(t);
  });

  testWidgets('step 3 home city found from GPS shows the help line until the user picks', (t) async {
    installServer();
    final loc = _putLoc();
    loc.gpsCityDistrict.value = DistrictModel(id: 'dd', name: 'Dehradun', stateName: 'Uttarakhand');
    loc.gpsCity.value = CityModel(id: 'ddn', districtId: 'dd', name: 'Dehradun', latitude: 30.3, longitude: 78.0);
    await pumpSocial(t, const OnboardingScreen(), size: const Size(392, 2000), pages: _pages);
    await _toStep3(t);
    expect(find.text('Dehradun, Uttarakhand'), findsOneWidget);
    expect(find.text(SocialStringsA.homeCityFound), findsOneWidget);
    final c = t.widget<OnboardingStepAbout>(find.byType(OnboardingStepAbout)).c;
    c.pickHomeCity(const PickedHome(city: 'Haldwani', state: 'Uttarakhand'));
    await settle(t);
    expect(find.text('Haldwani, Uttarakhand'), findsOneWidget);
    expect(find.text(SocialStringsA.homeCityFound), findsNothing);
    await drain(t);
  });

  testWidgets('step 3 picking the same GPS city hides the help line', (t) async {
    installServer();
    final loc = _putLoc();
    loc.gpsCityDistrict.value = DistrictModel(id: 'dd', name: 'Dehradun', stateName: 'Uttarakhand');
    loc.gpsCity.value = CityModel(id: 'ddn', districtId: 'dd', name: 'Dehradun', latitude: 30.3, longitude: 78.0);
    await pumpSocial(t, const OnboardingScreen(), size: const Size(392, 2000), pages: _pages);
    await _toStep3(t);
    expect(find.text(SocialStringsA.homeCityFound), findsOneWidget);
    final c = t.widget<OnboardingStepAbout>(find.byType(OnboardingStepAbout)).c;
    c.pickHomeCity(const PickedHome(city: 'Dehradun', state: 'Uttarakhand'));
    await settle(t);
    expect(find.text('Dehradun, Uttarakhand'), findsOneWidget);
    expect(find.text(SocialStringsA.homeCityFound), findsNothing);
    await drain(t);
  });

  testWidgets('step 3 home city opens the city sheet and the preview shows the pick', (t) async {
    installServer();
    _putLoc();
    await pumpSocial(t, const OnboardingScreen(), size: const Size(392, 2000), pages: _pages);
    await _toStep3(t);
    await _tap(t, find.byKey(const ValueKey('ob_home_city')));
    expect(find.text(SocialStringsA.pickHomeTitle), findsOneWidget);
    await t.tap(find.text('Bhimtal').last);
    await settle(t);
    expect(find.descendant(of: find.byKey(const ValueKey('ob_home_city')), matching: find.text('Bhimtal, Uttarakhand')), findsOneWidget);
    final c = t.widget<OnboardingStepAbout>(find.byType(OnboardingStepAbout)).c;
    expect(c.homeCity.value, 'Bhimtal');
    expect(c.homeState.value, 'Uttarakhand');
    await t.ensureVisible(find.byKey(const ValueKey('ob_about')));
    await t.enterText(find.byKey(const ValueKey('ob_about')), 'Weekend trekker.');
    await settle(t);
    expect(find.descendant(of: find.byKey(const ValueKey('ob_preview')), matching: find.text('Bhimtal')), findsOneWidget);
    await drain(t);
  });

  Future<void> toStep2(WidgetTester t, {Size size = const Size(392, 1600), double scale = 1.0}) async {
    installServer();
    await pumpSocial(t, const OnboardingScreen(), size: size, textScale: scale, pages: _pages);
    await _tap(t, find.byKey(const ValueKey('ob_gender_Female')));
    await _pickFirst(t, const ValueKey('ob_month'), 'January');
    await _pickFirst(t, const ValueKey('ob_year'), '${DateTime.now().year - 18}');
    await _tap(t, find.byKey(OnboardingBottom.buttonKey));
    expect(find.text(SocialStringsA.obStep2), findsOneWidget);
  }

  for (final (size, scale) in [(const Size(392, 1600), 1.0), (const Size(320, 1800), 1.3)]) {
    testWidgets('step 2: title, dots and card share one left edge and the card sits below the header curve ($size, $scale)', (t) async {
      await toStep2(t, size: size, scale: scale);
      final title = t.getRect(find.byKey(OnboardingHeader.titleKey));
      final dots = t.getRect(find.byType(OnboardingStepDots));
      final card = t.getRect(find.descendant(of: find.byType(OnboardingCard), matching: find.byType(DecoratedBox)).first);
      final header = t.getRect(find.byType(OnboardingHeader));
      final back = t.getRect(find.byKey(OnboardingHeader.backKey));
      // One compact header row (spec 23.12): back on the shared left edge, the title to its right in the same row, dots below.
      expect(back.left, closeTo(card.left, 0.5));
      expect(title.left, greaterThan(back.right));
      expect(title.left - back.right, lessThan(back.width));
      expect(title.top, lessThan(back.bottom));
      expect(title.bottom, greaterThan(back.top));
      expect(dots.top, greaterThan(back.bottom));
      expect(dots.left, closeTo(card.left, 0.5));
      expect(dots.right, closeTo(card.right, 0.5));
      expect(card.top, greaterThan(header.bottom));
      await drain(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('step 2: interests and skills are equal tiles, two per row, with a tick when picked ($size, $scale)', (t) async {
      await toStep2(t, size: size, scale: scale);
      final tiles = find.byType(ChoiceArtTile);
      expect(tiles, findsNWidgets(14));
      final first = t.getRect(tiles.first);
      for (final e in tiles.evaluate()) {
        final r = t.getRect(find.byWidget(e.widget));
        expect(r.height, closeTo(first.height, 0.5));
        expect(r.width, closeTo(first.width, 0.5));
      }
      final a = t.getRect(find.byKey(const ValueKey('ob_int_Mountains')));
      final b = t.getRect(find.byKey(const ValueKey('ob_int_Treks')));
      final c = t.getRect(find.byKey(const ValueKey('ob_int_Adventure')));
      expect(b.top, closeTo(a.top, 0.5));
      expect(c.top, greaterThan(a.bottom));
      expect(c.left, closeTo(a.left, 0.5));
      final skill = t.getRect(find.byKey(const ValueKey('ob_skill_Photographer')));
      expect(skill.left, closeTo(a.left, 0.5));
      expect(find.descendant(of: find.byKey(const ValueKey('ob_int_Mountains')), matching: find.byIcon(Icons.check_rounded)), findsNothing);
      await _tap(t, find.byKey(const ValueKey('ob_int_Mountains')));
      expect(find.descendant(of: find.byKey(const ValueKey('ob_int_Mountains')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
      expect(find.text(SocialStringsA.picked(0)), findsOneWidget);
      expect(find.byKey(const ValueKey('ob_add_place')), findsNothing);
      await drain(t);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('step 2 shows two cards, interests above skills', (t) async {
    await toStep2(t);
    final cards = find.descendant(of: find.byType(OnboardingStepStyle), matching: find.byType(OnboardingCard));
    expect(cards, findsNWidgets(2));
    expect(find.descendant(of: cards.at(0), matching: find.byKey(const ValueKey('ob_int_Mountains'))), findsOneWidget);
    expect(find.descendant(of: cards.at(0), matching: find.byKey(const ValueKey('ob_skill_Driver'))), findsNothing);
    expect(find.descendant(of: cards.at(1), matching: find.byKey(const ValueKey('ob_skill_Driver'))), findsOneWidget);
    expect(t.getRect(cards.at(0)).bottom, lessThan(t.getRect(cards.at(1)).top));
    await drain(t);
    expect(t.takeException(), isNull);
  });
}
