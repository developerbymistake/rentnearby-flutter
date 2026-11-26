import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/profile_photo_strings.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_steps.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/a/widgets/social_chips_a.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

final _pages = [GetPage(name: AppRoutes.main, page: () => const Scaffold(body: Text('MAIN')))];

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
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
    expect(find.text('Pick 3 more interests, 1 skill and 1 place'), findsOneWidget);
    for (final i in ['Mountains', 'Treks', 'Food']) {
      await _tap(t, find.byKey(ValueKey('ob_int_$i')));
    }
    await _tap(t, find.byKey(const ValueKey('ob_skill_Driver')));
    await _tap(t, find.byKey(const ValueKey('ob_add_place')));
    await t.tap(find.text('Rishikesh').last);
    await settle(t);
    expect(find.text('Rishikesh'), findsOneWidget);
    await _tap(t, find.byKey(OnboardingBottom.buttonKey));

    expect(find.text(SocialStringsA.obStep3), findsOneWidget);
    expect(find.byKey(const ValueKey('ob_preview')), findsNothing);
    await _tap(t, find.text('Weekend trekker. Happy to share a cab.'));
    expect(find.byKey(const ValueKey('ob_preview')), findsOneWidget);
    expect(find.text(SocialStringsA.howOthersSee), findsOneWidget);
    await _tap(t, find.byKey(OnboardingBottom.buttonKey));

    final body = server.calls('PUT', '/social/me/onboarding').single.data as Map;
    expect(body['gender'], 'Male');
    expect(body['birthMonth'], 1);
    expect(body['interests'], ['Mountains', 'Treks', 'Food']);
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

  testWidgets('as the login gate step 1 has no back but offers Log out', (t) async {
    installServer();
    await pumpSocial(t, const OnboardingScreen(), pages: _pages);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.text(ProfilePhotoStrings.logOut), findsOneWidget);
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
    Get.toNamed(AppRoutes.onboarding, arguments: const {'existing': true});
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
    c.skills.assignAll(const ['Driver']);
    c.places.assignAll(const ['Rishikesh']);
    expect(c.next(), isTrue);
    expect(c.next(), isTrue);
    c.about.value = 'Hills over beaches.';
    await settle(t);
    expect((find.byKey(const ValueKey('ob_about')).evaluate().single.widget as TextField).controller!.text, 'Hills over beaches.');
    expect(find.text('19/150'), findsOneWidget);
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
}
