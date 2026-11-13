import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_shortlist_review.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo implements TripShortlistRepository {
  final removed = <String>[];

  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: []);

  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];

  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async => removed.add(listingId);

  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}

  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 0, closedShortlist: 0);
}

class _Enquiry extends TripEnquiryController {
  TripEnquiryBatch? reply;
  String? type;
  int? minutes;

  @override
  Future<TripEnquiryBatch?> sendEnquiry({
    required int day,
    required List<String> stayIds,
    required int nights,
    String? clientRequestId,
    String? stepKey,
  }) async {
    lastErrorType = type;
    lastRetryAfterMinutes = minutes;
    return reply;
  }

  @override
  Future<TripEnquiryBatch?> sendLead({
    required List<int> days,
    required List<String> taxiIds,
    String? pickupTime,
    String? pickupPlace,
    String? clientRequestId,
    String? stepKey,
  }) async {
    lastErrorType = type;
    lastRetryAfterMinutes = minutes;
    return reply;
  }
}

ShortlistItem _item(String id, {String step = 'stay:1'}) =>
    ShortlistItem(stepKey: step, kind: 'Stay', listingId: id, name: 'Name $id');

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  late List<String> toasts;
  late _Repo repo;
  late _Enquiry enquiry;
  late TripShortlistController c;

  setUp(() {
    Get.testMode = true;
    toasts = [];
    repo = _Repo();
    enquiry = _Enquiry();
    Get.put<TripEnquiryController>(enquiry);
    c = TripShortlistController(repo: repo, tripId: () async => 't1', offline: () => false, warn: toasts.add);
    Get.put(c);
  });

  tearDown(Get.reset);

  group('SB1 other-trip rows', () {
    test('OpenInAnotherTrip is not ok, not sent, labelled and kept on the card', () async {
      c.items.addAll([_item('a'), _item('b')]);
      enquiry.reply = const TripEnquiryBatch(items: [], skipped: [
        TripSkipped(listingId: 'a', reason: TripSkipReasons.openInAnotherTrip),
        TripSkipped(listingId: 'b', reason: TripSkipReasons.alreadyOpen),
      ], veryShortNotice: false);
      final batch = await c.sendStays(step: 'stay:1', day: 1, nights: 2);
      final results = {for (final r in batch!.perRecipient) r.listingId: r};
      expect(results['a']!.status, 'OpenInAnotherTrip');
      expect(results['a']!.ok, isFalse);
      expect(results['b']!.ok, isTrue);
      expect(batch.perRecipient.where((r) => r.ok).length, 1);
      expect(c.activeOf('stay:1').map((i) => i.listingId), ['a']);
      expect(c.reasonOf('stay:1', 'a'), 'OpenInAnotherTrip');
      expect(TripStringsShortlist.reasonLine('OpenInAnotherTrip', taxi: false),
          'You already asked this host for these dates in another trip');
      expect(TripStringsShortlist.reasonLine('OpenInAnotherTrip', taxi: true),
          'You already asked this driver for these dates in another trip');
      expect(TripStringsShortlist.isOk('OpenInAnotherTrip'), isFalse);
    });
  });

  group('SB2 unavailable hosts', () {
    test('NotAvailable and Blocked leave the shortlist locally, Failed stays', () {
      c.items.addAll([_item('a'), _item('b'), _item('c'), _item('d')]);
      c.applyResults('stay:1', const [
        TripSendResult(listingId: 'a', status: 'Sent'),
        TripSendResult(listingId: 'b', status: 'NotAvailable'),
        TripSendResult(listingId: 'c', status: 'Blocked'),
        TripSendResult(listingId: 'd', status: 'Failed'),
      ]);
      expect(c.activeOf('stay:1').map((i) => i.listingId), ['d']);
      expect(c.reasonOf('stay:1', 'd'), 'Failed');
    });

    test('remove drops the item and calls the server', () async {
      c.items.addAll([_item('a'), _item('b')]);
      expect(await c.remove('stay:1', 'a'), isTrue);
      expect(c.countOf('stay:1'), 1);
      expect(repo.removed, ['a']);
    });

    testWidgets('review card shows a remove x and the failure reason line', (tester) async {
      c.items.addAll([_item('a'), _item('b')]);
      c.reasons['stay:1|b'] = 'Blocked';
      await tester.pumpWidget(_host(TripGuideShortlistReview(
        asset: TravelIcon.stay,
        names: const ['Name a', 'Name b'],
        stays: true,
        sending: false,
        failed: 1,
        step: 'stay:1',
        onSend: () {},
        onNotNow: () {},
      )));
      expect(find.text('This host cannot be reached'), findsOneWidget);
      expect(find.text('One host could not be reached.'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('Remove Name b'));
      await tester.pump();
      expect(c.activeOf('stay:1').map((i) => i.listingId), ['a']);
      expect(find.text('Name b'), findsNothing);
      expect(repo.removed, ['b']);
    });

    testWidgets('taxi step says driver', (tester) async {
      await tester.pumpWidget(_host(TripGuideShortlistReview(
        asset: TravelIcon.stay,
        names: const [],
        stays: false,
        sending: false,
        failed: 2,
        onSend: () {},
        onNotNow: () {},
      )));
      expect(find.text('2 drivers could not be reached.'), findsOneWidget);
    });
  });

  group('SB3 limit message on the bulk path', () {
    test('ask limit on sendStays shows the limit text with minutes', () async {
      c.items.add(_item('a'));
      enquiry.type = TripEnquiryErrorTypes.enquiryLimit;
      enquiry.minutes = 12;
      expect(await c.sendStays(step: 'stay:1', day: 1, nights: 1), isNull);
      expect(toasts.single, '${TripStrings.askLimitTitle}. ${TripStrings.askLimitBody(12)}');
      expect(c.noteOf('stay:1'), toasts.single);
      expect(c.countOf('stay:1'), 1);
    });

    test('lead limit on sendTaxis shows the lead text', () async {
      c.items.add(_item('t', step: 'taxi'));
      enquiry.type = TripEnquiryErrorTypes.leadLimit;
      expect(await c.sendTaxis(step: 'taxi', days: [1]), isNull);
      expect(toasts.single, TripStringsShortlist.leadLimit);
    });

    test('other failures show no limit text', () async {
      c.items.add(_item('a'));
      enquiry.type = 'SomethingElse';
      await c.sendStays(step: 'stay:1', day: 1, nights: 1);
      expect(toasts, isEmpty);
    });

    testWidgets('429 note is visible on the review card', (tester) async {
      c.items.add(_item('a'));
      enquiry.type = TripEnquiryErrorTypes.enquiryLimit;
      await c.sendStays(step: 'stay:1', day: 1, nights: 1);
      await tester.pumpWidget(_host(TripGuideShortlistReview(
        asset: TravelIcon.stay,
        names: const ['Name a'],
        stays: true,
        sending: false,
        failed: 0,
        step: 'stay:1',
        onSend: () {},
        onNotNow: () {},
      )));
      expect(find.textContaining(TripStrings.askLimitTitle), findsOneWidget);
    });
  });

  group('SB8 double Done', () {
    testWidgets('a second Done while sending opens no second sheet', (tester) async {
      c.items.add(_item('a'));
      final gate = Completer<TripEnquiryBatch?>();
      var sends = 0;
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return TripShortlistBar(
              step: 'stay:1',
              onDone: () => TripShortlistFlow.done(context, step: 'stay:1', taxi: false, send: () {
                sends++;
                return gate.future;
              }),
            );
          }),
        ),
      ));
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Send to all'), findsOneWidget);
      await TripShortlistFlow.done(ctx, step: 'stay:1', taxi: false, send: () async => null);
      await tester.pump();
      expect(find.text('Send to all'), findsOneWidget);
      await tester.tap(find.text('Send to all'));
      await tester.pump();
      expect(c.isSending('stay:1'), isTrue);
      await TripShortlistFlow.done(ctx, step: 'stay:1', taxi: false, send: () async => null);
      expect(sends, 1);
      gate.complete(null);
      await tester.pump(const Duration(seconds: 1));
      expect(c.isSending('stay:1'), isFalse);
    });
  });
}
