import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_summary_controller.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/buddies/screens/blocked_people_screen.dart';
import 'package:bakhli/features/buddy/buddies/widgets/block_dialog.dart';
import 'package:bakhli/features/buddy/buddies/widgets/profile_buddies_row.dart';
import 'package:bakhli/features/buddy/buddies/widgets/report_sheet.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'buddies_fakes.dart';

// The unreachable Buddies screen is gone; its live block and report boxes are tested on their own.

late FakeBuddiesApi api;

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

final results = <Object?>[];

Widget blockHost(BuddyPerson p, {String contextName = BuddyContext.buddy}) => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () async => results.add(await BlockDialog.show(c, person: p, contextName: contextName, api: api)),
            child: const Text('open'),
          ),
        ),
      ),
    );

Widget reportHost(BuddyPerson p, {String contextName = BuddyContext.buddy}) => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () async => results.add(await ReportDialog.show(c, person: p, contextName: contextName, api: api)),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  useBuddyRenderScale();

  setUp(() {
    Get.reset();
    results.clear();
    api = FakeBuddiesApi();
    putMe();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  group('Block box', () {
    testWidgets('2.11a owner trip line, Cancel returns false', (t) async {
      api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'Uttarakhand Hills Trip', myRole: 'Owner')]));
      await pump(t, blockHost(vikas));
      await tapText(t, 'open');
      expect(find.text('Block Vikas?'), findsOneWidget);
      expect(find.text('Vikas is still on your Uttarakhand Hills Trip. Remove him in Travellers.'), findsOneWidget);
      expect(find.text('Also report'), findsOneWidget);
      expect(find.text('Spam'), findsNothing);
      await tapText(t, 'Cancel');
      expect(results, [false]);
      await finish(t);
    });

    testWidgets('2.11b viewer trip line, block without a report', (t) async {
      api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'X', myRole: 'Viewer')]));
      await pump(t, blockHost(aman));
      await tapText(t, 'open');
      expect(find.text("You are still on Aman's trip. Leave it in Travellers."), findsOneWidget);
      await tapText(t, 'Block');
      expect(api.calls, contains('block:$amanId'));
      expect(api.lastAlsoReport, isNull);
      expect(api.lastContext, 'Buddy');
      expect(results.last, isTrue);
      await finish(t);
    });

    testWidgets('Also report shows the reasons and sends the picked one', (t) async {
      await pump(t, blockHost(neha, contextName: BuddyContext.joinReq));
      await tapText(t, 'open');
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
      expect(api.lastContext, BuddyContext.joinReq);
      expect(results.last, isTrue);
      await finish(t);
    });

    testWidgets('refused TooManyBlocks keeps the box open with the red line', (t) async {
      api.blockResult = refused(409, BuddyErrorTypes.tooManyBlocks);
      await pump(t, blockHost(neha));
      await tapText(t, 'open');
      await tapText(t, 'Block');
      expect(find.text('You have blocked too many people.'), findsOneWidget);
      expect(find.text('Block Neha?'), findsOneWidget);
      await tapText(t, 'Cancel');
      expect(find.text('Block Neha?'), findsNothing);
      expect(results, [false]);
      await finish(t);
    });

    testWidgets('reasons unavailable: tick row hidden, block still works', (t) async {
      api.reasonsResult = const BuddyOffline();
      await pump(t, blockHost(aman));
      await tapText(t, 'open');
      expect(find.text('Also report'), findsNothing);
      await tapText(t, 'Block');
      expect(api.calls, contains('block:$amanId'));
      expect(results.last, isTrue);
      await finish(t);
    });
  });

  group('Report box', () {
    testWidgets('report-only form: Also block ticked, Other asks for a note', (t) async {
      await pump(t, reportHost(neha));
      await tapText(t, 'open');
      expect(find.text('Report Neha?'), findsOneWidget);
      expect(find.text('The report goes to the app team.'), findsOneWidget);
      expect(find.text('Also block'), findsOneWidget);
      await tapText(t, 'Other');
      expect(find.text('Tell us what happened'), findsOneWidget);
      await t.tap(find.text('Report').last);
      await settle(t);
      expect(api.calls, contains('report:$nehaId:r4'));
      expect(api.lastAlsoBlock, isTrue);
      expect(results.last, ReportOutcome.reportedAndBlocked);
      await finish(t);
    });
  });

  group('Blocked people', () {
    testWidgets('1.4 the list shows the blocked line and the note', (t) async {
      api.blocksResult = BuddyOk(BlockedList(items: [BlockedPerson(userId: vikasId, name: 'Vikas', username: 'Bakhli#83720518', initial: 'V', blockedAt: DateTime(2026, 11, 12, 10))], count: 1));
      await pump(t, BlockedPeopleScreen(api: api));
      expect(find.text('Blocked people'), findsOneWidget);
      expect(find.text('1 person'), findsOneWidget);
      expect(find.text('Bakhli#83720518 · Blocked 12 Nov'), findsOneWidget);
      expect(find.text('They cannot find you, send you a request or invite you.'), findsOneWidget);
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

    testWidgets('row badge and tap opens People on Requests', (t) async {
      Get.put(BuddySummaryController(api: api..summaryResult = const BuddyOk(BuddySummary(receivedPending: 1, buddies: 2))), permanent: true);
      Map<dynamic, dynamic>? args;
      await pump(t, const Scaffold(body: Column(children: [ProfileBuddiesRow()])), pages: [
        GetPage(name: AppRoutes.people, page: () {
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

    testWidgets('Bug 8: row with no pending request opens People on My Buddies', (t) async {
      Get.put(BuddySummaryController(api: api..summaryResult = const BuddyOk(BuddySummary(buddies: 2))), permanent: true);
      Map<dynamic, dynamic>? args;
      await pump(t, const Scaffold(body: Column(children: [ProfileBuddiesRow()])), pages: [
        GetPage(name: AppRoutes.people, page: () {
          args = Get.arguments as Map?;
          return const Scaffold();
        }),
      ]);
      await t.tap(find.text('Buddies'));
      await t.pumpAndSettle();
      expect(args?['tab'], 'buddies');
    });
  });
}
