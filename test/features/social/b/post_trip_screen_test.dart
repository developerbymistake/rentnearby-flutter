import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/models/post_draft.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/social_widgets_b.dart';
import 'package:bakhli/features/social/b/wizard/post_about_step.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_controller.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_screen.dart';
import 'package:bakhli/features/social/b/wizard/post_when_step.dart';
import 'package:bakhli/features/social/b/wizard/post_wizard_parts.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
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
        expect(find.text('Rishikesh'), findsOneWidget, reason: 'I-6: one city, no state filter');
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

  testWidgets('When: Anyone · Men · Women with a lock on Women; Men is free, Women shows the Plus box and stays Anyone; exact date shows the strip', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(gender: 'Female'));
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    final who = find.byKey(PostWhenStep.whoKey);
    expect(find.descendant(of: who, matching: find.text(SocialStringsB.anyone)), findsOneWidget);
    expect(find.descendant(of: who, matching: find.text(SocialStringsB.men)), findsOneWidget);
    expect(find.descendant(of: who, matching: find.text(SocialStringsB.women)), findsOneWidget);
    expect(find.descendant(of: who, matching: find.byIcon(Icons.lock_rounded)), findsOneWidget);
    await t.tap(find.descendant(of: who, matching: find.text(SocialStringsB.men)));
    await settle(t);
    expect(c.draft.value.joinGender, 'M');
    expect(find.byKey(PostWhenStep.genderLockKey), findsNothing);
    await t.tap(find.descendant(of: who, matching: find.text(SocialStringsB.women)));
    await settle(t);
    expect(find.byKey(PostWhenStep.genderLockKey), findsOneWidget);
    expect(find.textContaining('Women-only trips are a Plus feature.'), findsOneWidget);
    expect(find.textContaining('Your post stays open to anyone for now.'), findsOneWidget);
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

  testWidgets('I-1 When: How will you travel? is the equal tab row like Seats: Taxi | Bike | Bus | Train, Taxi by default, Bike can be picked', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    final travel = find.byKey(PostWhenStep.travelKey);
    await t.ensureVisible(travel);
    await settle(t);
    expect(find.text(SocialStringsB.howTravel), findsOneWidget);
    expect(SocialStringsB.travelLabels, ['Taxi', 'Bike', 'Bus', 'Train']);
    for (final label in SocialStringsB.travelLabels) {
      expect(find.descendant(of: travel, matching: find.text(label)), findsOneWidget, reason: label);
    }
    expect(t.widget<SegmentTabs>(travel).compact, isFalse);
    expect(t.widget<SegmentTabs>(travel).selected, 0);
    expect(c.draft.value.travelMode, TravelModes.taxi);
    await t.tap(find.descendant(of: travel, matching: find.text('Bike')));
    await settle(t);
    expect(c.draft.value.travelMode, 'bike');
    expect(t.widget<SegmentTabs>(travel).selected, 1);
    await drain(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('I-6 When: How long? offers 1 to 4 days only', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    await t.tap(find.byKey(PostWhenStep.howLongKey));
    await settle(t);
    expect(find.text(SocialStringsB.howLongSub), findsWidgets);
    for (var d = 1; d <= 4; d++) {
      expect(find.byKey(ValueKey('post_days_$d')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('post_days_5')), findsNothing);
    expect(find.byKey(const ValueKey('post_days_11')), findsNothing);
    await t.tap(find.byKey(const ValueKey('post_days_2')));
    await settle(t);
    expect(c.draft.value.days, 2);
    await drain(t);
  });

  testWidgets('When with Plus: no lock, Women is set', (t) async {
    final server = installServer();
    final me = putSocialMe(server, socialMeWith(isPlus: true, genderOnly: true, gender: 'Male'));
    await t.runAsync(me.load);
    expect(me.limits.genderOnlyTrips, isTrue);
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    final who = find.byKey(PostWhenStep.whoKey);
    expect(find.descendant(of: who, matching: find.byIcon(Icons.lock_rounded)), findsNothing);
    await t.tap(find.descendant(of: who, matching: find.text(SocialStringsB.women)));
    await settle(t);
    expect(c.draft.value.joinGender, 'F');
    expect(find.byKey(PostWhenStep.genderLockKey), findsNothing);
    await drain(t);
  });

  testWidgets('When (spec 23.8): title Post your trip; the month window is one dropdown row like How long?, no loose chips; rows share one left edge', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    expect(find.text('Post your trip'), findsWidgets);
    expect(find.textContaining('Find a travel buddy'), findsNothing);
    expect(find.textContaining('Find buddies'), findsNothing);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    await t.tap(find.byKey(WizardBottomBar.nextKey));
    await settle(t);
    expect(find.byKey(PostWhenStep.withinKey), findsOneWidget);
    expect(find.byKey(const ValueKey('post_months_1')), findsNothing);
    expect(find.byType(SocialPickChip), findsNothing);
    expect(find.descendant(of: find.byKey(PostWhenStep.withinKey), matching: find.text(SocialStringsB.withinTheNext)), findsOneWidget);
    expect(find.descendant(of: find.byKey(PostWhenStep.withinKey), matching: find.text('2 months')), findsOneWidget);
    expect(t.getTopLeft(find.byKey(PostWhenStep.withinKey)).dx, t.getTopLeft(find.byKey(PostWhenStep.howLongKey)).dx);
    expect(t.getSize(find.byKey(PostWhenStep.withinKey)).width, t.getSize(find.byKey(PostWhenStep.howLongKey)).width);
    // Mock D10c: one 'When and how long' card holds both rows (divider only between them), the window note sits below it.
    expect(find.text(SocialStringsB.whenAndHowLong), findsOneWidget);
    expect(find.descendant(of: find.byKey(PostWhenStep.withinKey), matching: find.text(SocialStringsB.withinRowSub)), findsOneWidget);
    expect(t.getTopLeft(find.byKey(PostWhenStep.howLongKey)).dy - t.getBottomLeft(find.byKey(PostWhenStep.withinKey)).dy, lessThan(3));
    expect(find.text(SocialStringsB.windowNote(2)), findsOneWidget);
    expect(t.getTopLeft(find.text(SocialStringsB.windowNote(2))).dy, greaterThan(t.getBottomLeft(find.byKey(PostWhenStep.howLongKey)).dy));
    expect(find.text('Who can join'), findsOneWidget);
    await t.tap(find.byKey(PostWhenStep.withinKey));
    await settle(t);
    for (var n = 1; n <= PostDraft.maxMonths; n++) {
      expect(find.byKey(ValueKey('post_months_$n')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('post_months_4')));
    await settle(t);
    expect(c.draft.value.withinMonths, 4);
    expect(c.draft.value.whenKind, PostDraft.within);
    expect(find.byKey(const ValueKey('post_months_1')), findsNothing);
    expect(find.descendant(of: find.byKey(PostWhenStep.withinKey), matching: find.text('4 months')), findsOneWidget);
    await t.tap(find.text(SocialStringsB.exactDate));
    await settle(t);
    expect(find.byKey(PostWhenStep.withinKey), findsNothing);
    expect(find.text(SocialStringsB.startDate), findsOneWidget);
    expect(find.byKey(PostWhenStep.howLongKey), findsOneWidget);
    expect(find.text(SocialStringsB.whenAndHowLong), findsNothing);
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

  testWidgets('About (theme review): summary card, text box and chips share one left edge; uniform card corners', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    final c = PostTripController(persist: false);
    await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
    await t.tap(find.byKey(const ValueKey('post_city_101')));
    await settle(t);
    c.goTo(PostTripController.stepAbout);
    await settle(t);
    final summary = t.getRect(find.byKey(PostAboutStep.editKey));
    final chips = t.getRect(find.byKey(PostAboutStep.chipsKey));
    expect(chips.left, closeTo(summary.left, 0.5));
    final cards = t.widgetList<Container>(find.ancestor(of: find.byKey(PostAboutStep.textKey), matching: find.byType(Container)));
    final box = cards.map((e) => e.decoration).whereType<BoxDecoration>().firstWhere((d) => d.border != null);
    expect(box.borderRadius, DS.br(CardRadius.card));
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

  testWidgets('I-23: Where list shows the admin city photo, the icon only when a city has no photo', (t) async {
    TripCityCatalog.to.seedForTest(const [
      TripCityModel(cityKey: 101, name: 'Manali', stateName: 'Himachal Pradesh', latitude: 32.2, longitude: 77.2, spotCount: 22, coverUrl: 'https://example.com/manali.jpg'),
      kasol,
    ]);
    final server = installServer();
    putSocialMe(server, socialMeWith());
    await pumpSocial(t, PostTripScreen(controller: PostTripController(persist: false)), pages: _pages);
    final manaliRow = find.byKey(const ValueKey('post_city_101'));
    final kasolRow = find.byKey(const ValueKey('post_city_102'));
    expect(find.descendant(of: manaliRow, matching: find.byKey(const ValueKey('post_city_photo_101'))), findsOneWidget);
    expect(find.descendant(of: manaliRow, matching: find.byType(Art3D)), findsNothing);
    expect(find.descendant(of: kasolRow, matching: find.byType(KitPhoto)), findsNothing);
    expect(find.descendant(of: kasolRow, matching: find.byType(Art3D)), findsOneWidget);
    await drain(t);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(minutes: 1));
  });
}
