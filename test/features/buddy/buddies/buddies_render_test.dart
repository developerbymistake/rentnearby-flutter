import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_find_controller.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_summary_controller.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/buddies/screens/blocked_people_screen.dart';
import 'package:bakhli/features/buddy/buddies/screens/buddies_screen.dart';
import 'package:bakhli/features/buddy/buddies/widgets/buddies_header_menu.dart';
import 'package:bakhli/features/buddy/buddies/widgets/my_buddies_tab.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'buddies_fakes.dart';

late FakeBuddiesApi api;
late FakeTripMembersApi tripApi;

BuddiesScreen screen({String tab = 'buddies', String? query, String? source}) =>
    BuddiesScreen(tab: tab, query: query, source: source, api: api, tripApi: tripApi);

Future<void> step(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester t, String s) async {
  await t.tap(find.text(s).last);
  await step(t);
}

Future<void> render(WidgetTester t, String id, Widget w, {Future<void> Function(WidgetTester)? arrange}) async {
  final file = await renderFrame(t, id, w, arrange: arrange);
  expect(t.takeException(), isNull);
  expect(file.existsSync(), isTrue);
  await t.pump(const Duration(seconds: 6));
  BuddySnack.hide();
  await t.pump(const Duration(seconds: 1));
}

void listOf(List<BuddyItem> items) => api.buddiesResult = BuddyOk(BuddyList(items: items, count: items.length));

void foundAs(BuddyPerson p, BuddyRelation r, {String? requestId}) =>
    api.findResult = BuddyOk(FindResult(found: true, person: found(p, r, requestId: requestId)));

void received(BuddyPerson p, Duration ago, {bool withSent = true}) {
  api.receivedResult = BuddyOk(BuddyCursorPage(items: [ReceivedRequest(requestId: 'rq', person: p, createdAt: DateTime.now().toUtc().subtract(ago))]));
  api.sentResult = BuddyOk(BuddyCursorPage(
    items: withSent
        ? [
            SentRequest(requestId: 's1', person: vikram, state: 'waiting', expiresAt: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 14, 12), canCancel: true),
            SentRequest(requestId: 's2', person: karan, state: 'ended', canCancel: false),
          ]
        : [],
  ));
}

void summary(BuddySummary s) {
  Get.put(BuddySummaryController(api: api..summaryResult = BuddyOk(s)), permanent: true);
}

void main() {
  useBuddyRenderScale();

  setUp(() {
    Get.reset();
    BuddyFindController.debugResetRest();
    api = FakeBuddiesApi();
    tripApi = FakeTripMembersApi();
    putMe();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  testWidgets('1.3a', (t) async {
    summary(const BuddySummary(buddies: 2, blocked: 1));
    listOf([item(aman), item(neha)]);
    await render(t, '1.3a', screen(), arrange: (t) async {
      await t.tap(find.byKey(BuddiesHeaderMenu.dotsKey));
      await step(t);
    });
  });

  testWidgets('1.4', (t) async {
    api.blocksResult = BuddyOk(BlockedList(items: [BlockedPerson(userId: vikasId, name: 'Vikas', username: 'Bakhli#83720518', initial: 'V', blockedAt: DateTime(2026, 11, 12, 10))], count: 1));
    await render(t, '1.4', BlockedPeopleScreen(api: api));
  });

  testWidgets('2.1', (t) async => render(t, '2.1', screen()));

  testWidgets('2.2', (t) async => render(t, '2.2', screen(tab: 'find')));

  testWidgets('2.3', (t) async {
    foundAs(vikram, BuddyRelation.none);
    await render(t, '2.3', screen(query: 'Bakhli#29583047'));
  });

  testWidgets('2.3a', (t) async {
    foundAs(aman, BuddyRelation.buddy);
    await render(t, '2.3a', screen(query: 'Bakhli#61408275', source: 'Qr'));
  });

  testWidgets('2.3b', (t) async {
    foundAs(aman, BuddyRelation.requestedByMe, requestId: 'q');
    await render(t, '2.3b', screen(query: 'Bakhli#61408275', source: 'Qr'));
  });

  testWidgets('2.3c', (t) async {
    foundAs(aman, BuddyRelation.requestedMe, requestId: 'q');
    await render(t, '2.3c', screen(query: 'Bakhli#61408275', source: 'Qr'));
  });

  testWidgets('2.4', (t) async => render(t, '2.4', screen(query: 'Bakhli#29583074')));

  testWidgets('2.4a', (t) async {
    api.findResult = const BuddyOffline();
    await render(t, '2.4a', screen(query: 'Bakhli#29583047'));
  });

  testWidgets('2.5', (t) async {
    api.findResult = refused(429, BuddyErrorTypes.tooManyRequests, 600);
    await render(t, '2.5', screen(query: 'Bakhli#29583047'));
    await t.pump(const Duration(minutes: 11));
  });

  for (final c in <(String, BuddyResult<SendRequestResult>)>[
    ('2.6', const BuddyOk(SendRequestResult(state: 'pending', requestId: 'r'))),
    ('2.6a', refused(429, BuddyErrorTypes.tooManyRequests, 60)),
    ('2.6b', refused(409, BuddyErrorTypes.waitingLimit)),
  ]) {
    testWidgets(c.$1, (t) async {
      foundAs(vikram, BuddyRelation.none);
      api.sendResult = c.$2;
      await render(t, c.$1, screen(query: 'Bakhli#29583047'), arrange: (t) => tapText(t, 'Add buddy'));
    });
  }

  testWidgets('2.7', (t) async {
    summary(const BuddySummary(receivedPending: 1));
    received(neha, const Duration(hours: 2));
    await render(t, '2.7', screen(tab: 'requests'));
  });

  testWidgets('2.8', (t) async {
    summary(const BuddySummary(receivedPending: 1));
    received(neha, const Duration(hours: 2));
    await render(t, '2.8', screen(tab: 'requests'), arrange: (t) async {
      await t.tap(find.byType(BuddyDots).first);
      await step(t);
    });
  });

  for (final c in <(String, String)>[('2.8a', BuddyErrorTypes.buddyLimit), ('2.8b', BuddyErrorTypes.cannotAddNow)]) {
    testWidgets(c.$1, (t) async {
      summary(const BuddySummary(receivedPending: 1));
      received(neha, const Duration(hours: 2), withSent: false);
      api.acceptResult = refused(409, c.$2);
      await render(t, c.$1, screen(tab: 'requests'), arrange: (t) => tapText(t, 'Accept'));
    });
  }

  testWidgets('2.9', (t) async {
    received(neha, const Duration(hours: 2), withSent: false);
    listOf([item(aman), item(neha, isNew: true)]);
    await render(t, '2.9', screen(tab: 'requests'), arrange: (t) => tapText(t, 'Accept'));
  });

  testWidgets('2.10', (t) async {
    listOf([item(aman), item(neha, isNew: true)]);
    await render(t, '2.10', screen(), arrange: (t) => tapText(t, 'Aman'));
  });

  testWidgets('2.10a', (t) async {
    listOf([item(aman), item(neha)]);
    tripApi.optionsResult = BuddyOk(sampleOptions());
    await render(t, '2.10a', screen(), arrange: (t) async {
      await tapText(t, 'Aman');
      await tapText(t, 'Invite to a trip');
      await tapText(t, 'Goa Beach Trip');
    });
  });

  testWidgets('2.10b', (t) async {
    listOf([item(aman), item(neha)]);
    await render(t, '2.10b', screen(), arrange: (t) async {
      await tapText(t, 'Aman');
      await tapText(t, 'Invite to a trip');
    });
  });

  testWidgets('2.10c', (t) async {
    listOf([item(aman), item(neha)]);
    tripApi.optionsResult = BuddyOk(sampleOptions());
    await render(t, '2.10c', screen(), arrange: (t) async {
      await tapText(t, 'Aman');
      await tapText(t, 'Invite to a trip');
      await tapText(t, 'Goa Beach Trip');
      await tapText(t, 'Send invite');
    });
  });

  testWidgets('2.11', (t) async {
    summary(const BuddySummary(receivedPending: 1));
    received(vikas, const Duration(minutes: 5), withSent: false);
    await render(t, '2.11', screen(tab: 'requests'), arrange: (t) async {
      await t.tap(find.byType(BuddyDots).first);
      await step(t);
      await tapText(t, 'Block Vikas');
      await tapText(t, 'Also report');
    });
  });

  testWidgets('2.11a', (t) async {
    listOf([item(aman), item(vikas)]);
    api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'Uttarakhand Hills Trip', myRole: 'Owner')]));
    await render(t, '2.11a', screen(), arrange: (t) async {
      await tapText(t, 'Vikas');
      await tapText(t, 'Block');
    });
  });

  testWidgets('2.11b', (t) async {
    final a = Get.find<AuthController>();
    a.profileName.value = 'Aman';
    a.user.value = UserModel(id: amanId, phoneNumber: '9', isPhoneVerified: true, name: 'Aman', username: 'Bakhli#61408275', createdAt: DateTime(2026), roleConfirmed: true);
    listOf([item(rahul), item(priya)]);
    api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'Uttarakhand Hills Trip', myRole: 'Viewer')]));
    await render(t, '2.11b', screen(), arrange: (t) async {
      await tapText(t, 'Rahul');
      await tapText(t, 'Block');
    });
  });

  testWidgets('1.2 Profile Buddies row', (t) async {
    final p = Get.put(PlanController());
    p.myPlan.value = MyPlanModel(paymentEnabled: false);
    final a = Get.find<AuthController>();
    a.profileName.value = 'Rahul Mehra';
    a.profilePhone.value = '9876543210';
    a.profilePhoneVerified.value = true;
    summary(const BuddySummary(receivedPending: 1, buddies: 2));
    await render(t, '1.2', const ProfileScreen());
  });
}
