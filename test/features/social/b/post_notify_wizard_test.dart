import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/models/post_draft.dart';
import 'package:bakhli/features/social/b/social_nav_b.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/wizard/post_about_step.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_controller.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_screen.dart';
import 'package:bakhli/features/social/b/wizard/post_wizard_parts.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../c/plus_fakes.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.travelBuddies, page: () => Scaffold(body: Text('FEED posted=${(Get.arguments as Map?)?['posted']}'))),
];

Map<String, dynamic> _me({int used = 0, String? resetsAt, bool isPrivate = false}) {
  final me = socialMeWith();
  me['profile'] = {...(me['profile'] as Map<String, dynamic>), 'isPrivate': isPrivate};
  final limits = Map<String, dynamic>.from(me['limits'] as Map);
  limits['notifyPosts'] = {'limit': 2, 'used': used};
  limits['notifyNextAt'] = resetsAt;
  me['limits'] = limits;
  return me;
}

SocialLimits _limits({int used = 0}) => SocialLimits.fromJson({...socialMeJson()['limits'] as Map<String, dynamic>, 'notifyPosts': {'limit': 2, 'used': used}});

Future<PostTripController> _ready(PostTripController c) async {
  Get.put(c, tag: 'test-${identityHashCode(c)}');
  for (var i = 0; i < 20 && c.preparing.value; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return c;
}

Switch3D _switch(WidgetTester t) => t.widget<Switch3D>(find.byKey(PostAboutStep.notifyKey));

Future<PostTripController> _toAbout(WidgetTester t) async {
  final c = PostTripController(persist: false);
  await pumpSocial(t, PostTripScreen(controller: c), pages: _pages);
  await t.tap(find.byKey(const ValueKey('post_city_101')));
  await settle(t);
  c.goTo(PostTripController.stepAbout);
  await settle(t);
  await t.ensureVisible(find.byKey(PostAboutStep.notifyKey));
  await settle(t);
  return c;
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    SocialNavB.postedNote = null;
    putSeeker();
    seedCities();
  });
  tearDown(() {
    SocialNavB.postedNote = null;
    Get.reset();
  });

  group('controller', () {
    test('UC1: the switch starts OFF and the body says notifyNearby false', () async {
      final server = installServer();
      server.on('POST', '/social/trips', publicTripJson(id: 'n1', isMine: true));
      final c = await _ready(PostTripController(persist: false));
      expect(c.draft.value.notifyNearby, isFalse);
      c.toggleCity(manali);
      await c.submit();
      expect((server.calls('POST', '/social/trips').single.data as Map)['notifyNearby'], isFalse);
    });

    test('UC2: switched ON, the create body says notifyNearby true; the publish of my trip too', () async {
      final server = installServer();
      server.on('POST', '/social/trips', publicTripJson(id: 'n1', isMine: true));
      server.on('PUT', '/social/trips/t-9/post', publicTripJson(id: 't-9', isMine: true));
      final c = await _ready(PostTripController(persist: false));
      c.toggleCity(manali);
      c.setNotifyNearby(true);
      await c.submit();
      expect((server.calls('POST', '/social/trips').single.data as Map)['notifyNearby'], isTrue);
      final p = await _ready(PostTripController(tripId: 't-9', persist: false, loadTrip: (_) async => (cities: const [manali], startDate: null, days: 3)));
      p.setNotifyNearby(true);
      await p.submit();
      expect((server.calls('PUT', '/social/trips/t-9/post').single.data as Map)['notifyNearby'], isTrue);
    });

    test('UC3: weekly limit used: the switch cannot turn on and the post still goes with notifyNearby false', () async {
      final server = installServer();
      server.on('POST', '/social/trips', publicTripJson(id: 'n1', isMine: true));
      Get.put<SocialMeController>(FakeSocialMeController(_limits(used: 2)), permanent: true);
      final c = await _ready(PostTripController(persist: false));
      expect(c.notifyUsedUp, isTrue);
      expect(c.canNotifyNearby, isFalse);
      c.toggleCity(manali);
      c.setNotifyNearby(true);
      expect(c.draft.value.notifyNearby, isFalse);
      final r = await c.submit();
      expect(r, isA<BuddyOk<PublicTrip>>());
      expect((server.calls('POST', '/social/trips').single.data as Map)['notifyNearby'], isFalse);
    });

    test('UC3: if the limit is used up after the switch went ON, the body still sends false (never blocks the post)', () async {
      final server = installServer();
      server.on('POST', '/social/trips', publicTripJson(id: 'n1', isMine: true));
      final me = Get.put<SocialMeController>(FakeSocialMeController(_limits()), permanent: true);
      final c = await _ready(PostTripController(persist: false));
      c.toggleCity(manali);
      c.setNotifyNearby(true);
      expect(c.draft.value.notifyNearby, isTrue);
      me.me.value = SocialMe(limits: _limits(used: 2));
      await c.submit();
      expect((server.calls('POST', '/social/trips').single.data as Map)['notifyNearby'], isFalse);
    });

    test('UC8: a private profile cannot notify nearby travellers (followers only)', () async {
      installServer();
      final me = Get.put<SocialMeController>(FakeSocialMeController(_limits()), permanent: true);
      me.me.value = SocialMe(profile: MyProfile.fromJson(myProfileJson(isPrivate: true)), limits: _limits());
      final c = await _ready(PostTripController(persist: false));
      expect(c.notifyPrivate, isTrue);
      c.setNotifyNearby(true);
      expect(c.draft.value.notifyNearby, isFalse);
    });

    test('safety S1: a Men only / Women only post notifies nearby travellers only from a poster of that gender', () async {
      installServer();
      final me = Get.put<SocialMeController>(FakeSocialMeController(_limits()), permanent: true);
      me.me.value = SocialMe(profile: MyProfile.fromJson({...myProfileJson(), 'gender': 'Female'}), limits: _limits());
      final c = await _ready(PostTripController(persist: false));
      c.toggleCity(manali);
      expect(c.notifyGender, isFalse);
      c.setJoinGender('M');
      expect(c.notifyGender, isTrue);
      expect(c.canNotifyNearby, isFalse);
      c.setNotifyNearby(true);
      expect(c.draft.value.notifyNearby, isFalse);
      c.setJoinGender('A');
      expect(c.notifyGender, isFalse);
      c.setNotifyNearby(true);
      expect(c.draft.value.notifyNearby, isTrue);
    });

    test('nearby only for trips starting in the next 60 days: an exact date further out locks the switch; a window never does', () async {
      installServer();
      final c = await _ready(PostTripController(persist: false));
      c.toggleCity(manali);
      expect(c.notifyTooFar, isFalse);
      final n = DateTime.now();
      c.setDate(DateTime(n.year, n.month, n.day).add(const Duration(days: 61)));
      expect(c.notifyTooFar, isTrue);
      c.setNotifyNearby(true);
      expect(c.draft.value.notifyNearby, isFalse);
      c.setDate(DateTime(n.year, n.month, n.day).add(const Duration(days: 60)));
      expect(c.notifyTooFar, isFalse);
      c.setMonths(6);
      expect(c.notifyTooFar, isFalse);
    });

    test('the switch is never stored with the draft: a restored draft starts OFF', () {
      const d = PostDraft(notifyNearby: true);
      expect(d.toJson()['notifyNearby'], isTrue);
      expect(d.toStore().containsKey('notifyNearby'), isFalse);
    });
  });

  group('screen', () {
    testWidgets('About: Notify travellers near me row, OFF by default, shows what is left this week; ON is sent', (t) async {
      final server = installServer();
      putSocialMe(server, _me());
      server.on('POST', '/social/trips', publicTripJson(id: 'n1', isMine: true, cities: ['Manali']));
      final c = await _toAbout(t);
      expect(find.text(SocialStringsB.notifyNearby), findsOneWidget);
      expect(find.text('Sent at 7 am · 2 of 2 left this week'), findsOneWidget);
      expect(_switch(t).value, isFalse);
      expect(_switch(t).onChanged, isNotNull);
      await t.tap(find.byKey(PostAboutStep.notifyKey));
      await settle(t);
      expect(c.draft.value.notifyNearby, isTrue);
      expect(_switch(t).value, isTrue);
      await t.tap(find.byKey(WizardBottomBar.nextKey));
      await settle(t);
      expect((server.calls('POST', '/social/trips').single.data as Map)['notifyNearby'], isTrue);
      expect(find.text('FEED posted=true'), findsOneWidget);
      await drain(t);
    });

    testWidgets('UC3: weekly limit used: calm disabled row, a short line with the day it comes back, the post still publishes', (t) async {
      final server = installServer();
      putSocialMe(server, _me(used: 2, resetsAt: '2026-12-02T04:00:00Z'));
      server.on('POST', '/social/trips', {...publicTripJson(id: 'n1', isMine: true, cities: ['Manali']), 'notify': {'followers': 'weekLimit', 'nearby': 'off', 'used': 2, 'limit': 2}});
      await _toAbout(t);
      expect(find.text('Used 2 of 2 this week'), findsOneWidget);
      expect(_switch(t).onChanged, isNull);
      expect(_switch(t).value, isFalse);
      expect(find.byKey(PostAboutStep.notifyNoteKey), findsOneWidget);
      expect(find.textContaining(SocialStringsB.notifyUsedUp), findsOneWidget);
      expect(find.textContaining('They are back on'), findsOneWidget);
      await t.tap(find.byKey(WizardBottomBar.nextKey));
      await settle(t);
      expect(server.calls('POST', '/social/trips'), hasLength(1));
      expect(find.text('FEED posted=true'), findsOneWidget);
      expect(SocialNavB.postedNote, SocialStringsB.notifyUsedUpPosted);
      await drain(t);
    });

    testWidgets('UC8: private profile: the row is off with its reason', (t) async {
      final server = installServer();
      putSocialMe(server, _me(isPrivate: true));
      await _toAbout(t);
      expect(find.text(SocialStringsB.notifyPrivateLine), findsOneWidget);
      expect(_switch(t).onChanged, isNull);
      await drain(t);
    });

    testWidgets('UC2 poster feedback: the server keeps nearby ON, the live card line says 7 am', (t) async {
      final server = installServer();
      putSocialMe(server, _me());
      server.on('POST', '/social/trips', {...publicTripJson(id: 'n1', isMine: true, cities: ['Manali']), 'notify': {'followers': 'sent', 'nearby': 'queued', 'used': 1, 'limit': 2}});
      await _toAbout(t);
      await t.tap(find.byKey(PostAboutStep.notifyKey));
      await settle(t);
      await t.tap(find.byKey(WizardBottomBar.nextKey));
      await settle(t);
      expect(SocialNavB.postedNote, SocialStringsB.nearbyTomorrow);
      await drain(t);
    });

    testWidgets('UC3 server side: switch ON but the week was used on another phone: the server answers weekLimit, one call, the post is still published', (t) async {
      final server = installServer();
      putSocialMe(server, _me());
      server.on('POST', '/social/trips', {...publicTripJson(id: 'n1', isMine: true, cities: ['Manali']), 'notify': {'followers': 'weekLimit', 'nearby': 'weekLimit', 'used': 2, 'limit': 2}});
      await _toAbout(t);
      await t.tap(find.byKey(PostAboutStep.notifyKey));
      await settle(t);
      await t.tap(find.byKey(WizardBottomBar.nextKey));
      await settle(t);
      final calls = server.calls('POST', '/social/trips');
      expect(calls, hasLength(1));
      expect((calls.single.data as Map)['notifyNearby'], isTrue);
      expect(find.text('FEED posted=true'), findsOneWidget);
      expect(SocialNavB.postedNote, SocialStringsB.notifyUsedUpPosted);
      await drain(t);
    });

    testWidgets('abuse guard: a PublishLimit refusal shows the calm line with the day, the wizard stays', (t) async {
      final server = installServer();
      putSocialMe(server, _me());
      server.routes['POST /social/trips'] = (
        429,
        {
          'error': {'type': 'PublishLimit', 'message': 'Refused'},
          'data': {'nextAllowedAt': '2026-12-01T06:00:00Z'},
        }
      );
      await _toAbout(t);
      await t.tap(find.byKey(WizardBottomBar.nextKey));
      await settle(t);
      expect(find.textContaining('You have posted a lot this week. Try again on'), findsOneWidget);
      expect(find.text('FEED posted=true'), findsNothing);
      await drain(t);
    });
  });
}
