import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/taxi/ways/models/ask_models.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_controller.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_feed_screen.dart';
import 'package:bakhli/features/taxi/ways/way_actions.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_bar.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../support/real_phone.dart';

const _step = 'gettingThere';
const _hint = 'Pick up to 3 from the list, or choose another option';

// Fake server: shortlist storage.
class _Repo implements TripShortlistRepository {
  final items = <ShortlistItem>[];

  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: List.of(items), max: 3);

  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async {
    items.removeWhere((i) => i.listingId == listingId);
    items.add(item);
    return List.of(items);
  }

  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {
    items.removeWhere((i) => i.listingId == listingId);
  }

  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}

  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 0, closedShortlist: 0);
}

// Fake server: the bulk ask endpoint. Records every call.
class _Bulk extends WayActions {
  _Bulk(this.calls, this.store)
      : super(
          tripId: 't1',
          tripRole: _step,
          date: () => DateTime(2030, 11, 1),
          people: () => 2,
          chosenOf: (_) => const {},
          busy: <String>{}.obs,
        );

  final List<List<String>> calls;
  final List<ShortlistItem> store;

  @override
  Future<AskResult?> askShortlisted(
    BuildContext context,
    WayPlan plan, {
    required String step,
    required String requestId,
    required List<String> taxiIds,
  }) async {
    calls.add(List.of(taxiIds));
    store.removeWhere((i) => taxiIds.contains(i.listingId));
    return AskResult(
      items: const [],
      skipped: const [],
      veryShortNotice: false,
      results: [for (final id in taxiIds) TripSendResult(listingId: id, status: 'Sent', enquiryId: 'e-$id')],
    );
  }
}

const _from = WayPlace(key: 'a', name: 'Delhi', lat: 28.6, lng: 77.2, resolved: true);
const _to = WayPlace(key: 'b', name: 'Nainital', lat: 29.4, lng: 79.4, resolved: true);
const _names = ['Ramesh Negi', 'Suresh Bisht', 'Mahesh Joshi', 'Dinesh Rawat', 'Kamal Pant'];

class _Ways extends TaxiWaysController {
  _Ways(this.bulk)
      : super(
          from: PlaceResult(name: 'Delhi', subtitle: 'Delhi', latLng: const LatLng(28.6, 77.2)),
          to: PlaceResult(name: 'Nainital', subtitle: 'Nainital', latLng: const LatLng(29.4, 79.4)),
          tripId: 't1',
          tripRole: _step,
          fromTrip: true,
          date: DateTime(2030, 11, 1),
          people: 2,
        );

  final _Bulk bulk;
  int loads = 0;

  @override
  WayActions get actions => bulk;

  @override
  Future<void> load() async {
    loads++;
    result.value = TaxiWaysResult(
      version: '1',
      from: _from,
      to: _to,
      allTheWay: [
        for (var i = 0; i < _names.length; i++)
          WayDriver(
            taxiId: 'd$i',
            driverName: _names[i],
            vehicleTypeName: 'Sedan',
            seats: 4,
            fromName: 'Delhi',
            toName: 'Nainital',
            listedFare: 5200 + i * 300,
            basedHere: i == 0,
          ),
      ],
    );
  }
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripPlan _plan({TripGuide? guide}) => TripPlan(
      legs: [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.4, longitude: 79.4)],
      days: [
        TripDay(
          day: 1,
          leg: 1,
          spots: [TripSpotRef(id: 's1', name: 'Naini Lake', latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60)],
        ),
      ],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      guide: guide,
    );

class _Rig {
  _Rig({TripPlan? plan, _Repo? repo}) : repo = repo ?? _Repo() {
    Get.testMode = true;
    sl = TripShortlistController(repo: this.repo, tripId: () async => 't1', offline: () => false, warn: warnings.add);
    Get.put<TripShortlistController>(sl);
    Get.put<TabConfigController>(_Tabs());
    c = TripPlanController();
    c.plan.value = plan ?? _plan();
    Get.put<TripPlanController>(c);
    ways = _Ways(_Bulk(bulkCalls, this.repo.items));
    Get.put(ways, tag: 'ways-test');
    // Same shape as TripNavigation.openWays: push the real list and wait until it closes.
    c.guideState.opener = (ctx, row, guide) async {
      listOpens++;
      await Navigator.of(ctx).push(MaterialPageRoute<void>(
        builder: (_) => TaxiWaysFeedScreen(debugController: ways, debugGuide: guide),
      ));
      return true;
    };
    addTearDown(Get.reset);
  }

  final _Repo repo;
  final warnings = <String>[];
  final bulkCalls = <List<String>>[];
  late final TripShortlistController sl;
  late final TripPlanController c;
  late final _Ways ways;
  int listOpens = 0;

  void close() {
    c.onClose();
    Get.reset();
  }
}

Future<void> _pump(WidgetTester t, _Rig r, {Size size = phoneSize}) async {
  await pumpPhone(
    t,
    Scaffold(body: SafeArea(bottom: false, child: TripGuideView(controller: r.c, shortlist: r.sl))),
    size: size,
  );
  await settlePhone(t);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 150));
}

Future<void> _tapText(WidgetTester t, String label, {int at = 0}) => _tap(t, find.text(label).at(at));

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 300));
  await settlePhone(t);
}

TripGuideBar _bar(WidgetTester t) => t.widget<TripGuideBar>(find.byType(TripGuideBar));

Future<void> _back(WidgetTester t) async {
  Navigator.of(t.element(find.byType(TaxiWaysFeedScreen))).pop();
  await _settle(t);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  tearDown(Get.reset);

  testWidgets('BOT happy path: find -> list -> shortlist 3 -> 4th refused -> Done -> review -> send -> sent -> Next', (t) async {
    final r = _Rig();
    await _pump(t, r);

    // Question card, nothing answered yet.
    expect(find.text("Let's get you there"), findsOneWidget);
    expect(find.text('0% done'), findsOneWidget);
    expect(_bar(t).canNext, isFalse);
    await shot(t, 'FINAL_01_question');

    // Help me find opens the real list.
    await _tapText(t, 'Help me find');
    await _settle(t);
    expect(r.listOpens, 1);
    expect(find.byType(TaxiWaysFeedScreen), findsOneWidget);
    for (final n in _names.take(3)) {
      expect(find.text(n), findsOneWidget, reason: '$n card renders');
    }
    expect(find.text('0 of 3 shortlisted'), findsOneWidget);
    expect(r.c.guideAnswered(_step), isFalse);
    await shot(t, 'FINAL_02_list_empty');

    // Shortlist 1, 2, 3.
    await _tapText(t, 'Shortlist');
    expect(find.text('1 of 3 shortlisted'), findsOneWidget);
    expect(r.c.guideAnswered(_step), isFalse, reason: 'one pick alone does not answer the step');
    await shot(t, 'FINAL_03_list_one');
    await _tapText(t, 'Shortlist');
    expect(find.text('2 of 3 shortlisted'), findsOneWidget);
    await _tapText(t, 'Shortlist');
    expect(find.text('3 of 3 shortlisted'), findsOneWidget);
    expect(r.sl.countOf(_step), 3);
    expect(r.repo.items.map((i) => i.listingId).toSet().length, 3);

    // 4th refused with the message; count stays 3.
    await _tapText(t, 'Shortlist');
    expect(r.warnings, contains(TripStringsShortlist.full));
    expect(r.sl.countOf(_step), 3);
    expect(find.text('3 of 3 shortlisted'), findsOneWidget);
    expect(find.text(TripStringsShortlist.full), findsOneWidget);
    await shot(t, 'FINAL_04_list_full');

    // Done opens the review that lists the 3.
    await _tapText(t, 'Done');
    await _settle(t);
    expect(find.text('Great picks'), findsOneWidget);
    expect(find.text('Yes, send to all'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(r.bulkCalls, isEmpty, reason: 'nothing is sent before the user says yes');
    await shot(t, 'FINAL_05_review_sheet');

    // Yes: the bulk call carries exactly the 3 shortlisted ids.
    final picked = r.sl.items.where((i) => i.stepKey == _step).map((i) => i.listingId).toSet();
    expect(picked.length, 3);
    await _tapText(t, 'Yes, send to all');
    await _settle(t);
    expect(r.bulkCalls.length, 1);
    expect(r.bulkCalls.single.toSet(), picked);
    expect(r.bulkCalls.single.length, 3);
    await shot(t, 'FINAL_06_after_send');

    // Close any result sheet and the list; the guide card must show the sent state and Next.
    while (find.byType(TaxiWaysFeedScreen).evaluate().isNotEmpty) {
      if (find.text('Done').evaluate().isNotEmpty && find.byType(BottomSheet).evaluate().isNotEmpty) {
        await _tapText(t, 'Done');
      } else if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        await t.tapAt(const Offset(180, 20));
        await _settle(t);
      } else {
        await _back(t);
      }
    }
    await _settle(t);
    expect(find.byType(TaxiWaysFeedScreen), findsNothing);
    expect(r.c.guideAnswered(_step), isTrue, reason: 'a send where at least one recipient succeeded answers the step');
    expect(find.text('25% done'), findsOneWidget);
    expect(r.c.guideState.percent.value, 25);
    expect(_bar(t).canNext, isTrue);
    await shot(t, 'FINAL_07_sent_card');

    // Next shows the next step.
    await _tapText(t, 'Next');
    await _settle(t);
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    await shot(t, 'FINAL_08_next_step');
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('BOT guide-card path: back from the list with 3 picks, review card lists them, Yes send to all', (t) async {
    final r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'Help me find');
    await _settle(t);
    for (var i = 0; i < 3; i++) {
      await _tapText(t, 'Shortlist');
    }
    expect(r.sl.countOf(_step), 3);
    await _back(t);

    // Back with 3 picks and nothing sent: review card, still unanswered, Next disabled.
    expect(find.text('Great picks'), findsOneWidget);
    expect(r.c.guideAnswered(_step), isFalse);
    expect(_bar(t).canNext, isFalse);
    expect(find.text('0% done'), findsOneWidget);
    for (final n in _names.take(3)) {
      expect(find.textContaining(n), findsWidgets, reason: '$n is listed on the review card');
    }
    await shot(t, 'FINAL_09_review_card_on_plan');

    // The card send goes through the same server call; hook it on the plan controller.
    final ids = <String>[];
    r.c.carSender = (step, sent, requestId) async {
      ids.addAll(sent);
      r.repo.items.removeWhere((i) => sent.contains(i.listingId));
      return AskResult(
        items: const [],
        skipped: const [],
        veryShortNotice: false,
        results: [for (final id in sent) TripSendResult(listingId: id, status: 'Sent', enquiryId: 'e-$id')],
      );
    };
    final shortlisted = r.repo.items.map((i) => i.listingId).toSet();
    await _tapText(t, 'Yes, send to all');
    await _settle(t);
    expect(ids.toSet(), shortlisted);
    expect(ids.length, 3);
    expect(find.text('Enquiry sent'), findsOneWidget);
    expect(_bar(t).canNext, isTrue);
    expect(find.text('25% done'), findsOneWidget);
    await shot(t, 'FINAL_10_sent_card_from_review_card');
    await _tapText(t, 'Next');
    await _settle(t);
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('BOT Not now: 3 picks, Not now on the review answers the step and moves on', (t) async {
    final r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'Help me find');
    await _settle(t);
    await _tapText(t, 'Shortlist');
    await _tapText(t, 'Done');
    await _settle(t);
    expect(find.text('Great picks'), findsOneWidget);
    await _tapText(t, 'Not now');
    await _settle(t);
    expect(r.bulkCalls, isEmpty);
    expect(r.c.guideAnswered(_step), isTrue);
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('NEGATIVE BOT: Help me find, nothing shortlisted, back: Next disabled with the reason, Open the list reopens', (t) async {
    final r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'Help me find');
    await _settle(t);
    expect(find.byType(TaxiWaysFeedScreen), findsOneWidget);

    // Done with nothing: stays on the list and says what to do.
    await _tapText(t, 'Done');
    expect(find.byType(TaxiWaysFeedScreen), findsOneWidget);
    expect(find.text(TripStringsShortlist.pickFirst), findsOneWidget);
    expect(r.bulkCalls, isEmpty);
    await shot(t, 'FINAL_11_done_with_none');

    await _back(t);
    expect(r.c.guideAnswered(_step), isFalse);
    expect(find.text('0% done'), findsOneWidget);
    expect(_bar(t).canNext, isFalse);
    expect(find.text(_hint), findsOneWidget);
    expect(find.text('Open the list'), findsOneWidget);
    r.c.guideNext();
    await t.pump();
    expect(r.c.guideState.index.value, 0, reason: 'a direct forward call is refused too');
    expect(r.bulkCalls, isEmpty);
    await shot(t, 'FINAL_12_next_disabled_reason');

    await _tapText(t, 'Open the list');
    await _settle(t);
    expect(r.listOpens, 2);
    expect(find.byType(TaxiWaysFeedScreen), findsOneWidget);
    await _back(t);
    expect(_bar(t).canNext, isFalse);
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('NEGATIVE BOT: picks but never sent and never Not now stays unanswered', (t) async {
    final r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'Help me find');
    await _settle(t);
    await _tapText(t, 'Shortlist');
    await _back(t);
    expect(r.sl.countOf(_step), 1);
    expect(r.c.guideAnswered(_step), isFalse);
    expect(_bar(t).canNext, isFalse);
    r.c.guideNext();
    expect(r.c.guideState.index.value, 0);
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('NEGATIVE BOT: every recipient fails, step stays unanswered, no Next', (t) async {
    final r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'Help me find');
    await _settle(t);
    await _tapText(t, 'Shortlist');
    await _back(t);
    r.c.carSender = (step, sent, requestId) async => AskResult(
          items: const [],
          skipped: const [],
          veryShortNotice: false,
          results: [for (final id in sent) TripSendResult(listingId: id, status: 'Failed')],
        );
    await _tapText(t, 'Yes, send to all');
    await _settle(t);
    expect(r.c.guideAnswered(_step), isFalse);
    expect(_bar(t).canNext, isFalse);
    expect(find.text('0% done'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('Skip and I will arrange it myself each answer the step on their own', (t) async {
    var r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'Skip this');
    expect(r.c.guideAnswered(_step), isTrue);
    expect(find.text('25% done'), findsOneWidget);
    expect(_bar(t).canNext, isTrue);
    await _tapText(t, 'Next');
    await _settle(t);
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    r.close();

    await t.pumpWidget(const SizedBox.shrink());
    r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'I will arrange it myself');
    await t.pump(const Duration(milliseconds: 300));
    await _settle(t);
    expect(r.c.guideAnswered(_step), isTrue);
    expect(find.text('25% done'), findsOneWidget);
    expect(_bar(t).canNext, isTrue);
    expect(r.listOpens, 0);
    await shot(t, 'FINAL_13_own_answered');
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('RESUME: rebuild from the saved plan lands on the same unanswered step; skipped step moves on', (t) async {
    // Saved plan says find, user had left the list with nothing shortlisted.
    var r = _Rig(plan: _plan(guide: const TripGuide(step: _step, choices: {_step: TripGuideChoice.find})));
    await _pump(t, r);
    expect(find.text("Let's get you there"), findsOneWidget);
    expect(r.c.guideAnswered(_step), isFalse);
    expect(_bar(t).canNext, isFalse);
    expect(find.text('0% done'), findsOneWidget);
    expect(find.text(_hint), findsOneWidget);
    await shot(t, 'FINAL_14_resume_unanswered');
    r.close();
    await t.pumpWidget(const SizedBox.shrink());

    // A real save after Skip, then a rebuild from that saved plan resumes on step 2.
    r = _Rig();
    await _pump(t, r);
    await _tapText(t, 'Skip this');
    await _tapText(t, 'Next');
    await _settle(t);
    final saved = r.c.plan.value!;
    expect(saved.guide?.step, isNot(_step));
    r.close();
    await t.pumpWidget(const SizedBox.shrink());

    r = _Rig(plan: saved);
    await _pump(t, r);
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    expect(r.c.guideAnswered(_step), isTrue);
    await t.pump(const Duration(seconds: 6));
    r.close();
  });

  testWidgets('RESUME: picks exist after a kill, plan lands on the review card, still unanswered', (t) async {
    final repo = _Repo()..items.addAll([for (var i = 0; i < 2; i++) ShortlistItem(stepKey: _step, kind: ShortlistKinds.car, listingId: 'd$i', name: _names[i], state: ShortlistStates.active)]);
    final r = _Rig(plan: _plan(guide: const TripGuide(step: _step, choices: {_step: TripGuideChoice.find})), repo: repo);
    await r.sl.load(force: true);
    await _pump(t, r);
    expect(find.text('Great picks'), findsOneWidget);
    expect(r.c.guideAnswered(_step), isFalse);
    expect(_bar(t).canNext, isFalse);
    await shot(t, 'FINAL_15_resume_review');
    await t.pump(const Duration(seconds: 6));
    r.close();
  });
}
