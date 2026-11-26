import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/wizard/post_about_step.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_controller.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_screen.dart';
import 'package:bakhli/features/social/b/wizard/post_when_step.dart';
import 'package:bakhli/features/social/b/wizard/post_wizard_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.travelBuddies, page: () => Scaffold(body: Text('FEED posted=${(Get.arguments as Map?)?['posted']}'))),
];

GradientPillButton _next(WidgetTester t) => t.widget<GradientPillButton>(find.byKey(WizardBottomBar.nextKey));

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
    seedCities();
  });
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('Where: header, tabs, city list; Next stays off until a city is picked ($size, $scale)', (t) async {
        final server = installServer();
        putSocialMe(server, socialMeWith());
        await pumpSocial(t, PostTripScreen(controller: PostTripController(persist: false)), size: size, textScale: scale, pages: _pages);
        expect(find.text(SocialStringsB.wizardTitle), findsOneWidget);
        expect(find.text(SocialStringsB.stepWhere), findsOneWidget);
        expect(find.text(SocialStringsB.stepWhen), findsOneWidget);
        expect(find.text(SocialStringsB.stepAbout), findsOneWidget);
        expect(find.text(SocialStringsB.whereTitle), findsOneWidget);
        expect(find.text('Chopta'), findsNothing);
        expect(_next(t).enabled, isFalse);
        await t.tap(find.byKey(const ValueKey('post_city_101')));
        await settle(t);
        expect(find.text(SocialStringsB.inState('Himachal Pradesh').toUpperCase()), findsOneWidget);
        expect(find.text('Rishikesh'), findsNothing);
        expect(find.byKey(const ValueKey('post_draft_saved')), findsNothing);
        await t.tap(find.byKey(WizardBottomBar.nextKey));
        await settle(t);
        expect(find.text(SocialStringsB.whenTitle('Manali')), findsOneWidget);
        expect(find.byKey(const ValueKey('post_draft_saved')), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('When: Men only without Plus shows the Plus box and stays Anyone; exact date shows the strip', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(gender: 'Male'));
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    expect(find.text('Men only'), findsOneWidget);
    expect(find.text('Women only'), findsNothing);
    await t.tap(find.byKey(const ValueKey('post_who_own')));
    await settle(t);
    expect(find.byKey(PostWhenStep.genderLockKey), findsOneWidget);
    expect(find.textContaining('Men-only trips are a Plus feature.'), findsOneWidget);
    expect(c.draft.value.joinGender, 'A');
    await t.tap(find.text(SocialStringsB.exactDate));
    await settle(t);
    expect(find.text(SocialStringsB.today), findsOneWidget);
    expect(_next(t).enabled, isFalse);
    await t.tap(find.byKey(const ValueKey('post_date_2')));
    await settle(t);
    expect(_next(t).enabled, isTrue);
    await drain(t);
  });

  testWidgets('About: summary, text from answers, chips add a line, Post trip goes to the feed with posted', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('POST', '/social/trips', publicTripJson(id: 'new-1', isMine: true, cities: ['Manali']));
    server.on('GET', '/social/trips/feed', {'mine': [], 'items': [], 'nextCursor': null});
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    expect(find.text(SocialStringsB.aboutTitle), findsOneWidget);
    expect(find.text('4 days · within 2 months · open to anyone'), findsOneWidget);
    expect(find.textContaining('Heading to Manali for 4 days in the next 2 months.'), findsOneWidget);
    // The chips come from the server catalog (socialMeJson sends only 'Budget trip').
    await t.ensureVisible(find.byKey(const ValueKey('post_chip_Budget trip')));
    await t.tap(find.byKey(const ValueKey('post_chip_Budget trip')));
    await settle(t);
    expect(c.draft.value.text, endsWith('Budget trip.'));
    expect(find.text(SocialStringsB.postTrip), findsOneWidget);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    expect(server.calls('POST', '/social/trips'), hasLength(1));
    expect(find.text('FEED posted=true'), findsOneWidget);
    await drain(t);
  });

  testWidgets('About: an empty text keeps Post trip off; the pencil goes back to When', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    c.goTo(PostTripController.stepAbout);
    await settle(t);
    await t.enterText(find.byKey(PostAboutStep.textKey), '');
    await settle(t);
    expect(_next(t).enabled, isFalse);
    await t.tap(find.byKey(PostAboutStep.editKey));
    await settle(t);
    expect(c.step.value, PostTripController.stepWhen);
    await drain(t);
  });

  testWidgets('a 429 public trip limit opens the Plus limit sheet', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.refuse('POST', '/social/trips', status: 429, type: 'PublicTripLimit');
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    c.goTo(PostTripController.stepAbout);
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });
}
