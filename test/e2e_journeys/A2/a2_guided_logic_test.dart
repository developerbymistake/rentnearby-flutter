import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_strings_guide.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/features/trip/utils/trip_guide_rules.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';

class _Repo implements TripShortlistRepository {
  _Repo([this.items = const []]);

  final List<ShortlistItem> items;
  final booked = <String>[];
  int failBooked = 0;

  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: items);

  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];

  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}

  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}

  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async {
    if (failBooked > 0) {
      failBooked--;
      throw Exception('network');
    }
    booked.add(stepKey);
    return const MarkBookedResult(closedEnquiries: 1, closedShortlist: 1);
  }
}

class _Call {
  _Call(this.ids, this.days, this.day, this.nights, this.requestId);
  final List<String> ids;
  final List<int> days;
  final int? day;
  final int? nights;
  final String? requestId;
}

class _Enq extends TripEnquiryController {
  final calls = <_Call>[];
  String? failType;
  int? failMinutes;
  String failStatus = 'Sent';

  TripEnquiryBatch? _answer(List<String> ids) {
    if (failType != null) {
      lastErrorType = failType;
      lastRetryAfterMinutes = failMinutes;
      lastErrorMessage = 'raw';
      return null;
    }
    return TripEnquiryBatch(
      items: const [],
      skipped: const [],
      veryShortNotice: false,
      results: [for (final id in ids) TripSendResult(listingId: id, status: failStatus)],
    );
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
    calls.add(_Call(taxiIds, days, null, null, clientRequestId));
    return _answer(taxiIds);
  }

  @override
  Future<TripEnquiryBatch?> sendEnquiry({
    required int day,
    required List<String> stayIds,
    required int nights,
    String? clientRequestId,
    String? stepKey,
  }) async {
    calls.add(_Call(stayIds, const [], day, nights, clientRequestId));
    return _answer(stayIds);
  }
}

ShortlistItem _item(String step, String id, {String kind = ShortlistKinds.taxi, int? leg}) =>
    ShortlistItem(stepKey: step, kind: kind, listingId: id, name: 'N-$id', legIndex: leg);

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Rig {
  _Rig(this.c, this.sl, this.repo, this.enq);
  final TripPlanController c;
  final TripShortlistController sl;
  final _Repo repo;
  final _Enq enq;

  void close() {
    c.onClose();
    Get.reset();
  }
}

Future<_Rig> _rig(TripPlan plan, {List<ShortlistItem> items = const []}) async {
  Get.reset();
  final repo = _Repo(items);
  final sl = TripShortlistController(repo: repo, tripId: () async => 't1', offline: () => false, warn: (_) {});
  final enq = _Enq();
  Get.put<TripShortlistController>(sl);
  Get.put<TripEnquiryController>(enq);
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c);
  c.plan.value = plan;
  await sl.load(force: true);
  return _Rig(c, sl, repo, enq);
}

DateTime _today() => TripClock.today();

TripPlan _multi(List<int> legDays, {DateTime? start, TripGuide? guide}) {
  final p = journeyPlan(legDays, start: start ?? _today().add(const Duration(days: 10)));
  return guide == null ? p : p.withGuide(guide);
}

Future<void> _pump(WidgetTester t, _Rig r, double w, {double scale = 1, double h = 800, Widget? top}) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, h), textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: Scaffold(
        body: Column(children: [
          ?top,
          Expanded(child: TripGuideView(controller: r.c, shortlist: r.sl)),
        ]),
      ),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('SB3 limit errors are visible on the guided card', () {
    test('ask limit on a bulk taxi send shows the limit text and keeps the shortlist', () async {
      final r = await _rig(_multi([2]), items: [_item('taxi', 'a'), _item('taxi', 'b')]);
      r.enq
        ..failType = TripEnquiryErrorTypes.enquiryLimit
        ..failMinutes = 7;
      expect(await r.c.guideSendAll('taxi'), isNull);
      final note = r.c.guideState.notes['taxi']!;
      expect(note, contains('Ask limit reached'));
      expect(note, contains('7 min'));
      expect(r.sl.countOf('taxi'), 2);
      r.close();
    });

    test('lead limit shows the daily taxi limit text', () async {
      final r = await _rig(_multi([2]), items: [_item('taxi', 'a')]);
      r.enq.failType = TripEnquiryErrorTypes.leadLimit;
      await r.c.guideSendAll('taxi');
      expect(r.c.guideState.notes['taxi'], TripStringsShortlist.leadLimit);
      r.close();
    });

    test('ask limit on a bulk stay send shows the limit text', () async {
      final r = await _rig(_multi([2]), items: [_item('stay:1', 'a', kind: ShortlistKinds.stay)]);
      r.enq
        ..failType = TripEnquiryErrorTypes.enquiryLimit
        ..failMinutes = 3;
      await r.c.guideSendAll('stay:1');
      expect(r.c.guideState.notes['stay:1'], contains('3 min'));
      r.close();
    });

    testWidgets('tapping Send to all with a 429 shows the message on the card', (t) async {
      final r = await _rig(
        _multi([2], guide: const TripGuide(step: 'stay:1', choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.find})),
        items: [_item('stay:1', 'a', kind: ShortlistKinds.stay), _item('stay:1', 'b', kind: ShortlistKinds.stay)],
      );
      r.enq
        ..failType = TripEnquiryErrorTypes.enquiryLimit
        ..failMinutes = 12;
      await _pump(t, r, 360);
      await _tap(t, 'Send to all');
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('guide-send-note')), findsOneWidget);
      expect(find.textContaining('Ask limit reached'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(r.sl.countOf('stay:1'), 2);
      r.close();
    });
  });

  group('SB4 guided send follows the list screen day rules', () {
    test('multi city sightseeing taxi sends one request per leg with its own request id', () async {
      final r = await _rig(_multi([2, 2]), items: [_item('taxi', 'a', leg: 1), _item('taxi', 'b', leg: 2)]);
      final batch = await r.c.guideSendAll('taxi');
      expect(batch, isNotNull);
      expect(r.enq.calls.length, 2);
      expect(r.enq.calls[0].days, [1, 2]);
      expect(r.enq.calls[0].ids, ['a']);
      expect(r.enq.calls[1].days, [3, 4]);
      expect(r.enq.calls[1].ids, ['b']);
      expect(r.enq.calls[0].requestId, isNot(r.enq.calls[1].requestId));
      expect(batch!.perRecipient.length, 2);
      expect(r.c.guideState.sent['taxi'], 2);
      r.close();
    });

    test('a shortlist without a stored leg is sent only for the first coming leg, never across cities', () async {
      final r = await _rig(_multi([2, 2]), items: [_item('taxi', 'a'), _item('taxi', 'b')]);
      await r.c.guideSendAll('taxi');
      expect(r.enq.calls.length, 1);
      expect(r.enq.calls.single.days, [1, 2]);
      r.close();
    });

    test('an ongoing trip drops past days for taxis and sends the stay from today night', () async {
      final start = _today().subtract(const Duration(days: 1));
      final r = await _rig(
        _multi([3], start: start),
        items: [_item('taxi', 'a'), _item('stay:1', 's', kind: ShortlistKinds.stay)],
      );
      await r.c.guideSendAll('taxi');
      expect(r.enq.calls.single.days, [2, 3]);
      r.enq.calls.clear();
      await r.c.guideSendAll('stay:1');
      expect(r.enq.calls.single.day, 2);
      expect(r.enq.calls.single.nights, 2);
      r.close();
    });

    test('retry after a failed first leg reuses the same request id for that leg', () async {
      final r = await _rig(_multi([2, 2]), items: [_item('taxi', 'a', leg: 1), _item('taxi', 'b', leg: 2)]);
      r.enq.failType = TripEnquiryErrorTypes.enquiryLimit;
      await r.c.guideSendAll('taxi');
      final first = r.enq.calls.single.requestId;
      r.enq.failType = null;
      await r.c.guideSendAll('taxi');
      expect(r.enq.calls.first.requestId, first);
      r.close();
    });
  });

  group('SB6 failure and sent copy say why and use the right word', () {
    test('a driver that is not available gets its own line', () async {
      final r = await _rig(_multi([2]), items: [_item('taxi', 'a')]);
      r.enq.failStatus = 'NotAvailable';
      await r.c.guideSendAll('taxi');
      expect(r.c.guideState.notes['taxi'], 'This taxi is not available any more');
      expect(r.c.guideState.failed['taxi'], 1);
      r.close();
    });

    test('taxi says drivers and stays say hosts; the generic failure line names neither', () {
      expect(TripStringsGuide.sentBody(2, taxi: true), 'We told 2 drivers. You will see replies here.');
      expect(TripStringsGuide.sentBody(1), 'We told 1 host. You will see replies here.');
      expect(TripStringsGuide.failedNote(1), 'One enquiry could not be sent.');
      expect(TripStringsGuide.failedNote(2), '2 enquiries could not be sent.');
    });
  });

  group('SB7 car steps', () {
    testWidgets('a shortlisted car step shows the review card with Send to all and Change my picks', (t) async {
      final r = await _rig(
        _multi([2], guide: const TripGuide(step: 'gettingThere', choices: {'gettingThere': TripGuideChoice.find})),
        items: [_item('gettingThere', 'c1', kind: ShortlistKinds.car)],
      );
      await _pump(t, r, 360);
      expect(find.text('Great picks'), findsOneWidget);
      expect(find.text('Change my picks'), findsOneWidget);
      expect(find.text('Send to all'), findsOneWidget);
      r.close();
    });
  });

  group('SB2 and RM-3 in the real guided card', () {
    testWidgets('a shortlisted stay on the card shows the remove x', (t) async {
      final r = await _rig(
        _multi([2], guide: const TripGuide(step: 'stay:1', choices: {'stay:1': TripGuideChoice.find})),
        items: [_item('stay:1', 's1', kind: ShortlistKinds.stay)],
      );
      await _pump(t, r, 300, scale: 2);
      expect(find.bySemanticsLabel('Remove N-s1'), findsOneWidget);
      r.close();
    });

    test('a city 2 taxi shortlist item carries leg 2', () async {
      final r = await _rig(_multi([2, 2]));
      await r.sl.toggle(step: 'taxi', kind: ShortlistKinds.taxi, listingId: 'd1', name: 'D', legIndex: r.c.plan.value!.legIndexOf(r.c.plan.value!.days.last.day));
      expect(r.sl.activeOf('taxi').single.legIndex, 2);
      r.close();
    });
  });

  group('RM-1 the saved step is not overwritten by a jump', () {
    test('guideJumpTo without a flag moves the view but keeps the saved cursor', () async {
      final r = await _rig(_multi([2], guide: const TripGuide(step: 'taxi', choices: {'gettingThere': TripGuideChoice.skip})));
      r.c.guideJumpTo('stay:1');
      expect(r.c.guideState.keyNow, 'stay:1');
      expect(r.c.plan.value!.guide!.step, 'taxi');
      r.close();
    });

    test('a nudge jump is saved', () async {
      final r = await _rig(_multi([2], guide: const TripGuide(step: 'taxi', choices: {'gettingThere': TripGuideChoice.skip})));
      r.c.guideJumpTo('stay:1', nudge: true, name: 'Hill View');
      expect(r.c.plan.value!.guide!.step, 'stay:1');
      r.close();
    });
  });

  group('RM-2 one percent in guided mode', () {
    testWidgets('header ring and Step 2 label are hidden while the guide shows its own percent', (t) async {
      final r = await _rig(_multi([2], guide: const TripGuide(step: 'stay:1', choices: {'gettingThere': TripGuideChoice.skip})));
      r.c.planStep.value = 2;
      r.c.guideRefresh();
      expect(r.c.guideState.on.value, isTrue);
      await _pump(t, r, 412, h: 900, top: const TripPlanHeader(onMenu: _noop));
      expect(find.textContaining('%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.textContaining('arranged'), findsNothing);
      r.close();
    });
  });

  group('RM-4 a city change drops guide choices of the changed legs', () {
    const all = {
      'gettingThere': TripGuideChoice.skip,
      'stay:1': TripGuideChoice.skip,
      'taxi': TripGuideChoice.skip,
      'between:2': TripGuideChoice.skip,
      'stay:2': TripGuideChoice.skip,
      'between:3': TripGuideChoice.skip,
      'stay:3': TripGuideChoice.skip,
    };

    test('removing the middle city clears later stay and between answers and the cursor', () async {
      final r = await _rig(_multi([1, 1, 1], guide: const TripGuide(step: 'stay:2', choices: all)));
      expect(r.c.removeLeg(2), TripLegEditBlock.none);
      final g = r.c.plan.value!.guide!;
      expect(g.choices.keys.toSet(), {'gettingThere', 'stay:1', 'taxi'});
      expect(g.step, '');
      expect(r.c.guideState.choices.containsKey('stay:2'), isFalse);
      expect(r.c.guideState.keyNow, 'between:2');
      r.close();
    });

    test('moving a city clears the answers of the legs that swapped', () async {
      final r = await _rig(_multi([1, 1, 1], guide: const TripGuide(step: 'comingBack', choices: all)));
      expect(r.c.moveLeg(2, false), TripLegEditBlock.none);
      final g = r.c.plan.value!.guide!;
      expect(g.choices.containsKey('stay:2'), isFalse);
      expect(g.choices.containsKey('stay:3'), isFalse);
      expect(g.choices.containsKey('between:3'), isFalse);
      expect(g.choices['stay:1'], TripGuideChoice.skip);
      r.close();
    });

    test('staleKeys finds nothing when the cities are unchanged', () {
      final p = _multi([1, 1]);
      expect(TripGuideRules.staleKeys(p, p), isEmpty);
    });
  });

  group('RM-5 a stored finish step follows new steps', () {
    test('adding a city after finish moves the cursor to the first unanswered step', () async {
      const answered = {
        'gettingThere': TripGuideChoice.skip,
        'stay:1': TripGuideChoice.skip,
        'taxi': TripGuideChoice.skip,
        'comingBack': TripGuideChoice.skip,
      };
      final r = await _rig(_multi([2], guide: const TripGuide(choices: answered)));
      r.c.guideRefresh();
      r.c.guideGoTo(4);
      expect(r.c.guideState.atFinish, isTrue);
      r.c.plan.value = _multi([2, 2], guide: const TripGuide(choices: answered));
      r.c.guideSync();
      expect(r.c.guideState.atFinish, isFalse);
      expect(r.c.guideState.keyNow, 'between:2');
      r.close();
    });
  });

  group('RM-6 skip and find rules', () {
    test('Help me find with nothing shortlisted does not count as done; a shortlist does', () async {
      final r = await _rig(
        _multi([2], guide: const TripGuide(choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.find})),
      );
      r.c.guideHydrate();
      r.c.guideSync();
      expect(r.c.guideState.percent.value, 25);
      r.sl.items.add(_item('stay:1', 'a', kind: ShortlistKinds.stay));
      r.c.guideSync();
      expect(r.c.guideState.percent.value, 25);
      r.c.guideState.notNow.add('stay:1');
      r.c.guideSync();
      expect(r.c.guideState.percent.value, 50);
      r.close();
    });

    testWidgets('Skip is blocked while a journey is linked to the step', (t) async {
      final base = _multi([2]);
      final linked = base.copyWith(
        steps: base.steps.withStep(
          TripStepRole.gettingThere,
          const TripStep(status: TripStepStatus.chosen, journeyId: 'j1'),
        ),
      );
      final r = await _rig(linked);
      await _pump(t, r, 360);
      expect(r.c.guideState.keyNow, 'gettingThere');
      await r.c.guideChoose(t.element(find.byType(TripGuideView)), 'gettingThere', TripGuideChoice.skip);
      expect(r.c.guideState.choices.containsKey('gettingThere'), isFalse);
      expect(r.c.plan.value!.steps.of(TripStepRole.gettingThere).status, TripStepStatus.chosen);
      await t.pump(const Duration(seconds: 5));
      r.close();
    });

    test('resolvedCount counts find only when engaged', () {
      final keys = ['gettingThere', 'stay:1'];
      const choices = {'gettingThere': TripGuideChoice.find, 'stay:1': TripGuideChoice.own};
      expect(TripGuideRules.resolvedCount(keys, choices, engaged: <String>{}), 1);
      expect(TripGuideRules.resolvedCount(keys, choices, engaged: {'gettingThere'}), 2);
      expect(TripGuideRules.resolvedCount(keys, choices), 2);
    });
  });

  group('RM-7 saved overview flag never shows the old rows', () {
    testWidgets('a trip saved with overview true opens at its saved question in the guide', (t) async {
      final r = await _rig(_multi([2], guide: const TripGuide(overview: true, choices: {'gettingThere': TripGuideChoice.skip})));
      r.c.planStep.value = 2;
      r.c.guideHydrate();
      r.c.guideRefresh();
      expect(r.c.guideState.on.value, isTrue);
      expect(r.c.guideAvailable, isTrue);
      expect(r.c.guideState.keyNow, 'stay:1');
      r.close();
    });
  });

  group('RM-7 no Overview in the guide', () {
    testWidgets('the guide has no Overview link and no Back to steps button', (t) async {
      final r = await _rig(_multi([2], guide: const TripGuide(overview: true, choices: {'gettingThere': TripGuideChoice.skip})));
      r.c.planStep.value = 2;
      t.view.physicalSize = const Size(412, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const GetMaterialApp(home: TripPlanScreen()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      r.c.planStep.value = 2;
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text('Back to steps'), findsNothing);
      expect(r.c.guideState.on.value, isTrue);
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Your trip so far'), findsNothing);
      await t.pump(const Duration(seconds: 5));
      r.close();
    });
  });

  group('mark as booked with open enquiries goes through the server and is retried', () {
    test('a failed server call keeps the own mark pending and a later retry settles it', () async {
      final r = await _rig(_multi([2]));
      final start = _today().add(const Duration(days: 10));
      r.c.applyEnquiries([
        TripEnquiryModel.fromJson(enquiryJson(id: 'e1', kind: TripEnquiryKinds.stay, status: TripEnquiryStatuses.asked, start: start)),
      ]);
      r.c.ownRetryDelay = Duration.zero;
      r.repo.failBooked = 1;
      const stay = TripEasyRowKey(TripEasyRowKind.stay, 1);
      expect(r.c.openRowsOf(stay), isNotEmpty);
      expect(await r.c.markOwn(stay, withdrawOpen: true), isA<TripMarked>());
      expect(r.c.plan.value!.legAt(1)!.stayMark?.isOwn, isTrue);
      expect(r.c.ownPending, {'stay:1'});
      for (var i = 0; i < 50 && r.c.ownPending.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(r.c.ownPending, isEmpty);
      expect(r.repo.booked, ['stay:1']);
      r.close();
    });

    test('a successful call is made once and nothing stays pending', () async {
      final r = await _rig(_multi([2]));
      final start = _today().add(const Duration(days: 10));
      r.c.applyEnquiries([
        TripEnquiryModel.fromJson(enquiryJson(id: 'e1', kind: TripEnquiryKinds.stay, status: TripEnquiryStatuses.asked, start: start)),
      ]);
      await r.c.markOwn(const TripEasyRowKey(TripEasyRowKind.stay, 1), withdrawOpen: true);
      expect(r.repo.booked, ['stay:1']);
      expect(r.c.ownPending, isEmpty);
      r.close();
    });
  });

  group('finish copy', () {
    testWidgets('not everything arranged says plan saved and offers the overview', (t) async {
      const choices = {
        'gettingThere': TripGuideChoice.find,
        'stay:1': TripGuideChoice.skip,
        'taxi': TripGuideChoice.skip,
        'comingBack': TripGuideChoice.skip,
      };
      final r = await _rig(_multi([2], guide: const TripGuide(step: 'finish', choices: choices)));
      r.sl.items.add(_item('gettingThere', 'a'));
      r.c.guideState.notNow.add('gettingThere');
      r.c.guideRefresh();
      r.c.guideGoTo(4);
      await _pump(t, r, 360);
      expect(find.text('Your plan is saved'), findsOneWidget);
      expect(find.text('See what is still to do'), findsOneWidget);
      expect(find.text('Your trip is ready to go'), findsNothing);
      r.close();
    });

    testWidgets('everything arranged keeps the ready copy', (t) async {
      const choices = {
        'gettingThere': TripGuideChoice.skip,
        'stay:1': TripGuideChoice.skip,
        'taxi': TripGuideChoice.skip,
        'comingBack': TripGuideChoice.skip,
      };
      final r = await _rig(_multi([2], guide: const TripGuide(choices: choices)));
      for (final k in ['gettingThere', 'stay:1', 'taxi', 'comingBack']) {
        r.c.skipRow(TripGuideRules.rowKeyOf(k)!);
      }
      r.c.guideRefresh();
      r.c.guideGoTo(4);
      await _pump(t, r, 360);
      expect(find.text('Your trip is ready to go'), findsOneWidget);
      r.close();
    });
  });

  test('skipRow on a skipped row keeps rules consistent with TripEasyRules', () async {
    final r = await _rig(_multi([2]));
    r.c.skipRow(const TripEasyRowKey(TripEasyRowKind.taxi));
    expect(r.c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.taxi))!.state, TripRowState.skipped);
    r.close();
  });
}

void _noop(TripPlanMenu m) {}
