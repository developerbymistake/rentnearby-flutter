import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_find_controller.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_summary_controller.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/buddies/screens/blocked_people_screen.dart';
import 'package:bakhli/features/buddy/buddies/screens/buddies_screen.dart';
import 'package:bakhli/features/buddy/buddies/widgets/buddies_header_menu.dart';
import 'package:bakhli/features/buddy/buddies/widgets/my_buddies_tab.dart';
import 'package:bakhli/features/buddy/buddies/widgets/find_tab.dart';
import 'package:bakhli/features/buddy/buddies/widgets/profile_buddies_row.dart';
import 'package:bakhli/features/buddy/buddies/widgets/trip_pick_sheet.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'buddies_fakes.dart';

late FakeBuddiesApi api;
late FakeTripMembersApi tripApi;

Future<void> pump(WidgetTester t, Widget home, {List<GetPage<dynamic>> pages = const []}) async {
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(392 * 2, 860 * 2);
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    home: home,
    getPages: pages,
    builder: (c, child) => Stack(fit: StackFit.expand, children: [Positioned.fill(child: child!), Overlay(key: AppToast.overlayKey)]),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> finish(WidgetTester t) async {
  await t.pump(const Duration(seconds: 6));
  BuddySnack.hide();
  await t.pump(const Duration(seconds: 1));
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await settle(t);
}

BuddiesScreen screen({String tab = 'buddies', String? query, String? source}) =>
    BuddiesScreen(tab: tab, query: query, source: source, api: api, tripApi: tripApi);

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

  group('My buddies', () {
    testWidgets('2.1 empty: panda state, username card, Copy, Find a buddy opens Find', (t) async {
      await pump(t, screen());
      expect(find.text('No buddies yet'), findsOneWidget);
      expect(find.text('Find a friend by their username'), findsOneWidget);
      expect(find.text('Your username'), findsOneWidget);
      expect(find.text('Bakhli#48291736'), findsOneWidget);
      expect(find.text('Made by the app. It cannot be changed.'), findsOneWidget);
      expect(find.text('My buddies'), findsOneWidget);
      await tapText(t, 'Copy');
      expect(find.text('Username copied'), findsOneWidget);
      await tapText(t, 'Find a buddy');
      expect(find.text('Type a username'), findsOneWidget);
      expect(find.text('OR SHOW YOURS'), findsOneWidget);
      expect(find.text('Find a buddy'), findsNothing);
      await finish(t);
    });

    testWidgets('2.9 list: count label, New badge, seen marked after 2 s', (t) async {
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman), item(neha, isNew: true)], count: 2));
      await pump(t, screen());
      expect(find.text('My buddies 2'), findsOneWidget);
      expect(find.text('2 BUDDIES'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(api.seen, isNull);
      await t.pump(const Duration(seconds: 3));
      expect(api.seen, [nehaId]);
      expect(find.text('New'), findsOneWidget);
      await finish(t);
    });

    testWidgets('load failure shows Could not load + Retry, never empty', (t) async {
      api.buddiesResult = const BuddyOffline();
      await pump(t, screen());
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('No buddies yet'), findsNothing);
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman)], count: 1));
      await tapText(t, 'Retry');
      expect(find.text('1 BUDDY'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.10 buddy menu rows and Remove with confirm', (t) async {
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman), item(neha)], count: 2));
      await pump(t, screen());
      await tapText(t, 'Aman');
      for (final s in ['Invite to a trip', 'Pick one of your trips', 'Remove buddy', 'Trips you share stay as they are', 'Block', 'Report', 'Bakhli#61408275']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      await tapText(t, 'Remove buddy');
      expect(find.text('Remove Aman?'), findsOneWidget);
      expect(find.text('Trips you share stay as they are.'), findsOneWidget);
      await tapText(t, 'Remove');
      expect(api.calls, contains('remove:$amanId'));
      expect(find.text('Aman removed'), findsOneWidget);
      expect(find.text('1 BUDDY'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.10a-c invite: tagged rows locked, pick, send, snack', (t) async {
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman)], count: 1));
      tripApi.optionsResult = BuddyOk(sampleOptions());
      await pump(t, screen());
      await tapText(t, 'Aman');
      await tapText(t, 'Invite to a trip');
      expect(find.text('Invite Aman to a trip'), findsOneWidget);
      expect(find.text('They join as a viewer after they accept.'), findsOneWidget);
      expect(find.text('2 – 6 Jun · 2 of 12'), findsOneWidget);
      expect(find.text('Draft · 4 days · 1 of 12'), findsOneWidget);
      expect(find.text('16 – 22 May'), findsOneWidget);
      expect(find.text('On this trip'), findsOneWidget);
      expect(find.text('Invite sent'), findsOneWidget);
      expect(find.text('20 – 25 Jun · 12 of 12'), findsOneWidget);
      expect(find.text('Trip is full'), findsOneWidget);
      await tapText(t, 'Send invite');
      expect(tripApi.invites, isEmpty);
      await tapText(t, 'Kerala Backwaters Trip');
      await tapText(t, 'Send invite');
      expect(tripApi.invites, isEmpty);
      await tapText(t, 'Goa Beach Trip');
      await tapText(t, 'Send invite');
      expect(tripApi.invites, ['t1']);
      expect(find.text('Invite sent to Aman'), findsOneWidget);
      expect(find.text('Send invite'), findsNothing);
      await finish(t);
    });

    testWidgets('2.10b no trips: No trips yet, Plan a trip, no Send invite', (t) async {
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman)], count: 1));
      await pump(t, screen());
      await tapText(t, 'Aman');
      await tapText(t, 'Invite to a trip');
      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Plan a trip first.'), findsOneWidget);
      expect(find.text('Plan a trip'), findsOneWidget);
      expect(find.text('Send invite'), findsNothing);
      await finish(t);
    });

    testWidgets('invite outcome AlreadyOnTrip toasts and keeps the sheet', (t) async {
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman)], count: 1));
      tripApi.optionsResult = BuddyOk(sampleOptions());
      tripApi.inviteResult = BuddyOk(InviteResult(results: [InviteOutcome(userId: amanId, outcome: InviteOutcomes.alreadyOnTrip)], seatsLeft: 1));
      await pump(t, screen());
      await tapText(t, 'Aman');
      await tapText(t, 'Invite to a trip');
      await tapText(t, 'Goa Beach Trip');
      await tapText(t, 'Send invite');
      expect(find.text('Aman is already on this trip'), findsOneWidget);
      await finish(t);
    });
  });

  group('Find', () {
    testWidgets('2.2 idle, 2.4 bad text without a server call, prefix fixed', (t) async {
      await pump(t, screen(tab: 'find'));
      expect(find.text('Ask your friend for their username, or scan their QR'), findsOneWidget);
      expect(find.text('My QR'), findsOneWidget);
      await t.enterText(find.byKey(FindSearchRow.fieldKey), 'hello');
      await t.tap(find.byKey(FindSearchRow.searchKey));
      await settle(t);
      expect(find.text('No one found'), findsOneWidget);
      expect(find.text('Check the username and try again'), findsOneWidget);
      expect(api.calls.where((c) => c.startsWith('find')), isEmpty);
      await t.enterText(find.byKey(FindSearchRow.fieldKey), ' BAKHLI#29583047 ');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await settle(t);
      expect(api.calls, contains('find:Bakhli#29583047'));
      expect(api.sources.last, 'Search');
      expect(find.text('No one found'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.3 + 2.6 add, requested, cancel back to Add buddy', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(vikram, BuddyRelation.none)));
      await pump(t, screen(query: 'Bakhli#29583047'));
      expect(find.text('1 PERSON FOUND'), findsOneWidget);
      expect(find.text('Vikram'), findsOneWidget);
      await tapText(t, 'Add buddy');
      expect(api.calls, contains('send:$vikramId'));
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
      expect(find.text('Request sent to Vikram'), findsOneWidget);
      await tapText(t, 'Cancel request');
      expect(api.calls, contains('cancel:req-new'));
      expect(find.text('Add buddy'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.6 crossing request: accepted at once', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(vikram, BuddyRelation.none)));
      api.sendResult = const BuddyOk(SendRequestResult(state: 'accepted'));
      await pump(t, screen(query: 'Bakhli#29583047'));
      await tapText(t, 'Add buddy');
      expect(find.text('Your buddy'), findsOneWidget);
      expect(find.text('Vikram is now your buddy'), findsOneWidget);
      await finish(t);
    });

    for (final c in <(String, BuddyResult<SendRequestResult>, String)>[
      ('2.6a', refused(429, BuddyErrorTypes.tooManyRequests, 60), 'You have sent 10 requests today. Try again tomorrow.'),
      ('2.6b', refused(409, BuddyErrorTypes.waitingLimit), 'You have 20 requests waiting. Cancel one to send more.'),
      ('2.8a', refused(409, BuddyErrorTypes.buddyLimit), 'You have 500 buddies. Remove one to add more.'),
      ('2.8b', refused(409, BuddyErrorTypes.cannotAddNow), 'Could not add this buddy right now.'),
      ('hold', refused(403, BuddyErrorTypes.buddyRequestsOnHold), 'You cannot send requests right now.'),
      ('self', refused(400, BuddyErrorTypes.selfRequest), 'You cannot add yourself.'),
    ]) {
      testWidgets('${c.$1} add refused: red snack, card stays', (t) async {
        api.findResult = BuddyOk(FindResult(found: true, person: found(vikram, BuddyRelation.none)));
        api.sendResult = c.$2;
        await pump(t, screen(query: 'Bakhli#29583047'));
        await tapText(t, 'Add buddy');
        expect(find.text(c.$3), findsOneWidget);
        expect(find.text('!'), findsOneWidget);
        expect(find.text('Add buddy'), findsOneWidget);
        await finish(t);
      });
    }

    testWidgets('TryLater turns the card into the grey cooldown badge', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(vikram, BuddyRelation.none)));
      api.sendResult = refused(409, BuddyErrorTypes.tryLater);
      await pump(t, screen(query: 'Bakhli#29583047'));
      await tapText(t, 'Add buddy');
      expect(find.text('You can send again later'), findsOneWidget);
      expect(find.text('Add buddy'), findsNothing);
      await finish(t);
    });

    testWidgets('offline add keeps the same clientRequestId for the retry', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(vikram, BuddyRelation.none)));
      api.sendResult = const BuddyOffline();
      await pump(t, screen(query: 'Bakhli#29583047'));
      await tapText(t, 'Add buddy');
      expect(find.text('You are offline. Try again when you are back online.'), findsOneWidget);
      api.sendResult = const BuddyOk(SendRequestResult(state: 'pending', requestId: 'r9'));
      await tapText(t, 'Add buddy');
      expect(api.requestIds.length, 2);
      expect(api.requestIds[0], api.requestIds[1]);
      await finish(t);
    });

    testWidgets('2.3a buddy badge opens the buddy menu; 2.3b request sent badge', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(aman, BuddyRelation.buddy)));
      await pump(t, screen(query: 'Bakhli#61408275', source: 'Qr'));
      expect(api.sources.last, 'Qr');
      expect(find.text('Your buddy'), findsOneWidget);
      expect(find.text('Add buddy'), findsNothing);
      await tapText(t, 'Aman');
      expect(find.text('Invite to a trip'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.3b request sent: badge, no button', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(aman, BuddyRelation.requestedByMe, requestId: 'q1')));
      await pump(t, screen(query: 'Bakhli#61408275'));
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.text('Cancel request'), findsNothing);
      expect(find.text('Add buddy'), findsNothing);
      await finish(t);
    });

    testWidgets('2.3c they asked you: Accept makes you buddies', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(aman, BuddyRelation.requestedMe, requestId: 'q2')));
      await pump(t, screen(query: 'Bakhli#61408275'));
      expect(find.text('Decline'), findsNothing);
      await tapText(t, 'Accept');
      expect(api.calls, contains('accept:q2'));
      expect(find.text('Your buddy'), findsOneWidget);
      expect(find.text('Aman is now your buddy'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.3c accept refused with BuddyLimit shows the 2.8a line', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(aman, BuddyRelation.requestedMe, requestId: 'q2')));
      api.acceptResult = refused(409, BuddyErrorTypes.buddyLimit);
      await pump(t, screen(query: 'Bakhli#61408275'));
      await tapText(t, 'Accept');
      expect(find.text('You have 500 buddies. Remove one to add more.'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      await finish(t);
    });

    testWidgets('own username shows the self line', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(rahul, BuddyRelation.self)));
      await pump(t, screen(query: 'Bakhli#48291736'));
      expect(find.text('This is your own username.'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.4a search failed: Try again repeats with the same source', (t) async {
      api.findResult = const BuddyOffline();
      await pump(t, screen(query: 'Bakhli#29583047', source: 'Qr'));
      expect(find.text('Could not search'), findsOneWidget);
      expect(find.text('Check your network and try again.'), findsOneWidget);
      expect(find.text('No one found'), findsNothing);
      expect(find.text('Bakhli#29583047'), findsOneWidget);
      await tapText(t, 'Try again');
      expect(api.sources, ['Qr', 'Qr']);
      await finish(t);
    });

    testWidgets('2.5 too many tries: box and scan off, rest kept on reopen', (t) async {
      api.findResult = refused(429, BuddyErrorTypes.tooManyRequests, 600);
      await pump(t, screen(query: 'Bakhli#29583047'));
      expect(find.text('Too many tries'), findsOneWidget);
      expect(find.text('Please try again in a few minutes'), findsOneWidget);
      expect(find.text('Type a username'), findsOneWidget);
      final field = t.widget<TextField>(find.byKey(FindSearchRow.fieldKey));
      expect(field.enabled, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
      await pump(t, screen(tab: 'find'));
      expect(find.text('Too many tries'), findsOneWidget);
      await t.pump(const Duration(minutes: 11));
      expect(find.text('Too many tries'), findsNothing);
      await finish(t);
    });

    testWidgets('scan button returns a username and searches with source Qr', (t) async {
      api.findResult = BuddyOk(FindResult(found: true, person: found(vikram, BuddyRelation.none)));
      await pump(t, screen(tab: 'find'), pages: [
        GetPage(name: AppRoutes.buddyScan, page: () => Scaffold(body: TextButton(onPressed: () => Get.back(result: 'Bakhli#29583047'), child: const Text('scan-done')))),
      ]);
      await t.tap(find.byKey(FindSearchRow.scanKey));
      await t.pumpAndSettle();
      await t.tap(find.text('scan-done'));
      await t.pumpAndSettle();
      expect(api.sources.last, 'Qr');
      expect(find.text('Vikram'), findsOneWidget);
      await finish(t);
    });
  });

  group('Requests', () {
    void seed() {
      api.receivedResult = BuddyOk(BuddyCursorPage(items: [
        ReceivedRequest(requestId: 'rq1', person: neha, createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 2))),
      ]));
      api.sentResult = BuddyOk(BuddyCursorPage(items: [
        SentRequest(requestId: 'sq1', person: vikram, state: 'waiting', expiresAt: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 14, 12), canCancel: true),
        SentRequest(requestId: 'sq2', person: karan, state: 'ended', canCancel: false),
      ]));
    }

    testWidgets('2.7 sections, lines, decline, cancel', (t) async {
      seed();
      await pump(t, screen(tab: 'requests'));
      for (final s in ['RECEIVED', 'SENT, WAITING', 'Neha', '2 h ago', 'Expires in 14 days', 'You can send again later', 'Ended', 'Cancel', 'Decline', 'Accept']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      await tapText(t, 'Decline');
      expect(api.calls, contains('decline:rq1'));
      expect(find.text('RECEIVED'), findsNothing);
      await tapText(t, 'Cancel');
      expect(api.calls, contains('cancel:sq1'));
      expect(find.text('Vikram'), findsNothing);
      await finish(t);
    });

    testWidgets('2.7 accept moves to My buddies with the snack', (t) async {
      seed();
      await pump(t, screen(tab: 'requests'));
      api.buddiesResult = BuddyOk(BuddyList(items: [item(neha, isNew: true)], count: 1));
      await tapText(t, 'Accept');
      expect(api.calls, contains('accept:rq1'));
      expect(find.text('Neha is now your buddy'), findsOneWidget);
      expect(find.text('1 BUDDY'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.8a/2.8b accept refused keeps the request; RequestEnded removes it', (t) async {
      seed();
      api.acceptResult = refused(409, BuddyErrorTypes.cannotAddNow);
      await pump(t, screen(tab: 'requests'));
      await tapText(t, 'Accept');
      expect(find.text('Could not add this buddy right now.'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);
      api.acceptResult = refused(404, BuddyErrorTypes.requestEnded);
      await tapText(t, 'Accept');
      expect(find.text('Neha'), findsNothing);
      expect(find.text('This request is no longer open.'), findsOneWidget);
      await finish(t);
    });

    testWidgets('both empty shows No requests yet', (t) async {
      await pump(t, screen(tab: 'requests'));
      expect(find.text('No requests yet'), findsOneWidget);
      expect(find.text('Requests you get and send show here'), findsOneWidget);
      await finish(t);
    });

    testWidgets('2.8 + 2.11 request menu, block with report reason', (t) async {
      seed();
      await pump(t, screen(tab: 'requests'));
      await t.tap(find.byType(BuddyDots).first);
      await settle(t);
      expect(find.text('Block Neha'), findsOneWidget);
      expect(find.text('They will not be told'), findsOneWidget);
      expect(find.text('Spam, harassment or a fake account'), findsOneWidget);
      await tapText(t, 'Block Neha');
      expect(find.text('Block Neha?'), findsOneWidget);
      expect(find.text('They will not be told. They cannot find you or invite you.'), findsOneWidget);
      expect(find.text('Spam'), findsNothing);
      await tapText(t, 'Also report');
      for (final s in ['Spam', 'Harassment', 'Fake account', 'Other']) {
        expect(find.text(s), findsOneWidget);
      }
      await tapText(t, 'Harassment');
      await tapText(t, 'Block');
      expect(api.calls, contains('block:$nehaId'));
      expect(api.lastAlsoReport?.reasonId, 'r2');
      expect(api.lastContext, 'Request');
      expect(find.text('Neha blocked'), findsOneWidget);
      expect(find.text('RECEIVED'), findsNothing);
      await finish(t);
    });

    testWidgets('block refused TooManyBlocks keeps the box open with the red line', (t) async {
      seed();
      api.blockResult = refused(409, BuddyErrorTypes.tooManyBlocks);
      await pump(t, screen(tab: 'requests'));
      await t.tap(find.byType(BuddyDots).first);
      await settle(t);
      await tapText(t, 'Block Neha');
      await tapText(t, 'Block');
      expect(find.text('You have blocked too many people.'), findsOneWidget);
      expect(find.text('Block Neha?'), findsOneWidget);
      await tapText(t, 'Cancel');
      expect(find.text('Block Neha?'), findsNothing);
      expect(find.text('Neha'), findsOneWidget);
      await finish(t);
    });

    testWidgets('report-only form: Also block ticked, Report sent', (t) async {
      seed();
      await pump(t, screen(tab: 'requests'));
      await t.tap(find.byType(BuddyDots).first);
      await settle(t);
      await tapText(t, 'Report');
      expect(find.text('Report Neha?'), findsOneWidget);
      expect(find.text('The report goes to the app team.'), findsOneWidget);
      expect(find.text('Also block'), findsOneWidget);
      await tapText(t, 'Other');
      expect(find.text('Tell us what happened'), findsOneWidget);
      await t.tap(find.text('Report').last);
      await settle(t);
      expect(api.calls, contains('report:$nehaId:r4'));
      expect(api.lastAlsoBlock, isTrue);
      expect(find.text('Report sent'), findsOneWidget);
      expect(find.text('RECEIVED'), findsNothing);
      await finish(t);
    });
  });

  group('Block trip lines', () {
    testWidgets('2.11a owner trip line, 2.11b viewer trip line', (t) async {
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman), item(vikas)], count: 2));
      api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'Uttarakhand Hills Trip', myRole: 'Owner')]));
      await pump(t, screen());
      await tapText(t, 'Vikas');
      await tapText(t, 'Block');
      expect(find.text('Vikas is still on your Uttarakhand Hills Trip. Remove him in Travellers.'), findsOneWidget);
      expect(find.text('Also report'), findsOneWidget);
      expect(find.text('Spam'), findsNothing);
      await tapText(t, 'Cancel');
      api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'X', myRole: 'Viewer')]));
      await tapText(t, 'Aman');
      await tapText(t, 'Block');
      expect(find.text("You are still on Aman's trip. Leave it in Travellers."), findsOneWidget);
      await tapText(t, 'Block');
      expect(api.lastAlsoReport, isNull);
      expect(api.lastContext, 'Buddy');
      expect(find.text('Aman blocked'), findsOneWidget);
      await finish(t);
    });

    testWidgets('reasons unavailable: tick row hidden, block still works', (t) async {
      api.buddiesResult = BuddyOk(BuddyList(items: [item(aman)], count: 1));
      api.reasonsResult = const BuddyOffline();
      await pump(t, screen());
      await tapText(t, 'Aman');
      await tapText(t, 'Block');
      expect(find.text('Also report'), findsNothing);
      await tapText(t, 'Block');
      expect(api.calls, contains('block:$amanId'));
      await finish(t);
    });
  });

  group('Header menu and Blocked people', () {
    testWidgets('1.3a popup row opens Blocked people', (t) async {
      Get.put(BuddySummaryController(api: api..summaryResult = const BuddyOk(BuddySummary(blocked: 1, buddies: 0))), permanent: true);
      api.blocksResult = BuddyOk(BlockedList(items: [BlockedPerson(userId: vikasId, name: 'Vikas', username: 'Bakhli#83720518', initial: 'V', blockedAt: DateTime(2026, 11, 12, 10))], count: 1));
      await pump(t, screen(), pages: [GetPage(name: AppRoutes.buddiesBlocked, page: () => BlockedPeopleScreen(api: api))]);
      await t.tap(find.byKey(BuddiesHeaderMenu.dotsKey));
      await settle(t);
      expect(find.text('Blocked people'), findsOneWidget);
      expect(find.text('1 person'), findsOneWidget);
      await t.tap(find.byKey(BuddiesHeaderMenu.rowKey));
      await t.pumpAndSettle();
      expect(find.text('Bakhli#83720518 · Blocked 12 Nov'), findsOneWidget);
      expect(find.text('They cannot find you, send you a request or invite you.'), findsOneWidget);
      await finish(t);
    });

    testWidgets('1.3a tap outside closes the popup', (t) async {
      await pump(t, screen());
      await t.tap(find.byKey(BuddiesHeaderMenu.dotsKey));
      await settle(t);
      expect(find.byKey(BuddiesHeaderMenu.rowKey), findsOneWidget);
      expect(find.text('1 person'), findsNothing);
      await t.tapAt(const Offset(40, 700));
      await settle(t);
      expect(find.byKey(BuddiesHeaderMenu.rowKey), findsNothing);
      await finish(t);
    });

    testWidgets('1.4 unblock removes the row; empty shows No one blocked', (t) async {
      api.blocksResult = BuddyOk(BlockedList(items: [BlockedPerson(userId: vikasId, name: 'Vikas', username: 'Bakhli#83720518', initial: 'V', blockedAt: DateTime(2026, 11, 12, 10))], count: 1));
      await pump(t, BlockedPeopleScreen(api: api));
      expect(find.text('1 person'), findsOneWidget);
      await tapText(t, 'Unblock');
      expect(api.calls, contains('unblock:$vikasId'));
      expect(find.text('Vikas'), findsNothing);
      expect(find.text('No one blocked'), findsOneWidget);
      expect(find.text('1 person'), findsNothing);
      expect(find.text('They cannot find you, send you a request or invite you.'), findsNothing);
      await finish(t);
    });

    testWidgets('1.4 unblock offline keeps the row', (t) async {
      api.blocksResult = BuddyOk(BlockedList(items: [BlockedPerson(userId: vikasId, name: 'Vikas', username: 'Bakhli#83720518', initial: 'V')], count: 1));
      api.unblockResult = const BuddyOffline();
      await pump(t, BlockedPeopleScreen(api: api));
      await tapText(t, 'Unblock');
      expect(find.text('Vikas'), findsOneWidget);
      expect(find.text('You are offline. Try again when you are back online.'), findsOneWidget);
      await finish(t);
    });
  });

  group('Profile row and counts', () {
    test('subtitle rules', () {
      expect(ProfileBuddiesRow.subtitleOf(const BuddySummary(receivedPending: 1, buddies: 4)), '1 new request');
      expect(ProfileBuddiesRow.subtitleOf(const BuddySummary(receivedPending: 3)), '3 new requests');
      expect(ProfileBuddiesRow.subtitleOf(const BuddySummary(buddies: 1)), '1 buddy');
      expect(ProfileBuddiesRow.subtitleOf(const BuddySummary(buddies: 7)), '7 buddies');
      expect(ProfileBuddiesRow.subtitleOf(const BuddySummary()), 'Friends you travel with');
    });

    testWidgets('row badge and tap opens Requests', (t) async {
      Get.put(BuddySummaryController(api: api..summaryResult = const BuddyOk(BuddySummary(receivedPending: 1, buddies: 2))), permanent: true);
      Map<dynamic, dynamic>? args;
      await pump(t, const Scaffold(body: Column(children: [ProfileBuddiesRow()])), pages: [
        GetPage(name: AppRoutes.buddies, page: () {
          args = Get.arguments as Map?;
          return const Scaffold();
        }),
      ]);
      expect(find.text('Buddies'), findsOneWidget);
      expect(find.text('1 new request'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await t.tap(find.text('Buddies'));
      await t.pumpAndSettle();
      expect(args?['tab'], 'requests');
    });

    testWidgets('Requests tab count from the summary', (t) async {
      Get.put(BuddySummaryController(api: api..summaryResult = const BuddyOk(BuddySummary(receivedPending: 1))), permanent: true);
      await pump(t, screen());
      expect(find.text('1'), findsOneWidget);
      await finish(t);
    });
  });

  test('trip line format and art', () {
    final o = sampleOptions();
    expect(TripPickSheet.line(o[0]), '2 – 6 Jun · 2 of 12');
    expect(TripPickSheet.line(o[1]), 'Draft · 4 days · 1 of 12');
    expect(TripPickSheet.line(o[2]), '16 – 22 May');
    expect(TripPickSheet.line(o[3]), '8 – 11 Jun');
    expect(TripPickSheet.line(o[4]), '20 – 25 Jun · 12 of 12');
    expect(TripPickArt.of('Something'), endsWith('luggage.png'));
    expect(TripPickArt.of('Goa Beach Trip'), endsWith('beach_with_umbrella.png'));
  });

  test('username normalize', () {
    expect(BuddyUsername.normalize('  bakhli#12345678 '), 'Bakhli#12345678');
    expect(BuddyUsername.isValid('Bakhli#12345678'), isTrue);
    expect(BuddyUsername.isValid('Bakhli#1234567'), isFalse);
  });

  test('find controller rest survives a new controller until it ends', () async {
    var now = DateTime(2026, 1, 1, 10);
    final a = BuddyFindController(api: api..findResult = refused(429, null, 120), clock: () => now);
    a.onInit();
    await a.search(raw: 'Bakhli#12345678');
    expect(a.state.value, FindState.limited);
    final b = BuddyFindController(api: api, clock: () => now);
    b.onInit();
    expect(b.state.value, FindState.limited);
    now = now.add(const Duration(minutes: 3));
    final c = BuddyFindController(api: api, clock: () => now);
    c.onInit();
    expect(c.state.value, FindState.idle);
    a.onClose();
    b.onClose();
    c.onClose();
  });
}
